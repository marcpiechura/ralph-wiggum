#!/bin/bash
#
# Test: Amp Loop Completion
# Creates a synthetic plan with N simple tasks and verifies amp completes them all.
#
# Usage:
#   ./tests/amp_loop_test.sh [num_tasks]
#
# Default: 3 tasks

set -e

NUM_TASKS=${1:-3}
TEST_DIR=$(mktemp -d)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Amp Loop Test ==="
echo "Tasks: $NUM_TASKS"
echo "Test dir: $TEST_DIR"
echo ""

# Create AGENTS.md
cat > "$TEST_DIR/AGENTS.md" << 'EOF'
# Test Project

Simple test project for ralph loop testing.

## Validation
```bash
echo "Validation passed"
```
EOF

# Create specs directory
mkdir -p "$TEST_DIR/specs"
cat > "$TEST_DIR/specs/test-feature.md" << 'EOF'
# Test Feature

## Overview
Create simple text files for testing the ralph loop.

## Acceptance Criteria
- [ ] All files created successfully
EOF

# Generate IMPLEMENTATION_PLAN.md with N tasks
cat > "$TEST_DIR/IMPLEMENTATION_PLAN.md" << EOF
# Test Feature - Implementation Plan

Generated for testing. Tasks sorted by priority.

## Status Legend
- [ ] Not started
- [x] Completed
- [~] In progress
- [!] Blocked

---

## Phase 1: Test Tasks (P0)

EOF

for i in $(seq 1 $NUM_TASKS); do
  cat >> "$TEST_DIR/IMPLEMENTATION_PLAN.md" << EOF
### Task $i: Create file$i.txt
- **File**: \`file$i.txt\` (new)
- **Description**: Create a file containing "Hello from task $i"
- **Details**:
  - Create file$i.txt with content "Hello from task $i"
- **Verification**: \`cat file$i.txt\`
- [ ] Not started

EOF
done

cat >> "$TEST_DIR/IMPLEMENTATION_PLAN.md" << 'EOF'
---

## Completed Tasks

(Move completed tasks here)

---

## Notes

- One task per loop iteration
EOF

# Create PROMPT_build.md
cat > "$TEST_DIR/PROMPT_build.md" << 'EOF'
# Building Mode (Test)

Implement ONE task from the plan, then check if more work remains.

## Phase 1: Check Initial State

Run this command:
```bash
tail -n +12 IMPLEMENTATION_PLAN.md | grep -c "^\- \[ \]" || echo 0
```

If result is 0, output **RALPH_COMPLETE** and exit.
Otherwise, continue to Phase 2.

## Phase 2: Select Task

Read IMPLEMENTATION_PLAN.md and find the first task with `- [ ] Not started`.

## Phase 3: Implement

Create the file as specified in the task.

## Phase 4: Update Plan

Edit IMPLEMENTATION_PLAN.md to change `- [ ] Not started` to `- [x] Completed` for this task.

## Phase 5: Re-check

Run the completion check AGAIN:
```bash
tail -n +12 IMPLEMENTATION_PLAN.md | grep -c "^\- \[ \]" || echo 0
```

- If result > 0: Say "X tasks remaining" and EXIT immediately. Do NOT say RALPH_COMPLETE.
- If result = 0: Output **RALPH_COMPLETE**
EOF

# Initialize git repo
cd "$TEST_DIR"
git init -q
git add -A
git commit -q -m "Initial commit"

echo "Created test environment with $NUM_TASKS tasks"
echo ""

# Show initial plan
echo "--- Initial Plan (task status lines) ---"
grep -E "^\- \[.\]" IMPLEMENTATION_PLAN.md | head -20
echo ""

# Copy the loop script
cp "$SCRIPT_DIR/agents/amp/loop.sh" "$TEST_DIR/loop.sh"
chmod +x loop.sh

# Run the loop with max iterations = NUM_TASKS + 2 (buffer for completion check)
echo "--- Running Amp Loop ---"
echo ""

MAX_ITER=$((NUM_TASKS + 2))
timeout 300 ./loop.sh build $MAX_ITER 2>&1 || true

echo ""
echo "--- Final Plan (task status lines) ---"
grep -E "^\- \[.\]" IMPLEMENTATION_PLAN.md | head -20
echo ""

# Check results
INCOMPLETE=$(tail -n +12 IMPLEMENTATION_PLAN.md | grep -c "^\- \[ \]" 2>/dev/null || true)
INCOMPLETE=${INCOMPLETE:-0}
COMPLETED=$(grep -c "^\- \[x\]" IMPLEMENTATION_PLAN.md 2>/dev/null || true)
COMPLETED=${COMPLETED:-0}

echo "--- Results ---"
echo "Incomplete tasks: $INCOMPLETE"
echo "Completed tasks: $COMPLETED"
echo ""

# Verify files were created
echo "--- Created Files ---"
for i in $(seq 1 $NUM_TASKS); do
  if [[ -f "file$i.txt" ]]; then
    echo -e "${GREEN}✓${NC} file$i.txt exists"
  else
    echo -e "${RED}✗${NC} file$i.txt missing"
  fi
done
echo ""

# Final verdict (completed includes legend entry, so check >= NUM_TASKS)
if [[ "$INCOMPLETE" -eq 0 && "$COMPLETED" -ge $NUM_TASKS ]]; then
  echo -e "${GREEN}=== TEST PASSED ===${NC}"
  echo "All $NUM_TASKS tasks completed successfully."
  rm -rf "$TEST_DIR"
  exit 0
else
  echo -e "${RED}=== TEST FAILED ===${NC}"
  echo "Expected 0 incomplete, got $INCOMPLETE"
  echo "Expected $NUM_TASKS completed, got $COMPLETED"
  echo ""
  echo "Test directory preserved at: $TEST_DIR"
  exit 1
fi

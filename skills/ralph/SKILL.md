---
name: ralph
description: Interactive planning skill for Amp. Generates specs, implementation plans, and loop infrastructure through clarifying questions.
---

# Ralph Planning Skill

Generate specs, implementation plans, and loop infrastructure for iterative AI-driven development.

## Entry

**Usage:** `/skill ralph [optional/path/to/plan.md]`

- If path provided: Read that `.md` file as the source specification
- If no path: Use the current conversation context

---

## Step 1: Clarification Questions

Before generating any files, ask the user 3-5 clarifying questions in A/B/C/D format. Cover these areas:

### 1. Scope
- A) Localized change (single file/module)
- B) Cross-module changes (multiple related files)
- C) Cross-cutting concern (affects many parts of codebase)
- D) Greenfield (new feature from scratch)

### 2. Risk Tolerance
- A) Conservative - minimal changes, maximum safety
- B) Balanced - reasonable refactoring allowed
- C) Aggressive - significant refactoring acceptable
- D) Experimental - prototype/spike, can be discarded

### 3. Tech Constraints
- A) Must use existing patterns/libraries only
- B) Can introduce new patterns if justified
- C) Can add new dependencies if needed
- D) No constraints - use best solution

### 4. Dependencies
- A) No external dependencies
- B) Known dependencies documented in plan
- C) Dependencies to be discovered
- D) Blocked by other work in progress

### 5. Validation Approach
- A) Existing test suite only
- B) Add new unit tests
- C) Add integration tests
- D) Manual validation sufficient

**Example output:**
```
Before I generate the implementation plan, please answer these questions:

1. **Scope**: How broad is this change?
   A) Localized (single file/module)
   B) Cross-module (multiple related files)
   C) Cross-cutting (affects many parts)
   D) Greenfield (new feature from scratch)

2. **Risk tolerance**: How aggressive should refactoring be?
   A) Conservative - minimal changes
   B) Balanced - reasonable refactoring
   C) Aggressive - significant refactoring OK
   D) Experimental - prototype/spike

3. **Tech constraints**: What's allowed?
   A) Existing patterns/libraries only
   B) New patterns if justified
   C) New dependencies if needed
   D) No constraints

Reply with format: `1A, 2B, 3C`
```

Wait for user response in format like `1A, 2C, 3B`.

---

## Step 2: Optional Oracle Review

After receiving clarification answers, ask:

> Reply `oracle` to run architectural review, or `skip` to proceed with generation.

### If user replies `oracle`:
1. Use the Oracle tool to analyze the codebase architecture relevant to the feature
2. Present any additional clarifying questions based on Oracle's findings
3. Wait for user response before proceeding

### If user replies `skip`:
Proceed directly to Step 3.

---

## Step 3: Generate Files

Generate the following files, **always overwriting** existing files:

### 1. `specs/<feature-slug>.md`

Requirements specification containing:
- Feature overview
- User stories
- Acceptance criteria
- Edge cases and error handling
- Out of scope items

### 2. `IMPLEMENTATION_PLAN.md`

Format:
```markdown
# Implementation Plan: <Feature Name>

> **Scope**: <scope choice> | **Risk**: <risk choice> | **Constraints**: <constraint choice>

## Summary

<2-3 sentence overview of the implementation approach>

## Tasks

- [ ] Task 1: Description with enough context for implementation
- [ ] Task 2: Description with enough context for implementation
- [ ] Task 3: Description with enough context for implementation
...
```

Tasks should be:
- Ordered by priority/dependency
- Small enough for single iteration
- Include file paths when known
- Self-contained with sufficient context

### 3. `PROMPT.md`

Generate with this exact content (replace `[VALIDATION_COMMAND]` with the appropriate command from AGENTS.md or project config):

```markdown
# Ralph Build Mode

Implement ONE task from the plan, validate, commit, exit.

## Tools

- **finder**: Semantic code discovery (use before implementing)
- **Task**: Parallel file operations
- **Oracle**: Debug complex issues
- **Librarian**: External library docs

## Phase 0: Orient

Read:
- @AGENTS.md (project rules)
- @IMPLEMENTATION_PLAN.md (current state)
- @specs/* (requirements)

### Check for completion

Run:
```bash
grep -c "^\- \[ \]" IMPLEMENTATION_PLAN.md || echo 0
```

- If 0: Run validation → commit → output **RALPH_COMPLETE** → exit
- If > 0: Continue to Phase 1

## Phase 1: Implement

1. **Search first** — Use finder to verify the behavior doesn't already exist
2. **Implement** — ONE task only (use Task for parallel independent work)
3. **Validate** — Run `[VALIDATION_COMMAND]`, must pass

If stuck, use Oracle to debug.

## Phase 2: Update Plan

In `IMPLEMENTATION_PLAN.md`:
- Mark task `- [x] Completed`
- Add discovered tasks if any

## Phase 3: Commit & Exit

```bash
git add -A && git commit -m "feat([scope]): [description]

Thread: $AMP_THREAD_URL"
```

Run completion check again:
```bash
grep -c "^\- \[ \]" IMPLEMENTATION_PLAN.md || echo 0
```

- If > 0: Say "X tasks remaining" and EXIT
- If = 0: Output **RALPH_COMPLETE**

## Guardrails

- ONE task per iteration
- Search before implementing
- Validation MUST pass
- Never output RALPH_COMPLETE if tasks remain
```

### 4. `loop.sh`

Generate with this content:

```bash
#!/bin/bash

# Ralph Wiggum Build Loop (Amp)
# Runs build iterations until RALPH_COMPLETE

set -e

MAX_ITERATIONS=0
ITERATION=0
CONSECUTIVE_FAILURES=0
MAX_CONSECUTIVE_FAILURES=3

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

for arg in "$@"; do
  if [[ "$arg" =~ ^[0-9]+$ ]]; then
    MAX_ITERATIONS=$arg
  fi
done

PROMPT_FILE="PROMPT.md"

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo -e "${RED}Error: $PROMPT_FILE not found${NC}"
  echo "Run the ralph skill first to generate the required files."
  exit 1
fi

seconds_until_next_hour() {
  local now=$(date +%s)
  local current_minute=$(date +%M)
  local current_second=$(date +%S)
  local seconds_past_hour=$((10#$current_minute * 60 + 10#$current_second))
  local seconds_until=$((3600 - seconds_past_hour))
  echo $seconds_until
}

seconds_until_daily_reset() {
  local reset_hour=5
  local now=$(date +%s)
  local today_reset=$(date -v${reset_hour}H -v0M -v0S +%s 2>/dev/null || date -d "today ${reset_hour}:00:00" +%s)

  if [[ $now -ge $today_reset ]]; then
    local tomorrow_reset=$((today_reset + 86400))
    echo $((tomorrow_reset - now))
  else
    echo $((today_reset - now))
  fi
}

countdown() {
  local seconds=$1
  local message=$2

  while [[ $seconds -gt 0 ]]; do
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    printf "\r${CYAN}%s${NC} Time remaining: %02d:%02d:%02d " "$message" $hours $minutes $secs
    sleep 1
    ((seconds--))
  done
  printf "\r%-80s\r" " "
}

is_recoverable_error() {
  return 1
}

get_sleep_duration() {
  local output="$1"

  local json_reset=$(echo "$output" | grep -oE '"resetsAt"\s*:\s*"[^"]+"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
  if [[ -n "$json_reset" ]]; then
    local reset_epoch=$(date -jf "%Y-%m-%dT%H:%M:%S%z" "$json_reset" +%s 2>/dev/null || \
                        date -d "$json_reset" +%s 2>/dev/null)
    if [[ -n "$reset_epoch" ]]; then
      local now=$(date +%s)
      local diff=$((reset_epoch - now))
      if [[ $diff -gt 0 ]]; then
        echo $((diff + 60))
        return
      fi
    fi
  fi

  if [[ "$output" =~ retry.after[[:space:]]*:?[[:space:]]*([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
    return
  fi

  if [[ "$output" =~ "try again in "([0-9]+)" minute" ]]; then
    echo $(( ${BASH_REMATCH[1]} * 60 + 60 ))
    return
  fi

  if [[ "$output" =~ "try again in "([0-9]+)" hour" ]]; then
    echo $(( ${BASH_REMATCH[1]} * 3600 + 60 ))
    return
  fi

  if [[ "$output" =~ (daily|day|24.?hour) ]]; then
    seconds_until_daily_reset
    return
  fi

  echo 300
}

handle_recoverable_error() {
  local output="$1"
  local sleep_duration=$(get_sleep_duration "$output")

  echo ""
  echo -e "${YELLOW}=== Recoverable Error Detected ===${NC}"
  echo -e "${YELLOW}Waiting before retry...${NC}"
  echo ""

  local resume_time=$(date -v+${sleep_duration}S "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -d "+${sleep_duration} seconds" "+%Y-%m-%d %H:%M:%S")
  echo -e "Expected resume: ${CYAN}${resume_time}${NC}"
  echo ""

  countdown $sleep_duration "Waiting..."

  echo ""
  echo -e "${GREEN}Resuming...${NC}"
  echo ""

  CONSECUTIVE_FAILURES=0
}

echo -e "${GREEN}Ralph Build Loop (Amp)${NC}"
[[ $MAX_ITERATIONS -gt 0 ]] && echo "Max iterations: $MAX_ITERATIONS"
echo "Press Ctrl+C to stop"
echo "---"

while true; do
  ITERATION=$((ITERATION + 1))
  echo ""
  echo -e "${GREEN}=== Build Iteration $ITERATION ===${NC}"
  echo ""

  TEMP_OUTPUT=$(mktemp)
  set +e

  amp -x \
    --dangerously-allow-all \
    --stream-json \
    < "$PROMPT_FILE" 2>&1 | tee "$TEMP_OUTPUT" | jq -r '
      def tool_info:
        if .name == "edit_file" or .name == "create_file" or .name == "Read" then
          (.input.path | split("/") | last | .[0:60])
        elif .name == "todo_write" then
          ((.input.todos // []) | map(.content) | join(", ") | if contains("\n") then .[0:60] else . end)
        elif .name == "Bash" then
          (.input.cmd | if contains("\n") then split("\n") | first | .[0:50] else .[0:80] end)
        elif .name == "Grep" then
          (.input.pattern | .[0:40])
        elif .name == "glob" then
          (.input.filePattern | .[0:40])
        elif .name == "finder" then
          (.input.query | if contains("\n") then .[0:40] else . end)
        elif .name == "oracle" then
          (.input.task | if contains("\n") then .[0:40] else .[0:80] end)
        elif .name == "Task" then
          (.input.description // .input.prompt | if contains("\n") then .[0:40] else .[0:80] end)
        else null end;
      if .type == "assistant" then
        .message.content[] |
        if .type == "text" then
          if (.text | split("\n") | length) <= 3 then .text else empty end
        elif .type == "tool_use" then
          "    [" + .name + "]" + (tool_info | if . then " " + . else "" end)
        else empty end
      elif .type == "result" then
        "--- " + ((.duration_ms / 1000 * 10 | floor / 10) | tostring) + "s, " + (.num_turns | tostring) + " turns ---"
      else empty end
    ' 2>/dev/null

  EXIT_CODE=$?
  OUTPUT=$(cat "$TEMP_OUTPUT")
  RESULT_MSG=$(cat "$TEMP_OUTPUT" | jq -r 'select(.type == "result") | .result // empty' 2>/dev/null | tail -1)
  rm -f "$TEMP_OUTPUT"
  set -e

  if is_recoverable_error "$OUTPUT" "$EXIT_CODE"; then
    handle_recoverable_error "$OUTPUT"
    ITERATION=$((ITERATION - 1))
    continue
  fi

  if [[ $EXIT_CODE -ne 0 ]]; then
    CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
    echo ""
    echo -e "${RED}=== Error (exit code: $EXIT_CODE) ===${NC}"

    if [[ $CONSECUTIVE_FAILURES -ge $MAX_CONSECUTIVE_FAILURES ]]; then
      echo -e "${RED}Too many consecutive failures ($CONSECUTIVE_FAILURES). Stopping.${NC}"
      exit 1
    fi

    echo -e "${YELLOW}Retrying in 30 seconds... (failure $CONSECUTIVE_FAILURES/$MAX_CONSECUTIVE_FAILURES)${NC}"
    sleep 30
    ITERATION=$((ITERATION - 1))
    continue
  fi

  CONSECUTIVE_FAILURES=0

  if [[ "$RESULT_MSG" =~ "RALPH_COMPLETE" ]]; then
    echo ""
    echo -e "${GREEN}=== Ralph Complete ===${NC}"
    echo -e "${GREEN}All tasks finished.${NC}"
    break
  fi

  if [[ $MAX_ITERATIONS -gt 0 && $ITERATION -ge $MAX_ITERATIONS ]]; then
    echo ""
    echo -e "${GREEN}Reached max iterations ($MAX_ITERATIONS).${NC}"
    break
  fi

  sleep 2
done

echo ""
echo -e "${GREEN}Ralph loop complete. Iterations: $ITERATION${NC}"
```

Make the script executable:
```bash
chmod +x loop.sh
```

---

## End: Next Steps

After generating all files, tell the user:

> **Files generated:**
> - `specs/<feature-slug>.md` - Requirements specification
> - `IMPLEMENTATION_PLAN.md` - Task list with checkboxes
> - `PROMPT.md` - Build mode instructions
> - `loop.sh` - Build loop script
>
> **Next step:** Run `./loop.sh` to start the build loop.

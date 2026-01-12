---
name: ralph
description: Generate the complete Ralph Wiggum loop infrastructure for iterative AI-driven development. Creates specs, implementation plans, and loop scripts for autonomous AI development.
---

# Ralph Wiggum Loop Generator

Generate the complete Ralph Wiggum loop infrastructure for iterative AI-driven development.

## Ralph 2.0 (Recommended)

Uses the Amp SDK for programmatic thread orchestration with native thread map integration.

### Quick Start

```bash
# Navigate to SDK directory
cd ~/.config/agents/skills/ralph-wiggum/sdk

# Build standalone binary (first time only)
bun install && bun run compile

# Install to ~/.local/bin (no sudo required)
mkdir -p ~/.local/bin && mv ralph ~/.local/bin/

# Ensure ~/.local/bin is in PATH (add to shell config if needed)
export PATH="$HOME/.local/bin:$PATH"

# Run on your project
ralph auto -p /path/to/project --validation "pnpm run check"
```

### Commands

```bash
ralph plan      # Create implementation plan from specs
ralph build     # Execute tasks from plan
ralph auto      # Plan then build (recommended)
ralph --help    # Show all options
```

### Key Features

| Feature | Description |
|---------|-------------|
| **Thread Map** | Build threads link to coordinator via URL mentions |
| **Clean Context** | Each thread reads only plan + specs (no pollution) |
| **Thread Tracking** | Thread IDs recorded in `IMPLEMENTATION_PLAN.md` |
| **Dependency Aware** | Respects `depends_on` task ordering |
| **Error Recovery** | Handles consecutive failures gracefully |

### How It Works

1. **Planning Phase**: Creates `IMPLEMENTATION_PLAN.md` from specs
2. **Build Phase**: For each task:
   - Spawns Amp thread with focused instructions
   - Includes coordinator URL (creates thread map link)
   - Implements, validates, commits
   - Updates plan with thread ID
3. **Validation Phase**: Final checks, outputs `RALPH_COMPLETE`

### Thread Map Visualization

All threads appear connected in Amp's Thread Map (`threads: map`):

```
    Coordinator (Plan)
         │
         ├── Build P0.1
         ├── Build P1.1
         └── Build P2.1
```

See [sdk/README.md](sdk/README.md) for full documentation.

---

## Ralph 1.0 (Skill-based Setup)

Use the `/skill ralph` command in Amp to generate specs and plans from feature docs.

### Usage

```bash
# In an Amp session, generate infrastructure from a feature doc
/skill ralph docs/my-feature.md

# Then run the ralph binary to execute
ralph build         # Execute tasks from the plan
ralph auto          # Re-plan then build
```

### Generated Files

| File | Purpose |
|------|---------|
| `specs/*.md` | Feature specs (one topic per file) |
| `IMPLEMENTATION_PLAN.md` | Prioritized task list |
| `PROMPT_plan.md` | Planning mode instructions |
| `PROMPT_build.md` | Building mode instructions |

---

## When to Use Ralph

- Starting a new feature that needs iterative AI development
- Setting up autonomous development loops
- Generating specs and implementation plans from feature docs

## IMPLEMENTATION_PLAN.md Format

```markdown
# Implementation Plan

## Tasks

### P0: Core (must have)

- [ ] P0.1 Create user model
  - scope: src/models/user.ts
  - validation: npm run check
  - assigned_thread:
  - status: not_started

- [ ] P0.2 Add user API
  - scope: src/api/users.ts
  - validation: npm run check
  - assigned_thread:
  - status: not_started
  - depends_on: P0.1
```

## Amp Tools Used

- **Oracle**: For planning, gap analysis, and debugging
- **Librarian**: For reading library documentation
- **finder**: For semantic codebase search
- **Task**: For parallel subagent work (within threads)
- **Amp SDK**: For programmatic thread orchestration (v2)

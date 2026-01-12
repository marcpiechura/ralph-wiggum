---
name: ralph
description: Generate the complete Ralph Wiggum loop infrastructure for iterative AI-driven development. Creates specs, implementation plans, and loop scripts for autonomous AI development.
---

# Ralph Wiggum Loop Generator

Generate the complete Ralph Wiggum loop infrastructure for iterative AI-driven development.

## Versions

### Ralph 2.0 (Recommended) - SDK-Based

Uses the Amp SDK for programmatic thread orchestration.

```bash
# Install
cd sdk && bun install

# Run
bun run src/cli.ts plan      # Create implementation plan
bun run src/cli.ts build     # Execute tasks
bun run src/cli.ts auto      # Plan then build
```

**Benefits:**
- Native Amp thread management
- Thread URLs tracked in plan file
- TypeScript-based, npm-installable
- Proper error handling and recovery

See [sdk/README.md](sdk/README.md) for details.

### Ralph 1.0 (Legacy) - Bash Loop

Traditional bash-based loop that restarts Amp for each iteration.

```bash
./loop.sh           # Auto mode: plan first, then build
./loop.sh plan      # Planning mode only
./loop.sh build     # Build mode only
```

## When to Use

- When starting a new feature that needs iterative AI development
- When you want to set up autonomous development loops
- When you need to generate specs and implementation plans from feature docs

## What It Creates

All files are generated in the **project's root folder**:

| File | Purpose |
|------|---------|
| `specs/*.md` | Feature specs (one topic per file) |
| `IMPLEMENTATION_PLAN.md` | Prioritized task list with thread tracking |
| `PROMPT_plan.md` | Planning mode instructions (v1) |
| `PROMPT_build.md` | Building mode instructions (v1) |
| `loop.sh` | The bash loop script (v1) |

## Usage

Provide a path to a feature document, or let it auto-discover in `docs/`:

```
/skill ralph docs/my-feature.md
/skill ralph
```

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

## Amp-Specific Features

This skill leverages Amp's unique tools:
- **Oracle**: For planning, gap analysis, and debugging
- **Librarian**: For reading library documentation
- **finder**: For semantic codebase search
- **Task**: For parallel subagent work (within threads)
- **Amp SDK**: For programmatic thread orchestration (v2)

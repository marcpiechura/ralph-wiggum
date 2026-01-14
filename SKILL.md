---
name: ralph
description: Interactive planning skill for Amp. Generates specs, implementation plans, and loop infrastructure through clarifying questions.
---

# Ralph Planning Skill

Interactive planning for iterative AI-driven development.

## When to Use

- When starting a new feature that needs iterative AI development
- When you want to set up autonomous development loops
- When you need to generate specs and implementation plans from feature docs

## What It Creates

All files are generated in the **project's root folder**:

| File | Purpose |
|------|---------|
| `specs/<feature>.md` | Requirements, user stories, edge cases |
| `IMPLEMENTATION_PLAN.md` | Summary + prioritized task list |
| `PROMPT.md` | Build mode instructions |
| `loop.sh` | Build-only loop script |

## Usage

```
/skill ralph [optional/path/to/plan.md]
```

- If path provided: read that `.md` file as source specification
- If no path: use current conversation context

## Workflow

1. **Clarification** — 3-5 A/B/C/D questions (respond with "1A, 2C, 3B")
2. **Optional Oracle** — architectural review
3. **Generate** — specs, plan, prompt, loop script
4. **Build** — run `./loop.sh` to execute

## File Writing Behavior

**Always overwrite existing files** when generating ralph files. These files are ephemeral and meant to be regenerated.

## Amp-Specific Features

- **Oracle**: For architectural review and debugging
- **Librarian**: For external library documentation
- **finder**: For semantic codebase search
- **Task**: For parallel subagent work

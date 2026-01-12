# Ralph 2.0

AI-Driven Development Orchestrator using the Amp SDK.

## Overview

Ralph 2.0 reimagines the "Ralph Wiggum loop" pattern to leverage Amp's native thread management and SDK for programmatic orchestration.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    RALPH ORCHESTRATOR                        │
│  - Reads specs and creates IMPLEMENTATION_PLAN.md           │
│  - Spawns Amp threads via SDK for each task                 │
│  - Tracks progress and thread assignments                   │
│  - Validates and coordinates completion                     │
└─────────────────────────────────────────────────────────────┘
         │
         ├──▶ Thread: Planning (create plan from specs)
         │
         ├──▶ Thread: Build P0.1 (implement task)
         ├──▶ Thread: Build P0.2 (implement task)
         │    ...
         │
         └──▶ Thread: Validation (final checks)
```

### Thread Map Integration

Build threads include a **coordinator link** that creates visual connections in Amp's Thread Map without polluting context:

```
┌─────────────────────────────────────────┐
│  Thread Map (ampcode.com)               │
│                                         │
│     T-coordinator (Plan)                │
│          │                              │
│          ├── T-build-1 (P0.1)           │
│          ├── T-build-2 (P1.1)           │
│          └── T-build-3 (P2.1)           │
└─────────────────────────────────────────┘
```

**Key insight**: Each build thread includes the coordinator URL as metadata:
```
Coordinator: https://ampcode.com/threads/T-xxx
```

This creates the thread map link **without** using `read_thread`, keeping each build thread's context clean and focused on its specific task.

## Installation

```bash
# From npm (when published)
npm install -g @hmemcpy/ralph-wiggum

# From source
cd sdk
bun install
bun run build
```

## Usage

### CLI

```bash
# Auto mode: plan then build
ralph

# Plan only
ralph plan

# Build only (requires existing IMPLEMENTATION_PLAN.md)
ralph build

# With options
ralph build --verbose --validation "pnpm run check"
ralph -p ./myproject plan
```

### Programmatic

```typescript
import { RalphOrchestrator } from '@hmemcpy/ralph-wiggum';

const ralph = new RalphOrchestrator({
  mode: 'auto',
  verbose: true,
  config: {
    projectDir: './myproject',
    validationCommand: 'pnpm run check',
  },
});

await ralph.run('auto');
```

## Project Setup

Ralph expects this structure:

```
myproject/
├── AGENTS.md                  # Project guidance for Amp
├── specs/                     # Feature specifications
│   └── feature.md
├── IMPLEMENTATION_PLAN.md     # Generated/updated by Ralph
└── src/                       # Your source code
```

### IMPLEMENTATION_PLAN.md Format

```markdown
# Implementation Plan

## Tasks

### P0: Core

- [ ] P0.1 Create user model
  - scope: src/models/user.ts
  - validation: npm run check
  - assigned_thread:
  - status: not_started

- [ ] P0.2 Add user API endpoints
  - scope: src/api/users.ts
  - validation: npm run check
  - assigned_thread:
  - status: not_started
  - depends_on: P0.1
```

## How It Works

1. **Planning Phase**: Ralph reads specs and creates a prioritized task list
2. **Build Phase**: For each task, Ralph:
   - Spawns an Amp thread with focused instructions
   - Includes coordinator URL for thread map linking (no context pollution)
   - Thread implements, validates, and commits
   - Ralph tracks completion via plan file updates
3. **Validation Phase**: Final checks and RALPH_COMPLETE signal

### Context Management

Ralph follows a **clean context** philosophy:

| What | How |
|------|-----|
| **Task context** | Read from `IMPLEMENTATION_PLAN.md` and `specs/*.md` |
| **Thread linking** | URL mention in prompt (creates map link) |
| **No inheritance** | Each thread starts fresh, no `read_thread` pollution |

This keeps threads focused and avoids the "drunk agent" problem of context overload.

### Thread Visibility

All threads appear in your Amp dashboard at [ampcode.com](https://ampcode.com):
- Thread URLs recorded in the plan file for traceability
- Visual thread map shows coordinator → build thread relationships
- Use `threads: map` in Amp CLI to visualize

## Comparison with Ralph 1.0

| Aspect | Ralph 1.0 (Bash) | Ralph 2.0 (SDK) |
|--------|------------------|-----------------|
| Driver | Bash loop + `amp -x` | TypeScript + Amp SDK |
| Thread mgmt | External, disconnected | Native, tracked in plan |
| Thread map | No connections | Coordinator → child links |
| Context | Lost between iterations | Clean, explicit per task |
| Install | Copy scripts | npm package |

## License

MIT

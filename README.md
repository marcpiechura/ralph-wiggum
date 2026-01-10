# Ralph Wiggum Loop - Claude Code Plugin

Generate the complete [Ralph Wiggum loop](https://github.com/ghuntley/how-to-ralph-wiggum) infrastructure for iterative AI-driven development.

## What is Ralph?

An iterative AI development loop where a dumb bash script keeps restarting Claude, and Claude figures out what to do next by reading the plan file each time.

```
┌─────────────────────────────────────────────────────────┐
│                    OUTER LOOP (bash)                    │
│         while :; do cat PROMPT.md | claude ; done       │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                   INNER LOOP (agent)                    │
│   Read plan → Pick task → Implement → Test → Commit     │
└─────────────────────────────────────────────────────────┘
```

Two modes:
- **Planning**: Gap analysis. Output prioritized task list. No implementation.
- **Building**: Implement ONE task, validate, commit, exit. Repeat.

## Installation

### From GitHub (Recommended)

```bash
# Add the marketplace
/plugin marketplace add your-username/claude-ralph-wiggum

# Install the plugin
/plugin install ralph-wiggum
```

### Manual Installation (User-Global)

```bash
# Clone to your home directory
git clone https://github.com/your-username/claude-ralph-wiggum ~/.claude-ralph-wiggum

# Add to Claude Code (run inside Claude Code)
/plugin install ~/.claude-ralph-wiggum --scope user
```

### Manual Installation (Project-Local)

```bash
# Clone into your project
git clone https://github.com/your-username/claude-ralph-wiggum .claude-ralph-wiggum

# Install for this project only
/plugin install .claude-ralph-wiggum --scope local
```

### Test Without Installing

```bash
claude --plugin-dir /path/to/claude-ralph-wiggum
```

## Usage

```bash
# Generate Ralph infrastructure from a feature doc
/ralph-wiggum:ralph docs/my-feature.md

# Auto-discover feature docs in docs/ directory
/ralph-wiggum:ralph
```

The command generates:

| File | Purpose |
|------|---------|
| `specs/*.md` | Feature specs (one topic per file) |
| `IMPLEMENTATION_PLAN.md` | Prioritized task list |
| `PROMPT_plan.md` | Planning mode instructions |
| `PROMPT_build.md` | Building mode instructions |
| `loop.sh` | The bash loop script |

## Running the Loop

After generating the infrastructure:

```bash
# Make loop executable
chmod +x loop.sh

# Run in build mode (default)
./loop.sh

# Run in planning mode
./loop.sh plan

# Limit iterations
./loop.sh 10
./loop.sh plan 5
```

## Core Principles

1. **Deterministic Setup** - Same files seed each loop
2. **One Task Per Iteration** - Maximize context for that task
3. **Backpressure** - Tests must pass before commit
4. **Plan Disposability** - Regenerate when off-track
5. **Search First** - Don't assume not implemented
6. **Let Ralph Ralph** - Agent determines approach

## Requirements

- [Claude Code CLI](https://claude.ai/code)
- `jq` (for parsing JSON output)
- A project with tests/linting (for backpressure)

## Security Warning

Ralph uses `--dangerously-skip-permissions` for autonomous operation. **Always run in a sandboxed environment** (Docker, VM, etc.) to protect credentials and sensitive files.

## License

MIT

## Credits

Based on [How to Ralph Wiggum](https://github.com/ghuntley/how-to-ralph-wiggum) by Geoffrey Huntley.

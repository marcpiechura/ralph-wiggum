#!/bin/bash
# Install/update ralph-wiggum locally for Claude Code and Amp

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo "Installing/updating ralph-wiggum..."

# Claude Code skills: ~/.claude/skills/ralph-wiggum
CLAUDE_SKILL_DIR="$HOME/.claude/skills/ralph-wiggum"
echo -e "${GREEN}Installing Claude Code skill at $CLAUDE_SKILL_DIR${NC}"
mkdir -p "$CLAUDE_SKILL_DIR"
cp -r "$SCRIPT_DIR/.claude-plugin" "$CLAUDE_SKILL_DIR/"
cp -r "$SCRIPT_DIR/commands" "$CLAUDE_SKILL_DIR/"
cp -r "$SCRIPT_DIR/common" "$CLAUDE_SKILL_DIR/"
cp -r "$SCRIPT_DIR/agents" "$CLAUDE_SKILL_DIR/"
cp "$SCRIPT_DIR/README.md" "$CLAUDE_SKILL_DIR/"
echo "  ✓ Claude Code skill installed"

# Amp skill: ~/.config/agents/skills/ralph-wiggum
AMP_SKILL_DIR="$HOME/.config/agents/skills/ralph-wiggum"
echo -e "${GREEN}Installing Amp skill at $AMP_SKILL_DIR${NC}"
mkdir -p "$AMP_SKILL_DIR"
cp -r "$SCRIPT_DIR/common" "$AMP_SKILL_DIR/"
cp -r "$SCRIPT_DIR/agents" "$AMP_SKILL_DIR/"
cp "$SCRIPT_DIR/SKILL.md" "$AMP_SKILL_DIR/"
cp "$SCRIPT_DIR/README.md" "$AMP_SKILL_DIR/"
echo "  ✓ Amp skill installed"

# Ralph binary (SDK)
echo -e "${CYAN}Building Ralph binary...${NC}"
SDK_DIR="$AMP_SKILL_DIR/sdk"
mkdir -p "$SDK_DIR/src"
cp -r "$SCRIPT_DIR/sdk/src/"* "$SDK_DIR/src/"
cp "$SCRIPT_DIR/sdk/package.json" "$SDK_DIR/"
cp "$SCRIPT_DIR/sdk/tsconfig.json" "$SDK_DIR/"
cp "$SCRIPT_DIR/sdk/README.md" "$SDK_DIR/"

LOCAL_BIN="$HOME/.local/bin"

if command -v bun &> /dev/null; then
  echo "  Installing dependencies and compiling..."
  (cd "$SDK_DIR" && bun install --silent && bun run compile 2>/dev/null)
  
  if [[ -f "$SDK_DIR/ralph" ]]; then
    mkdir -p "$LOCAL_BIN"
    cp "$SDK_DIR/ralph" "$LOCAL_BIN/"
    chmod +x "$LOCAL_BIN/ralph"
    echo "  ✓ Ralph binary installed to $LOCAL_BIN/ralph"
    
    if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
      echo -e "${YELLOW}  ⚠ Add $LOCAL_BIN to your PATH:${NC}"
      echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
  else
    echo -e "${YELLOW}  ⚠ Compilation failed, use dev mode instead${NC}"
  fi
else
  echo -e "${YELLOW}  ⚠ bun not found, skipping compilation${NC}"
  echo "    Install bun: curl -fsSL https://bun.sh/install | bash"
  echo "  ✓ SDK source files installed (compile manually)"
fi

echo ""
echo "Done! Installed to:"
echo "  - Claude Code: $CLAUDE_SKILL_DIR"
echo "  - Amp:         $AMP_SKILL_DIR"
echo "  - Binary:      $LOCAL_BIN/ralph"
echo ""
echo "Usage:"
echo "  ralph --help      # Show options"
echo "  ralph plan        # Create plan from specs/"
echo "  ralph build       # Execute tasks"
echo "  ralph auto        # Plan then build"

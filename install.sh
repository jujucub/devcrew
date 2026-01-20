#!/bin/bash
set -e

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════╗"
echo "║       DevCrew Installer               ║"
echo "║  Multi-Agent Collaborative Dev Env    ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"

# インストール先
DEVCREW_HOME="${DEVCREW_HOME:-$HOME/.devcrew}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 依存チェック
echo -e "${BLUE}Checking dependencies...${NC}"

if ! command -v tmux &> /dev/null; then
  echo -e "${RED}✗ tmux is not installed${NC}"
  echo "  Install with: brew install tmux"
  exit 1
fi
echo -e "${GREEN}✓ tmux${NC}"

# エージェントチェック
AGENTS_FOUND=0
if command -v claude &> /dev/null; then
  echo -e "${GREEN}✓ claude (Claude Code CLI)${NC}"
  AGENTS_FOUND=$((AGENTS_FOUND + 1))
fi
if command -v codex &> /dev/null; then
  echo -e "${GREEN}✓ codex (OpenAI Codex CLI)${NC}"
  AGENTS_FOUND=$((AGENTS_FOUND + 1))
fi
if command -v gemini &> /dev/null; then
  echo -e "${GREEN}✓ gemini (Google Gemini CLI)${NC}"
  AGENTS_FOUND=$((AGENTS_FOUND + 1))
fi
if command -v aider &> /dev/null; then
  echo -e "${GREEN}✓ aider (Aider)${NC}"
  AGENTS_FOUND=$((AGENTS_FOUND + 1))
fi

if [ $AGENTS_FOUND -eq 0 ]; then
  echo -e "${YELLOW}⚠ No coding agents found${NC}"
  echo "  Install at least one of the following:"
  echo "    - Claude Code: https://github.com/anthropics/claude-code"
  echo "    - Codex CLI:   https://github.com/openai/codex"
  echo "    - Gemini CLI:  https://github.com/google/gemini-cli"
  echo "    - Aider:       https://github.com/paul-gauthier/aider"
fi

echo ""

# ディレクトリ作成
echo -e "${BLUE}Installing to $DEVCREW_HOME ...${NC}"
mkdir -p "$DEVCREW_HOME/prompts"
mkdir -p "$DEVCREW_HOME/lib/bridge"
mkdir -p "$DEVCREW_HOME/bridge"

# ファイルコピー
cp "$SCRIPT_DIR/bin/devcrew" "$DEVCREW_HOME/"
cp "$SCRIPT_DIR/bin/dc-send" "$DEVCREW_HOME/"
cp "$SCRIPT_DIR/bin/dc-status" "$DEVCREW_HOME/"
cp "$SCRIPT_DIR/bin/dc-bridge" "$DEVCREW_HOME/"
cp "$SCRIPT_DIR/bin/lib/common.sh" "$DEVCREW_HOME/lib/"
cp "$SCRIPT_DIR/bin/lib/bridge/"*.sh "$DEVCREW_HOME/lib/bridge/"
cp "$SCRIPT_DIR/prompts/"*.md "$DEVCREW_HOME/prompts/"

# 設定ファイル（既存の場合は上書きしない）
if [ ! -f "$DEVCREW_HOME/config" ]; then
  cp "$SCRIPT_DIR/config.example" "$DEVCREW_HOME/config"
  echo -e "${GREEN}✓ Config file created${NC}"
else
  echo -e "${YELLOW}✓ Config file preserved (already exists)${NC}"
fi

# config.exampleもコピー（参照用）
cp "$SCRIPT_DIR/config.example" "$DEVCREW_HOME/config.example"

# 実行権限
chmod +x "$DEVCREW_HOME/devcrew"
chmod +x "$DEVCREW_HOME/dc-send"
chmod +x "$DEVCREW_HOME/dc-status"
chmod +x "$DEVCREW_HOME/dc-bridge"

echo -e "${GREEN}✓ Files installed${NC}"

# PATH設定の確認
SHELL_RC=""
if [ -f "$HOME/.zshrc" ]; then
  SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
  SHELL_RC="$HOME/.bashrc"
fi

PATH_LINE='export PATH="$HOME/.devcrew:$PATH"'

if [ -n "$SHELL_RC" ]; then
  if grep -q "\.devcrew" "$SHELL_RC" 2>/dev/null; then
    echo -e "${GREEN}✓ PATH already configured${NC}"
  else
    echo ""
    echo -e "${YELLOW}Add the following to $SHELL_RC:${NC}"
    echo ""
    echo "  $PATH_LINE"
    echo ""
    read -p "Add automatically? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo "" >> "$SHELL_RC"
      echo "# DevCrew - Multi-Agent Collaborative Dev Environment" >> "$SHELL_RC"
      echo "$PATH_LINE" >> "$SHELL_RC"
      echo -e "${GREEN}✓ PATH added to $SHELL_RC${NC}"
      echo -e "${YELLOW}Run 'source $SHELL_RC' or restart terminal${NC}"
    fi
  fi
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       Installation Complete!          ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo "Usage:"
echo "  devcrew          # Start with 4 agents (default)"
echo "  devcrew -2       # Start with 2 agents"
echo "  devcrew -c       # Show current configuration"
echo "  devcrew -h       # Show help"
echo ""
echo "Commands:"
echo "  dc-send <target> <message>  # Send message to agent"
echo "  dc-status                   # Show agent status"
echo "  dc-bridge start             # Start Bridge (control system)"
echo "  dc-bridge status            # Show Bridge status"
echo ""
echo "Configuration:"
echo "  Edit ~/.devcrew/config to customize agent assignments"
echo "  Example: CODER_AGENT=\"codex\""
echo ""

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

if ! command -v claude &> /dev/null; then
  echo -e "${YELLOW}⚠ claude is not installed${NC}"
  echo "  Claude Code CLI is required to run agents"
  echo "  Install from: https://github.com/anthropics/claude-code"
else
  echo -e "${GREEN}✓ claude${NC}"
fi

echo ""

# ディレクトリ作成
echo -e "${BLUE}Installing to $DEVCREW_HOME ...${NC}"
mkdir -p "$DEVCREW_HOME/prompts"

# ファイルコピー
cp "$SCRIPT_DIR/bin/devcrew" "$DEVCREW_HOME/"
cp "$SCRIPT_DIR/bin/dc-send" "$DEVCREW_HOME/"
cp "$SCRIPT_DIR/bin/dc-status" "$DEVCREW_HOME/"
cp "$SCRIPT_DIR/prompts/"*.md "$DEVCREW_HOME/prompts/"

# 実行権限
chmod +x "$DEVCREW_HOME/devcrew"
chmod +x "$DEVCREW_HOME/dc-send"
chmod +x "$DEVCREW_HOME/dc-status"

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
echo "  devcrew -h       # Show help"
echo ""
echo "Commands:"
echo "  dc-send <target> <message>  # Send message to agent"
echo "  dc-status                   # Show agent status"
echo ""

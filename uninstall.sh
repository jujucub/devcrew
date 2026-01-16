#!/bin/bash

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════╗"
echo "║       DevCrew Uninstaller             ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"

DEVCREW_HOME="${DEVCREW_HOME:-$HOME/.devcrew}"

# 確認
echo -e "${YELLOW}This will remove:${NC}"
echo "  - $DEVCREW_HOME"
echo ""
read -p "Continue? [y/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi

# セッション終了
if tmux has-session -t devcrew 2>/dev/null; then
  echo -e "${BLUE}Killing devcrew session...${NC}"
  tmux kill-session -t devcrew
  echo -e "${GREEN}✓ Session terminated${NC}"
fi

# ファイル削除
if [ -d "$DEVCREW_HOME" ]; then
  rm -rf "$DEVCREW_HOME"
  echo -e "${GREEN}✓ Removed $DEVCREW_HOME${NC}"
else
  echo -e "${YELLOW}$DEVCREW_HOME not found${NC}"
fi

echo ""
echo -e "${YELLOW}Note: PATH configuration in .zshrc/.bashrc was not removed.${NC}"
echo "You may want to manually remove the following line:"
echo ""
echo '  export PATH="$HOME/.devcrew:$PATH"'
echo ""
echo -e "${GREEN}Uninstall complete.${NC}"

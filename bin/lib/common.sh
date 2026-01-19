#!/bin/bash
#
# DevCrew 共通ライブラリ
# 色定義、共通変数、共通関数を提供
#

# ============================================================
# 色定義
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================
# 共通変数
# ============================================================
SESSION="devcrew"
DEVCREW_HOME="${DEVCREW_HOME:-$HOME/.devcrew}"

# ============================================================
# 共通関数
# ============================================================

# エラーメッセージを表示して終了
# 引数: $1 - エラーメッセージ, $2 - 終了コード（省略時は1）
ErrorExit() {
  echo -e "${RED}Error: $1${NC}" >&2
  exit "${2:-1}"
}

# エラーメッセージを表示（終了しない）
# 引数: $1 - エラーメッセージ
Error() {
  echo -e "${RED}Error: $1${NC}" >&2
}

# 情報メッセージを表示（青）
# 引数: $1 - メッセージ
Info() {
  echo -e "${BLUE}$1${NC}"
}

# 成功メッセージを表示（緑）
# 引数: $1 - メッセージ
Success() {
  echo -e "${GREEN}$1${NC}"
}

# 警告メッセージを表示（黄）
# 引数: $1 - メッセージ
Warn() {
  echo -e "${YELLOW}$1${NC}"
}

# devcrewセッションの存在確認
# 戻り値: 0 - セッション存在, 1 - セッション不在
CheckSession() {
  if tmux has-session -t "$SESSION" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# devcrewセッションが存在しない場合にエラー終了
# 引数: なし
RequireSession() {
  if ! CheckSession; then
    ErrorExit "devcrew session is not running\nStart with: devcrew"
  fi
}

# devcrewセッションのモードを取得
# 戻り値: team または duo
GetMode() {
  local mode
  mode=$(tmux show-environment -t "$SESSION" DEVCREW_MODE 2>/dev/null | cut -d= -f2)
  echo "${mode:-team}"
}

#!/bin/bash
#
# Bridge Monitor - 状態監視モジュール
# 各エージェントの状態を収集し state.json に出力
#

# 承認待ちパターン
APPROVAL_PATTERNS_CLAUDE=(
  "No, and tell Claude what to do differently"
  "Do you want to proceed?"
)
APPROVAL_PATTERNS_AIDER=(
  "(Y)es/(N)o/(D)on't ask again"
)
APPROVAL_PATTERNS_CODEX=(
  "Allow this action"
)
APPROVAL_PATTERNS_GEMINI=(
  "Yes, allow once"
)

# プレビュー行数
PREVIEW_LINES=3

# ============================================================
# ペインのステータスを判定
# ============================================================
detect_pane_status() {
  local pane=$1
  local content="$2"

  # 承認待ちパターンをチェック
  for pattern in "${APPROVAL_PATTERNS_CLAUDE[@]}"; do
    if echo "$content" | grep -qF "$pattern"; then
      echo "waiting_approval"
      return
    fi
  done
  for pattern in "${APPROVAL_PATTERNS_AIDER[@]}"; do
    if echo "$content" | grep -qF "$pattern"; then
      echo "waiting_approval"
      return
    fi
  done
  for pattern in "${APPROVAL_PATTERNS_CODEX[@]}"; do
    if echo "$content" | grep -qF "$pattern"; then
      echo "waiting_approval"
      return
    fi
  done
  for pattern in "${APPROVAL_PATTERNS_GEMINI[@]}"; do
    if echo "$content" | grep -qF "$pattern"; then
      echo "waiting_approval"
      return
    fi
  done

  # 入力待ち（プロンプトが表示されている）
  # Claude Code: ">" で終わる行
  # Codex: ">" で終わる行
  if echo "$content" | tail -5 | grep -qE '^\s*>\s*$|>\s*$'; then
    echo "idle"
    return
  fi

  # それ以外は実行中
  echo "running"
}

# ============================================================
# 承認待ちの詳細を取得
# ============================================================
get_approval_details() {
  local pane=$1
  local content="$2"
  local agent=$3

  # 承認内容の説明を抽出（パターンの前の行）
  local description=""

  # Claude Codeの場合、直前のコンテキストを取得
  description=$(echo "$content" | grep -B 5 "Do you want to proceed" | head -3 | tr '\n' ' ' | sed 's/  */ /g')

  if [ -z "$description" ]; then
    description="Action requires approval"
  fi

  echo "$description"
}

# ============================================================
# ペインのプレビューを取得
# ============================================================
get_pane_preview() {
  local content="$1"

  # 最後の数行を取得し、空行を除去
  echo "$content" | tail -$PREVIEW_LINES | grep -v '^$' | head -1 | cut -c1-60
}

# ============================================================
# 状態を更新
# ============================================================
update_state() {
  local mode=$(GetMode)
  local project=$(tmux show-environment -t "$SESSION" DEVCREW_PROJECT 2>/dev/null | cut -d= -f2)
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # モードに応じたエージェント設定
  if [ "$mode" = "duo" ]; then
    local roles=("coder" "reviewer")
    local panes=(0 1)
  else
    local roles=("leader" "coder" "reviewer" "tester")
    local panes=(0 1 2 3)
  fi

  # JSON構築開始
  local agents_json="{"
  local pending_json="["
  local pending_count=0
  local first_agent=true

  for i in "${!roles[@]}"; do
    local role="${roles[$i]}"
    local pane="${panes[$i]}"

    # ペイン内容をキャプチャ
    local content=$(tmux capture-pane -t "$SESSION:0.$pane" -p 2>/dev/null || echo "")

    # ステータス判定
    local status=$(detect_pane_status "$pane" "$content")

    # プレビュー取得
    local preview=$(get_pane_preview "$content")
    preview=$(echo "$preview" | sed 's/"/\\"/g')  # エスケープ

    # 承認待ちの場合は詳細を追加
    if [ "$status" = "waiting_approval" ]; then
      local description=$(get_approval_details "$pane" "$content" "$role")
      description=$(echo "$description" | sed 's/"/\\"/g')  # エスケープ

      local approval_id="appr-${role}-$(date +%s)"

      if [ $pending_count -gt 0 ]; then
        pending_json+=","
      fi
      pending_json+="{\"id\":\"$approval_id\",\"agent\":\"$role\",\"pane\":$pane,\"description\":\"$description\",\"detectedAt\":\"$timestamp\"}"
      ((pending_count++))
    fi

    # エージェントJSON追加
    if [ "$first_agent" = true ]; then
      first_agent=false
    else
      agents_json+=","
    fi
    agents_json+="\"$role\":{\"pane\":$pane,\"status\":\"$status\",\"lastActivity\":\"$timestamp\",\"preview\":\"$preview\"}"
  done

  agents_json+="}"
  pending_json+="]"

  # 最終JSON
  local state_json=$(cat << EOF
{
  "version": "1.0",
  "session": "$SESSION",
  "mode": "$mode",
  "project": "$project",
  "updatedAt": "$timestamp",
  "agents": $agents_json,
  "pendingApprovals": $pending_json
}
EOF
)

  # ファイルに書き出し（アトミック書き込み）
  local tmp_file="$STATE_FILE.tmp"
  echo "$state_json" > "$tmp_file"
  mv "$tmp_file" "$STATE_FILE"
}

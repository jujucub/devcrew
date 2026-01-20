#!/bin/bash
#
# Bridge Commander - 指示送信モジュール
# commands.json からコマンドを読み取り、エージェントに送信
#

# ============================================================
# ターゲットからペイン番号を解決
# ============================================================
resolve_target_pane() {
  local target=$1
  local mode=$(GetMode)

  if [ "$mode" = "duo" ]; then
    case $target in
      "coder"|"0")    echo "0" ;;
      "reviewer"|"1") echo "1" ;;
      "all")          echo "all" ;;
      *)              echo "" ;;
    esac
  else
    case $target in
      "leader"|"0")   echo "0" ;;
      "coder"|"1")    echo "1" ;;
      "reviewer"|"2") echo "2" ;;
      "tester"|"3")   echo "3" ;;
      "all")          echo "all" ;;
      *)              echo "" ;;
    esac
  fi
}

# ============================================================
# メッセージを送信
# ============================================================
send_message_to_pane() {
  local pane=$1
  local message="$2"

  # マルチラインメッセージ対応
  local tmpfile=$(mktemp)
  echo -n "$message" > "$tmpfile"
  tmux load-buffer -b bridge_msg "$tmpfile"
  rm -f "$tmpfile"

  tmux paste-buffer -b bridge_msg -t "$SESSION:0.$pane"
  sleep 0.2
  tmux send-keys -t "$SESSION:0.$pane" Enter

  tmux delete-buffer -b bridge_msg 2>/dev/null || true
}

# ============================================================
# コマンドを追加
# ============================================================
add_command() {
  local cmd_type=$1
  local target=$2
  local content="$3"
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local cmd_id="cmd-$(date +%s%N | cut -c1-13)"

  # jqがない場合はシンプルな追加
  if ! command -v jq &> /dev/null; then
    # フォールバック：直接ファイル操作
    Warn "jq not found. Using simple append."
    return 1
  fi

  # コマンドをpendingに追加
  local new_cmd="{\"id\":\"$cmd_id\",\"type\":\"$cmd_type\",\"target\":\"$target\",\"content\":\"$content\",\"createdAt\":\"$timestamp\"}"

  jq ".pending += [$new_cmd]" "$COMMANDS_FILE" > "$COMMANDS_FILE.tmp" && mv "$COMMANDS_FILE.tmp" "$COMMANDS_FILE"
}

# ============================================================
# コマンドを処理
# ============================================================
process_commands() {
  # jqがない場合はスキップ
  if ! command -v jq &> /dev/null; then
    return 0
  fi

  # commands.json が存在しない場合はスキップ
  if [ ! -f "$COMMANDS_FILE" ]; then
    return 0
  fi

  # pending コマンドを取得
  local pending_count=$(jq -r '.pending | length' "$COMMANDS_FILE" 2>/dev/null || echo "0")

  if [ "$pending_count" -eq 0 ]; then
    return 0
  fi

  # 各コマンドを処理
  local i=0
  while [ $i -lt $pending_count ]; do
    local cmd=$(jq -r ".pending[$i]" "$COMMANDS_FILE")
    local cmd_id=$(echo "$cmd" | jq -r '.id')
    local cmd_type=$(echo "$cmd" | jq -r '.type')
    local target=$(echo "$cmd" | jq -r '.target')
    local content=$(echo "$cmd" | jq -r '.content')

    case $cmd_type in
      "message")
        process_message_command "$target" "$content"
        ;;
      "approval")
        local approval_id=$(echo "$cmd" | jq -r '.approvalId')
        local response=$(echo "$cmd" | jq -r '.response')
        process_approval_command "$approval_id" "$response" "$content"
        ;;
      "broadcast")
        process_broadcast_command "$content"
        ;;
      *)
        Warn "Unknown command type: $cmd_type"
        ;;
    esac

    ((i++))
  done

  # 処理済みコマンドを移動
  jq '.processed = .processed + .pending | .pending = []' "$COMMANDS_FILE" > "$COMMANDS_FILE.tmp" && mv "$COMMANDS_FILE.tmp" "$COMMANDS_FILE"
}

# ============================================================
# メッセージコマンドを処理
# ============================================================
process_message_command() {
  local target=$1
  local content="$2"

  local pane=$(resolve_target_pane "$target")

  if [ -z "$pane" ]; then
    Error "Unknown target: $target"
    return 1
  fi

  if [ "$pane" = "all" ]; then
    # 全員に送信
    local mode=$(GetMode)
    if [ "$mode" = "duo" ]; then
      send_message_to_pane 0 "$content"
      send_message_to_pane 1 "$content"
    else
      send_message_to_pane 0 "$content"
      send_message_to_pane 1 "$content"
      send_message_to_pane 2 "$content"
      send_message_to_pane 3 "$content"
    fi
    Info "Broadcast sent to all agents"
  else
    send_message_to_pane "$pane" "$content"
    Info "Message sent to pane $pane"
  fi
}

# ============================================================
# 承認コマンドを処理
# ============================================================
process_approval_command() {
  local approval_id=$1
  local response=$2
  local custom_message="$3"

  # state.json から承認待ちを検索
  if [ ! -f "$STATE_FILE" ]; then
    Error "state.json not found"
    return 1
  fi

  local approval=$(jq -r ".pendingApprovals[] | select(.id == \"$approval_id\")" "$STATE_FILE" 2>/dev/null)

  if [ -z "$approval" ]; then
    Warn "Approval not found: $approval_id"
    return 1
  fi

  local pane=$(echo "$approval" | jq -r '.pane')
  local agent=$(echo "$approval" | jq -r '.agent')

  case $response in
    "yes")
      # Yを送信
      tmux send-keys -t "$SESSION:0.$pane" "y" Enter
      Success "Approved: $agent (pane $pane)"
      ;;
    "no")
      # Nを送信
      tmux send-keys -t "$SESSION:0.$pane" "n" Enter
      Info "Rejected: $agent (pane $pane)"
      ;;
    "custom")
      # カスタムメッセージを送信
      if [ -n "$custom_message" ]; then
        send_message_to_pane "$pane" "$custom_message"
        Info "Custom response sent to $agent (pane $pane)"
      else
        Warn "Custom message is empty"
      fi
      ;;
    *)
      Warn "Unknown response: $response"
      ;;
  esac
}

# ============================================================
# ブロードキャストコマンドを処理
# ============================================================
process_broadcast_command() {
  local content="$1"
  process_message_command "all" "$content"
}

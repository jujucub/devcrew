# Bridge 設計書

## 概要

**Bridge** は devcrew の管制システム。各エージェント（Leader/Coder/Reviewer/Tester）の状態を監視し、承認リクエストの集約と指示の送信を担う。

将来的にはGUI Viewerと連携し、キャラクターベースのインターフェースを提供する。

---

## 名前の由来

「Bridge（艦橋）」= 船長が全体を見渡し指揮を執る場所。devcrewの「クルー（乗組員）」という世界観に合わせた命名。

---

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                        devcrew (tmux)                       │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐          │
│  │ Leader  │ │ Coder   │ │Reviewer │ │ Tester  │          │
│  │  pane:0 │ │  pane:1 │ │  pane:2 │ │  pane:3 │          │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘          │
│       └───────────┴───────────┴───────────┘                │
│                       │                                     │
│              tmux capture-pane / send-keys                  │
└───────────────────────┼─────────────────────────────────────┘
                        │
                        ▼
┌───────────────────────────────────────────────────────────────┐
│                         Bridge                                 │
│                                                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Monitor   │  │  Approver   │  │     Commander       │  │
│  │             │  │             │  │                     │  │
│  │ - pane監視  │  │ - 承認検知  │  │ - 指示送信          │  │
│  │ - 状態収集  │  │ - 承認実行  │  │ - メッセージ配信    │  │
│  │ - 変更検知  │  │ - 拒否+指示 │  │                     │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
│         └────────────────┼───────────────────┘              │
│                          ▼                                   │
│                  ┌──────────────┐                            │
│                  │  State File  │                            │
│                  │  state.json  │                            │
│                  └──────────────┘                            │
│                          │                                   │
│                   WebSocket (Phase 2)                        │
└──────────────────────────┼───────────────────────────────────┘
                           │
                           ▼
┌───────────────────────────────────────────────────────────────┐
│                     Viewer (将来)                              │
│  - キャラクター表示                                            │
│  - 承認UI                                                     │
│  - 指示パネル                                                  │
└───────────────────────────────────────────────────────────────┘
```

---

## コンポーネント

### 1. Monitor（状態監視）

各エージェントのtmux paneを定期的にキャプチャし、状態を収集する。

**責務:**
- pane内容のキャプチャ（`tmux capture-pane`）
- 状態判定（running / idle / waiting_approval）
- 変更検知（ハッシュ比較）
- state.json への書き出し

### 2. Approver（承認管理）

承認待ちプロンプトを検知し、ユーザーの承認/拒否をエージェントに伝達する。

**責務:**
- 承認待ちパターンの検知
- 承認リクエストの集約
- 承認/拒否の実行（`tmux send-keys`）
- カスタム指示付き拒否

### 3. Commander（指示送信）

ユーザーからの指示を適切なエージェントに送信する。

**責務:**
- 指示の受付（commands.json / WebSocket）
- 対象エージェントの特定
- メッセージ送信（`dc-send` 相当）

---

## ファイル構造

### ディレクトリ

```
~/.devcrew/
├── bridge/
│   ├── state.json       # 現在の状態
│   ├── commands.json    # 待機中のコマンド
│   ├── history.json     # 履歴（オプション）
│   └── config.json      # Bridge設定
└── ...
```

### state.json

```json
{
  "version": "1.0",
  "session": "devcrew",
  "mode": "team",
  "project": "/path/to/project",
  "updatedAt": "2025-01-20T10:30:00Z",

  "agents": {
    "leader": {
      "pane": 0,
      "status": "running",
      "lastActivity": "2025-01-20T10:30:00Z",
      "preview": "タスクを分析しています..."
    },
    "coder": {
      "pane": 1,
      "status": "waiting_approval",
      "lastActivity": "2025-01-20T10:30:05Z",
      "preview": "src/UserService.ts を編集中..."
    },
    "reviewer": {
      "pane": 2,
      "status": "idle",
      "lastActivity": "2025-01-20T10:29:00Z",
      "preview": "レビュー待ち"
    },
    "tester": {
      "pane": 3,
      "status": "idle",
      "lastActivity": "2025-01-20T10:28:00Z",
      "preview": "テスト待ち"
    }
  },

  "pendingApprovals": [
    {
      "id": "appr-001",
      "agent": "coder",
      "pane": 1,
      "type": "file_edit",
      "description": "src/UserService.ts を編集します",
      "context": "+ import { Logger } from './utils/logger';",
      "detectedAt": "2025-01-20T10:30:05Z"
    }
  ]
}
```

### commands.json

```json
{
  "version": "1.0",
  "pending": [
    {
      "id": "cmd-001",
      "type": "message",
      "target": "coder",
      "content": "エラーハンドリングを追加してください",
      "createdAt": "2025-01-20T10:31:00Z"
    },
    {
      "id": "cmd-002",
      "type": "approval",
      "approvalId": "appr-001",
      "response": "yes",
      "customMessage": null,
      "createdAt": "2025-01-20T10:31:05Z"
    }
  ],
  "processed": []
}
```

### config.json

```json
{
  "pollInterval": 1000,
  "approvalPatterns": {
    "claude": [
      "No, and tell Claude what to do differently",
      "Do you want to proceed?"
    ],
    "aider": [
      "(Y)es/(N)o/(D)on't ask again"
    ],
    "codex": [
      "Allow this action"
    ],
    "gemini": [
      "Yes, allow once"
    ]
  },
  "previewLines": 5
}
```

---

## 承認フロー

```
┌─────────────────────────────────────────────────────────────┐
│ 1. 検知フェーズ                                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   Bridge (Monitor)                                          │
│       │                                                     │
│       │ tmux capture-pane -t devcrew:0.1 -p                │
│       ▼                                                     │
│   ┌─────────────────────────────────────────┐              │
│   │ "... Do you want to proceed?           │              │
│   │  No, and tell Claude what to do...     │              │
│   │  Yes, allow once                       │              │
│   │  Yes, always allow  ← カーソル位置      │              │
│   └─────────────────────────────────────────┘              │
│       │                                                     │
│       │ パターンマッチ                                       │
│       ▼                                                     │
│   承認待ち検知 → state.json に追加                           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. 通知フェーズ                                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   Viewer / CLI が state.json を監視                         │
│       │                                                     │
│       │ pendingApprovals に新規追加を検知                   │
│       ▼                                                     │
│   ユーザーに通知                                             │
│   - Viewer: ポップアップ / バッジ                            │
│   - CLI: ターミナル通知                                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. 応答フェーズ                                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   ユーザーが承認/拒否を選択                                   │
│       │                                                     │
│       │ commands.json に書き込み                            │
│       ▼                                                     │
│   {                                                         │
│     "type": "approval",                                     │
│     "approvalId": "appr-001",                               │
│     "response": "yes"                                       │
│   }                                                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. 実行フェーズ                                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   Bridge (Approver)                                         │
│       │                                                     │
│       │ commands.json から承認コマンドを取得                 │
│       ▼                                                     │
│   対象paneにキー送信                                         │
│                                                             │
│   tmux send-keys -t devcrew:0.1 "y" Enter                  │
│                                                             │
│       │                                                     │
│       ▼                                                     │
│   state.json から pendingApprovals を削除                   │
│   commands.json の processed に移動                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 指示送信フロー

```
┌─────────────────────────────────────────────────────────────┐
│ ユーザー入力                                                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   Viewer / CLI                                              │
│       │                                                     │
│       │ 「Coderにエラーハンドリング追加を指示」               │
│       ▼                                                     │
│   commands.json に書き込み                                   │
│   {                                                         │
│     "type": "message",                                      │
│     "target": "coder",                                      │
│     "content": "エラーハンドリングを追加してください"         │
│   }                                                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ Bridge (Commander)                                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   commands.json を監視                                       │
│       │                                                     │
│       │ 新規コマンドを検知                                   │
│       ▼                                                     │
│   対象エージェントを特定                                      │
│   - target: "coder" → pane: 1                              │
│   - target: "all" → pane: 0,1,2,3                          │
│       │                                                     │
│       ▼                                                     │
│   メッセージ送信                                             │
│                                                             │
│   # dc-send 相当の処理                                       │
│   tmux load-buffer -b msg <<< "$content"                    │
│   tmux paste-buffer -b msg -t devcrew:0.1                   │
│   tmux send-keys -t devcrew:0.1 Enter                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## コマンドタイプ

| type | 説明 | 必須フィールド |
|------|------|---------------|
| `message` | エージェントへの指示 | target, content |
| `approval` | 承認/拒否 | approvalId, response |
| `broadcast` | 全員への通知 | content |
| `pause` | エージェント一時停止 | target |
| `resume` | エージェント再開 | target |

### response の種類（approval用）

| response | 動作 |
|----------|------|
| `yes` | 承認（Enter or "y" + Enter） |
| `no` | 拒否（"n" + Enter） |
| `custom` | カスタム指示（customMessage を送信） |

---

## CLI インターフェース

### dc-bridge（新規）

```bash
# Bridge起動（フォアグラウンド）
dc-bridge

# Bridge起動（バックグラウンド）
dc-bridge --daemon

# 状態確認
dc-bridge status

# 停止
dc-bridge stop
```

### 既存コマンドとの連携

```bash
# 従来通りの直接指示（dc-send）
dc-send coder "実装してください"

# Bridge経由の指示（同等の動作）
dc-bridge send coder "実装してください"

# 承認（Bridge経由のみ）
dc-bridge approve appr-001
dc-bridge approve --all
dc-bridge reject appr-001 --message "別の方法で"
```

---

## 実装フェーズ

### Phase 1: 基本機能

- [ ] state.json 出力（Monitor）
- [ ] commands.json 読み取り（Commander）
- [ ] メッセージ送信機能
- [ ] dc-bridge コマンド実装

### Phase 2: 承認機能

- [ ] 承認待ちパターン検知
- [ ] pendingApprovals 管理
- [ ] 承認/拒否コマンド実行
- [ ] 承認CLI（dc-bridge approve）

### Phase 3: Viewer連携

- [ ] WebSocketサーバー
- [ ] リアルタイム状態配信
- [ ] Viewer用API

---

## ファイル配置（実装時）

```
bin/
├── devcrew          # 既存
├── dc-send          # 既存
├── dc-status        # 既存
├── dc-bridge        # 新規: Bridge本体
└── lib/
    ├── common.sh    # 既存
    └── bridge/
        ├── monitor.sh    # 状態監視
        ├── approver.sh   # 承認管理
        └── commander.sh  # 指示送信
```

---

## 参考

- [類似ツール調査](./research-similar-tools.md)
- Claude Squad の AutoYes 実装

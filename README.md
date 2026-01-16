# DevCrew

マルチエージェント協調開発環境

tmuxを使って複数のAIコーディングエージェントを同時に起動し、エージェント間で通信しながら協調して開発を行う環境を提供します。

## 特徴

- **マルチエージェント**: 複数のエージェントを役割分担して同時実行
- **複数エージェント対応**: Claude Code、Codex、Gemini、Aiderなど
- **役割ごとにエージェント指定可能**: CoderはCodex、ReviewerはClaudeなど
- **エージェント間通信**: `dc-send` コマンドでエージェント間のメッセージ送受信
- **2つのモード**: 4人構成（Team）と2人構成（Duo）を選択可能
- **協調作業**: Leader/Coder/Reviewer/Testerがチームとして連携

## 対応エージェント

| エージェント | コマンド | 説明 |
|-------------|---------|------|
| Claude Code | `claude` | Anthropic Claude Code CLI |
| Codex | `codex` | OpenAI Codex CLI |
| Gemini | `gemini` | Google Gemini CLI |
| Aider | `aider` | Aider |

## 必要要件

- macOS / Linux
- [tmux](https://github.com/tmux/tmux)
- 以下のいずれかのコーディングエージェント:
  - [Claude Code CLI](https://github.com/anthropics/claude-code)
  - [Codex CLI](https://github.com/openai/codex)
  - [Gemini CLI](https://github.com/google/gemini-cli)
  - [Aider](https://github.com/paul-gauthier/aider)

## インストール

```bash
git clone https://github.com/jujucub/devcrew.git
cd devcrew
./install.sh
```

インストール後、ターミナルを再起動するか以下を実行:

```bash
source ~/.zshrc  # または source ~/.bashrc
```

## 使い方

### 基本

```bash
# カレントディレクトリで4人構成（デフォルト）
devcrew

# カレントディレクトリで2人構成
devcrew -2

# 特定のディレクトリで起動
devcrew ~/projects/my-app
devcrew -2 ~/projects/my-app

# 現在の設定を確認
devcrew -c
```

### オプション

| オプション | 説明 |
|-----------|------|
| `-2`, `--duo` | 2人構成で起動 |
| `-4`, `--team` | 4人構成で起動（デフォルト） |
| `-c`, `--config` | 現在の設定を表示 |
| `-k`, `--kill` | 既存セッションを終了 |
| `-h`, `--help` | ヘルプを表示 |

### エージェント間通信

```bash
# 特定のエージェントにメッセージ送信
dc-send coder "UserServiceを実装してください"
dc-send reviewer "src/user.ts をレビューお願いします"

# 全員に送信
dc-send all "作業を一時停止してください"

# 状態確認
dc-status
```

## エージェント構成

### Team Mode（4人構成）

```
┌─────────────────────────────────────────────┐
│                   Leader                     │
│            タスク管理・指示出し               │
└─────────────────┬───────────────────────────┘
                  │
    ┌─────────────┼─────────────┐
    ▼             ▼             ▼
┌────────┐  ┌──────────┐  ┌─────────┐
│ Coder  │  │ Reviewer │  │ Tester  │
│  実装  │→ │ レビュー │→ │ テスト  │
└────────┘  └──────────┘  └─────────┘
```

| エージェント | 役割 | ターゲット名 |
|-------------|------|-------------|
| Leader | タスク管理、指示、進捗管理 | `leader` or `0` |
| Coder | コード実装 | `coder` or `1` |
| Reviewer | コードレビュー | `reviewer` or `2` |
| Tester | テスト作成・実行 | `tester` or `3` |

### Duo Mode（2人構成）

```
┌─────────────┬─────────────┐
│   Coder     │  Reviewer   │
│    実装     │   レビュー   │
└─────────────┴─────────────┘
```

| エージェント | 役割 | ターゲット名 |
|-------------|------|-------------|
| Coder | コード実装 | `coder` or `0` |
| Reviewer | コードレビュー | `reviewer` or `1` |

## エージェント設定

`~/.devcrew/config` を編集して、各役割に使用するエージェントを指定できます。

### 設定例

```bash
# Team Mode - 全員Claude
LEADER_AGENT="claude"
CODER_AGENT="claude"
REVIEWER_AGENT="claude"
TESTER_AGENT="claude"

# Team Mode - 異なるエージェントを組み合わせ
LEADER_AGENT="claude"
CODER_AGENT="codex"
REVIEWER_AGENT="gemini"
TESTER_AGENT="claude"

# Duo Mode
CODER_DUO_AGENT="claude"
REVIEWER_DUO_AGENT="codex"
```

### 設定確認

```bash
devcrew -c
```

## プロンプトのカスタマイズ

`~/.devcrew/prompts/` 内のMarkdownファイルを編集することで、各エージェントの振る舞いをカスタマイズできます。

```
~/.devcrew/prompts/
├── leader.md       # 4人用: リーダー
├── coder.md        # 4人用: コーダー
├── reviewer.md     # 4人用: レビュアー
├── tester.md       # 4人用: テスター
├── coder-duo.md    # 2人用: コーダー
└── reviewer-duo.md # 2人用: レビュアー
```

## tmux操作

| キー | 操作 |
|------|------|
| `Ctrl+b d` | デタッチ（セッションを維持したまま抜ける） |
| `Ctrl+b o` | ペイン切り替え |
| `Ctrl+b q` | ペイン番号表示 |
| `Ctrl+b z` | ペイン最大化/戻す |
| `Ctrl+b [` | スクロールモード（qで抜ける） |

## アンインストール

```bash
./uninstall.sh
```

## ライセンス

MIT

## 参考

- [Claude-Code-Communication](https://github.com/nishimoto265/Claude-Code-Communication)

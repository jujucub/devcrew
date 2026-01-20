# 類似ツール調査メモ

調査日: 2025-01-20

## 概要

devcrewの改善に向けて、類似のマルチエージェントオーケストレーションツールを調査した。

---

## 調査したツール一覧

| ツール名 | 概要 | URL |
|---------|------|-----|
| Claude Squad | Go製TUI、複数エージェント管理 | https://github.com/smtg-ai/claude-squad |
| AgentPipe | エージェント間の共有ルーム通信 | https://github.com/kevinelliott/agentpipe |
| Conductor | git worktreeベースの分離 | https://addyo.substack.com/p/conductors-to-orchestrators-the-future |
| Tembo | クラウドベースの並列実行 | https://www.tembo.io/blog/how-to-run-claude-code-in-parallel |
| Warp Terminal | エージェント機能組み込みターミナル | https://www.warp.dev/ |

---

## Claude Squad 詳細分析

### 基本情報

- **言語**: Go (86.6%)
- **UI**: bubbletea (TUI)
- **内部**: tmuxを使用
- **リポジトリ**: https://github.com/smtg-ai/claude-squad

### アーキテクチャ

```
claude-squad/
├── app/          # アプリケーションロジック
├── cmd/          # コマンド実装
├── daemon/       # バックグラウンドプロセス
├── ui/           # TUIコンポーネント
├── session/      # セッション管理
│   ├── git/      # git worktree操作
│   └── tmux/     # tmux統合
├── config/       # 設定ファイル
└── web/          # Next.jsベースのWebUI（オプション）
```

### AutoYes（自動承認）実装

#### 設定

```go
type Config struct {
    DefaultProgram     string
    AutoYes            bool   // 自動承認フラグ
    DaemonPollInterval int    // ポーリング間隔（ms）
    BranchPrefix       string
}
```

#### プロンプト検知の仕組み

1. **画面キャプチャ**: `tmux capture-pane -p -e -J` で画面内容を取得
2. **ハッシュ比較**: SHA256で前回との差分を検知
3. **文字列マッチ**: エージェント固有のプロンプト文字列を検索

#### 検知パターン（ハードコード）

| エージェント | 検知文字列 |
|-------------|-----------|
| Claude Code | `"No, and tell Claude what to do differently"` |
| Aider | `"(Y)es/(N)o/(D)on't ask again"` |
| Gemini CLI | `"Yes, allow once"` |

#### 自動承認フロー

```
┌─────────────────────────────────────────┐
│  500msごとにポーリング                    │
└──────────────┬──────────────────────────┘
               ▼
┌─────────────────────────────────────────┐
│  HasUpdated() 実行                       │
│  - 画面内容取得                          │
│  - ハッシュ比較で変更検知                 │
│  - プロンプト文字列の検索                 │
└──────────────┬──────────────────────────┘
               ▼
       プロンプト検知?
          │
    Yes ──┴── No
     │        │
     ▼        ▼
 TapEnter()  何もしない
 (Enter送信)
```

#### デーモンモード

```go
// デーモン起動時、全インスタンスでAutoYes有効化
for _, instance := range instances {
    instance.AutoYes = true
}
```

### 状態管理

```go
type Status int

const (
    Running  // Claude実行中
    Ready    // ユーザー入力待ち
    Loading  // 起動中
    Paused   // 一時停止（ブランチ保持、worktree削除）
)
```

---

## devcrew との比較

### コンセプトの違い

| 観点 | Claude Squad | devcrew |
|------|-------------|---------|
| 目的 | 複数タスクの並列処理 | 1つのタスクをチームで協力 |
| エージェント関係 | 独立・並列 | 分業・協調 |
| フォーカス | スループット向上 | 品質向上 |

### 機能比較

| 機能 | Claude Squad | devcrew |
|------|-------------|---------|
| UI | Go製TUI (bubbletea) | tmux直接 |
| 承認制御 | 全承認 or 手動のみ | restricted/yolo + コマンド制限 |
| 許可コマンド | なし（全部かゼロ） | `dc-send`, `dc-status` のみ許可可能 |
| 検知方式 | 画面キャプチャ + 文字列マッチ | Claude Codeの `--allowedTools` |
| git分離 | git worktree | なし（共有） |

### devcrew の優位点

1. **細かい権限制御**: 特定コマンドのみ許可できる（セキュリティ）
2. **チーム協調モデル**: Leader/Coder/Reviewer/Testerの役割分担
3. **Claude Codeの `--allowedTools`** を活用

### Claude Squad の優位点

1. **TUIによる操作性**: ペイン切り替えが直感的
2. **git worktree分離**: コンフリクト回避
3. **デーモンモード**: バックグラウンド実行

---

## 参考にできる実装

### 1. プロンプト検知（画面キャプチャ方式）

```bash
# Claude Squadの方式
tmux capture-pane -p -e -J -t <session>
```

- 汎用的でエージェント種類を問わない
- ポーリングベースでシンプル

### 2. 状態遷移管理

Running → Ready → Paused の明確な状態定義

### 3. TUI実装（bubbletea）

- Go製でシングルバイナリ
- tmuxを内部で使いつつ、操作性を向上

---

## 今後の検討事項

### 短期（tmux改善）

- fzf/gum でペイン選択をインタラクティブに
- カスタムキーバインドで `dc-send` 呼び出し

### 中期（TUI化）

- bubbletea で軽量TUIアプリ化
- Claude Squadのコードを参考に

### 長期（SDK移行）

- Claude Agent SDK でオーケストレーション
- より複雑なワークフロー対応

---

## 参考リンク

- [Claude Squad - GitHub](https://github.com/smtg-ai/claude-squad)
- [Claude Squad - Docs](https://smtg-ai.github.io/claude-squad/)
- [AgentPipe - GitHub](https://github.com/kevinelliott/agentpipe)
- [Parallel Coding Agents - Simon Willison](https://simonwillison.net/2025/Oct/5/parallel-coding-agents/)
- [Conductors to Orchestrators - Addy Osmani](https://addyo.substack.com/p/conductors-to-orchestrators-the-future)
- [Tembo - Run Claude Code in Parallel](https://www.tembo.io/blog/how-to-run-claude-code-in-parallel)

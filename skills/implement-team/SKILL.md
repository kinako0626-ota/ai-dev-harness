---
name: implement-team
description: "複数タスクまたは自由指示を受けてチーム並列実装を行う。呼び出し例: /implement-team TASK-015 TASK-016 TASK-017、/implement-team 機能Xを実装して。複数タスクを並列で効率的に実装したいとき、自由指示から計画→分割→並列TDD実装→レビュー→ステータス更新を自動実行したいときに使用する。"
user-invocable: true
---

# チーム並列実装スキル

`$ARGUMENTS` から以下のいずれかを受け取る:
- **タスク ID 指定**: `TASK-015 TASK-016 TASK-017`（スペース区切り）
- **自由指示**: 自由形式のテキスト

未指定の場合は `AskUserQuestion` で確認する。

## Phase 0: プランモード（必須）

1. `EnterPlanMode` でプランモードに入る
2. 入力を解析（`TASK-[0-9]+` パターン → タスク ID、それ以外 → 自由指示）
3. **タスク ID の場合**: `docs/plan/tasks.json` から詳細を取得、依存関係を確認
4. **自由指示の場合**: Explore エージェント（`subagent_type: Explore`）でコードベースを探索
5. [convention-mapping.md](../implement/references/convention-mapping.md) に従い規約を読み込む
6. サブタスクに分割（各サブタスクに担当エージェント名、変更ファイル、規約、テスト計画を定義）
7. **不明点・曖昧な仕様がある場合は `AskUserQuestion` で確認する**（推測で進めない）
8. Sprint Contract を作成する（後述）
9. `ExitPlanMode` で計画 + Sprint Contract を提示し承認を得る

### Sprint Contract（実装前の成功基準合意）

計画の末尾に以下を追加:

```
### Sprint Contract

**完了条件**:
1. [ ] プロジェクトの静的解析コマンドを実行（CLAUDE.md 参照）: エラー 0件
2. [ ] テスト: 新規テスト X件以上、全テスト PASS
3. [ ] 変更ファイルが計画範囲内（±2ファイル以内）
4. [ ] レビュースコア: 全項目 A or B

**サブタスク別スコープ**:
| サブタスク | 担当 | 変更ファイル | テスト数 |
|-----------|------|-------------|---------|
| ST-1: ... | implementer-1 | ... | X件 |
| ST-2: ... | implementer-2 | ... | X件 |

**スコープ外**: ...
**リスク・前提**: ...
```

## Phase 1: チーム組成と並列実装

### 1. チーム作成
`TeamCreate` で `implement-team` チームを作成する。

### 2. 実装エージェントのスポーン
サブタスク数に応じて `Agent` で並列スポーンする（依存関係があるものは順次実行）。

各エージェントのプロンプトに含める内容:
- 担当サブタスクの内容と変更対象ファイル
- 適用規約（読み込んだ規約をそのまま渡す）
- TDD 必須（Red → Green → Refactor）
- [convention-mapping.md](../implement/references/convention-mapping.md) の i18n 対応・コード生成ルール
- 担当外ファイルの変更禁止
- 想定外の問題は報告すること

### 3. 進捗監視
- 各エージェントの完了を待つ
- 問題報告があれば `AskUserQuestion` でユーザーに確認する

### Context 管理戦略

- **リーダーは実装詳細を保持しない**: エージェントからの報告は「成功/失敗 + 変更ファイル一覧」のみ受け取る
- **サブタスク数が 5 以上の場合**: 2-3 タスクずつバッチで実行し、各バッチ完了後に `プロジェクトの静的解析コマンドを実行（CLAUDE.md 参照）` で中間チェック
- **エージェントの報告フォーマット（簡潔化）**:
  ```
  ## 実装結果
  **状態**: 成功 / 失敗（理由: ...）
  **変更ファイル**: [一覧]
  **テスト**: X件追加、全PASS / 失敗Y件
  **注意事項**: （あれば）
  ```

## Phase 2: 統合・レビュー

### 1. analyze 実行（必須）
```bash
プロジェクトの静的解析コマンドを実行（CLAUDE.md 参照）
```

### 2. レビュー
[review-report.md](../implement/references/review-report.md) に従い、3つのレビューエージェントを並列起動。
変更ファイル一覧は `git diff --name-only HEAD`（差分なければ `git diff --name-only main...HEAD`）で取得。

### 3. ゲート判定

| スコア | 判定 | アクション |
|--------|------|------------|
| 全項目 A or B | **PASS** | Phase 3 に進む |
| いずれか C | **CONDITIONAL** | MUST 指摘を修正 → 再レビュー |
| いずれか D | **BLOCK** | 修正 → 再レビュー（最大 3 回） |

### 4. Sprint Contract 照合

## Phase 3: クリーンアップ

### 1. チームシャットダウン
`TeamDelete` でチームを解散する。

### 2. ステータス更新（タスク ID 指定の場合のみ）
- `docs/plan/tasks.json`: 該当タスクの `status` → `"completed"`, `completed_at` → 今日の日付
- `docs/plan/progress.json`: `overall` と該当フェーズの `completed` / `completion_percentage` を再計算

### 3. 最終サマリー
```
## 実装完了
**実装内容**: {タスク一覧 or 自由指示の要約}
**チーム構成**: implementer-1〜N + reviewer x3
**変更ファイル**: X件
**テスト**: X件追加
**レビュー結果**: 規約 A / 品質 A / テスト A
**ステータス**: {completed に更新済み / N/A}
```

## 注意事項

- サブタスク分割時にファイル担当を明確に分け、競合を防ぐ
- 共有ファイルは1エージェントに集約するか、リーダーが最後に統合する
- 日本語で出力すること

$ARGUMENTS

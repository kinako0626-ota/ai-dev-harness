---
name: implement
description: "docs/plan/tasks.json の単一タスクを TDD で実装し、自動レビュー・ステータス更新まで一貫して行う。呼び出し例: /implement TASK-015。タスクIDを指定して単一タスクを実装したいとき、計画→TDD実装→レビュー→完了更新の一連フローを自動実行したいときに使用する。"
user-invocable: true
---

# 単体タスク実装スキル

`$ARGUMENTS` からタスク ID を受け取る（例: `TASK-015`）。
未指定の場合は `AskUserQuestion` で確認する。

## Phase 0: プランモード（必須）

1. `EnterPlanMode` でプランモードに入る
2. `docs/plan/tasks.json` から指定タスク ID の詳細を取得する
3. 依存タスクが未完了の場合はユーザーに警告する
4. [convention-mapping.md](references/convention-mapping.md) に従い、変更対象パスに応じた規約を読み込む
5. Explore エージェント（`subagent_type: Explore`）でコードベースを探索し、関連する既存コードを把握する
6. 実装計画を立案する（変更ファイル一覧、テスト計画、実装手順）
7. **不明点・曖昧な仕様がある場合は `AskUserQuestion` で確認する**（推測で進めない）
8. Sprint Contract を作成する（後述）
9. `ExitPlanMode` で計画 + Sprint Contract を提示し承認を得る

### Sprint Contract（実装前の成功基準合意）

計画の末尾に以下を追加してユーザーに提示する:

```
### Sprint Contract

**完了条件**:
1. [ ] プロジェクトの静的解析コマンドを実行（CLAUDE.md 参照）: エラー 0件
2. [ ] テスト: 新規テスト X件以上、全テスト PASS
3. [ ] 変更ファイルが計画範囲内（±2ファイル以内）
4. [ ] レビュースコア: 全項目 A or B

**スコープ外（明示的に行わないこと）**:
- {Phase 0 の探索で判明した、やりたくなるが今回は範囲外のこと}

**リスク・前提**:
- {依存ライブラリのバージョン、未解決の設計判断など}
```

## Phase 1: 実装

承認された計画に従い TDD で実装する。

### TDD サイクル（Service / Repository / UseCase は必須）
1. **Red**: テストを先に書く
2. **Green**: テストが通る最小限の実装
3. **Refactor**: コード整理

### 実装中のルール
- [convention-mapping.md](references/convention-mapping.md) の i18n 対応・コード生成ルールに従う
- 想定外の問題・設計変更が必要な場合は `AskUserQuestion` で確認する

### analyze 実行（必須）
```bash
プロジェクトの静的解析コマンドを実行（CLAUDE.md 参照）
```
エラーがある場合は修正してから次の Phase に進む。

## Phase 2: 自動レビュー

[review-report.md](references/review-report.md) に従い、3つのレビューエージェントを並列起動してレポートを出力する。

レポートにはタスク情報（`**タスク**: {タスクID} - {タスク名}`）を先頭に追加する。

### ゲート判定

| スコア | 判定 | アクション |
|--------|------|------------|
| 全項目 A or B | **PASS** | Phase 3 に進む |
| いずれか C | **CONDITIONAL** | MUST 指摘を修正 → 再レビュー → 再判定 |
| いずれか D | **BLOCK** | 修正 → 再レビュー → C 以上になるまでループ（最大 3 回）。3 回で未解消の場合 `AskUserQuestion` でユーザー判断 |

### Sprint Contract 照合

レビュー完了後、Sprint Contract の各完了条件を照合する。未達成項目がある場合はユーザーに報告する。

### レビュー結果のファイル永続化

[review-report.md](references/review-report.md) の「レビュー結果のファイル永続化」に従い、レポートを `docs/reviews/` に保存する。

## Phase 3: ステータス更新

1. `docs/plan/tasks.json`: 該当タスクの `status` → `"completed"`, `completed_at` → 今日の日付
2. `docs/plan/progress.json`: `overall` と該当フェーズの `completed` / `completion_percentage` を再計算
3. 最終サマリーを出力:
```
## 実装完了
**タスク**: {タスクID} - {タスク名}
**変更ファイル**: X件（新規: a件、変更: b件）
**テスト**: X件追加
**レビュー結果**: 規約 A / 品質 A / テスト A
**ステータス**: completed に更新済み
```

## 注意事項

- サブエージェントは Phase 2 のレビュー時のみ使用し、実装は Skill 自体が直接行う
- 規約に明記されていない判断が必要な場合は `AskUserQuestion` で確認する
- 日本語で出力すること

$ARGUMENTS

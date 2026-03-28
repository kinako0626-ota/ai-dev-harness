---
name: setup
description: "ai-dev-harness プラグインのプロジェクト初期設定を行う。CLAUDE.md の生成、docs/plan/ ディレクトリの作成、規約マッピングの設定をガイドする。新しいプロジェクトで ai-dev-harness を使い始めるときに実行する。"
user-invocable: true
---

# プロジェクト初期設定

ai-dev-harness プラグインをこのプロジェクトで使うための初期設定を行う。

## Step 1: プロジェクト情報の収集

`AskUserQuestion` で以下の情報を収集する:

1. **プロジェクト名** — リポジトリ名やプロダクト名
2. **主要言語・フレームワーク** — dart/flutter, typescript/nextjs, python/fastapi 等
3. **静的解析コマンド** — 例: `npx eslint . && npx tsc --noEmit`, `fvm flutter analyze`
4. **テストコマンド** — 例: `npx jest`, `fvm flutter test`, `pytest`
5. **アーキテクチャスタイル** — clean / layered / hexagonal / none
6. **レイヤー構成** — presentation, domain, data, core 各層のディレクトリパス
7. **タスクIDプレフィックス** — デフォルト: `TASK`（例: `ARC`, `BUG`）

## Step 2: CLAUDE.md の生成

収集した情報をもとに、プロジェクトルートに `CLAUDE.md` を生成する。

### CLAUDE.md テンプレート

```markdown
# {プロジェクト名}

## セッション開始時

必ず `/ai-dev-harness:plan-status` を実行して現在の状況を把握すること。

## プロジェクト構成

- **言語/フレームワーク**: {言語} / {フレームワーク}
- **アーキテクチャ**: {アーキテクチャスタイル}

### レイヤー構成

| レイヤー | パス |
|---------|------|
| Presentation | {presentation_path} |
| Domain | {domain_path} |
| Data | {data_path} |
| Core | {core_path} |

## コマンド

- **静的解析**: `{analyze_command}`
- **テスト**: `{test_command}`

## タスク管理

- **タスクIDプレフィックス**: {task_prefix}
- **タスクファイル**: `docs/plan/tasks.json`
- **進捗ファイル**: `docs/plan/progress.json`
- **メインブランチ**: `main`

## 自動生成ファイル（レビュー除外対象）

{generated_patterns をリスト形式で}

## 規約マッピング

| 変更対象パス | 参照する規約 |
|---|---|
| {path} | {convention_files} |

## レビュー設定

- **モックライブラリ**: {mock_library}
- **テスト命名規則**: {naming_pattern}
- **TDD 必須対象**: Service / Repository / UseCase

## 出力言語

日本語で出力すること
```

## Step 3: ディレクトリ構造の作成

以下のディレクトリとファイルを作成する:

```bash
mkdir -p docs/plan docs/reviews docs/conventions .claude/rules
touch docs/reviews/.gitkeep
```

### docs/plan/tasks.json（初期状態）

```json
{
  "metadata": {
    "project": "{プロジェクト名}",
    "prefix": "{task_prefix}",
    "created": "{今日の日付}"
  },
  "phases": [],
  "tasks": []
}
```

### docs/plan/progress.json（初期状態）

```json
{
  "last_updated": "{今日の日付}",
  "overall": {
    "total_tasks": 0,
    "completed": 0,
    "completion_percentage": 0
  },
  "phases": []
}
```

## Step 4: 完了メッセージ

設定完了後、以下を表示する:

```
セットアップが完了しました。

利用可能なスキル:
  /ai-dev-harness:implement TASK-001    — 単一タスク TDD 実装
  /ai-dev-harness:implement-team TASK-001 TASK-002  — チーム並列実装
  /ai-dev-harness:code-review           — 3軸コードレビュー
  /ai-dev-harness:review-fix            — 自動修正ループ
  /ai-dev-harness:full-review           — 包括5フェーズレビュー
  /ai-dev-harness:plan-status           — 進捗レポート
  /ai-dev-harness:architecture-check    — アーキテクチャ準拠チェック

次のステップ:
  1. docs/conventions/ に規約ファイルを追加
  2. .claude/rules/ にプロジェクトルールを追加
  3. /ai-dev-harness:plan-status で状況確認
```

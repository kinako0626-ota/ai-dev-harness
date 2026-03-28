---
name: architecture-check
description: コードベースをアーキテクチャターゲットと照合し、乖離を検出・レポートしてタスクを自動生成します。
user-invocable: true
context: fork
agent: architecture-analyzer
allowed-tools: Read, Grep, Glob, Bash
---

# アーキテクチャ準拠チェック

コードベースを `docs/plan/architecture.md` のターゲットアーキテクチャと照合し、乖離分析を行ってください。

## 実行手順

### 1. ドキュメント読み取り

- `docs/plan/architecture.md` — ターゲットアーキテクチャ定義
- `docs/plan/tasks.json` — 既存タスク（最大 TASK-XXX ID を特定）
- `docs/plan/progress.json` — 現在の進捗状況

### 2. コードベーススキャン

ディレクトリ構造をスキャンし、ターゲットとの差分を検出。

### 3. 乖離分析（4カテゴリ）

1. **ディレクトリ構造**: ターゲット vs 現状
2. **レイヤー依存違反**: import 解析
3. **パターン不一致**: 使用状況チェック
4. **テスト不足**: テストカバレッジ

### 4. タスク生成

乖離に基づき TASK-XXX 形式のタスクを生成:
- 1タスク1000行以内
- 依存関係を明示
- 優先度を P1（データ層）> P2（プレゼンテーション層）> P3（クリーンアップ）で設定

### 5. レポート出力 + ファイル更新

- `docs/plan/tasks.json` に新規タスクを追加（**completed タスクは絶対に変更しない**）
- `docs/plan/progress.json` を再計算

## 注意事項

- コードの変更は行わない（分析とレポートのみ + JSON 更新）
- Bash は読み取り専用コマンドのみ使用
- 日本語で出力すること

$ARGUMENTS

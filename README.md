# ai-dev-harness

**Claude Code 用の開発ハーネス -- AI エージェントの品質を構造で担保する**

---

## ハーネスとは何か

Anthropic のブログ記事 ["Claude Code: Best practices for agentic coding"](https://www.anthropic.com/engineering/claude-code-best-practices) では、AI コーディングエージェントの出力品質は「プロンプトの巧みさ」ではなく「ハーネスの設計」で決まると述べられています。

**ハーネス (harness)** とは、AI エージェントを取り囲む仕組みの総称です:

- 実装前に何を読むべきか（ルール・規約ファイル）
- 実装後に何をチェックするか（静的解析・テスト）
- レビューをどう分離するか（独立した複数レビュアー）
- 品質ゲートをどう設定するか（A/B/C/D 評価）
- 問題をどう修正ループで解消するか（review-fix サイクル）

ai-dev-harness は、これらのパターンを **設定ファイル 1 つ** (`harness.yaml`) から自動生成します。Flutter、Next.js、Python FastAPI など、どのスタックでもプロジェクト規約に沿った AI 開発環境を数分で構築できます。

> このハーネスは実際の Flutter プロジェクトの開発で培われたプラクティスを汎用化したものです。

---

## Quick Start

### 1. クローン

```bash
git clone https://github.com/ootaryuunosuke/ai-dev-harness.git ~/ai-dev-harness
```

### 2. 設定ファイルを作成

```bash
cd your-project
cp ~/ai-dev-harness/harness.yaml.example harness.yaml
vim harness.yaml   # プロジェクトに合わせて編集
```

`harness.yaml` をプロジェクトに合わせて編集します。`examples/` ディレクトリにスタック別の設定例があります:

| スタック | 設定例 | 特徴 |
|---------|-------|------|
| Flutter | [`examples/flutter/harness.yaml`](examples/flutter/harness.yaml) | Dart + Firebase + Riverpod + fvm |
| Next.js | [`examples/nextjs/harness.yaml`](examples/nextjs/harness.yaml) | TypeScript + React + Prisma + NextAuth |
| Python FastAPI | [`examples/python-fastapi/harness.yaml`](examples/python-fastapi/harness.yaml) | Python + SQLAlchemy + Alembic + pytest |

### 3. 初期化

```bash
~/ai-dev-harness/init.sh
```

以下のファイルが自動生成されます:

```
your-project/
  CLAUDE.md                                    # Claude Code への指示書
  .claude/
    settings.json                              # フック・環境変数設定
    skills/                                    # 7 つのスキル定義
      implement/SKILL.md                       #   単一タスク TDD 実装
      implement-team/SKILL.md                  #   チーム並列実装
      code-review/SKILL.md                     #   3 軸コードレビュー
      review-fix/SKILL.md                      #   自動修正ループ
      full-review/SKILL.md                     #   包括 5 フェーズレビュー
      plan-status/SKILL.md                     #   進捗レポート
      architecture-check/SKILL.md              #   アーキテクチャ準拠チェック
    agents/                                    # 専門エージェント定義
      convention-reviewer.md                   #   規約準拠レビュアー
      quality-reviewer.md                      #   品質レビュアー
      test-coverage-reviewer.md                #   テストカバレッジレビュアー
      architecture-analyzer.md                 #   アーキテクチャ分析
      plan-reader.md                           #   計画読み取り
  docs/
    plan/
      tasks.json                               # タスク管理
      progress.json                            # 進捗トラッキング
    reviews/                                   # レビュー結果の出力先
```

---

## スキル一覧

ai-dev-harness は Claude Code のスキル（スラッシュコマンド）として動作します。

| スキル | 説明 | 使い方 |
|--------|------|--------|
| `/implement` | 単一タスクを TDD で実装。計画 -> テスト -> 実装 -> 解析 -> ステータス更新まで一貫実行 | `/implement ARC-015` |
| `/implement-team` | 複数タスクをチーム並列実装。各タスクを独立エージェントに委譲して並列処理 | `/implement-team ARC-015 ARC-016 ARC-017` |
| `/code-review` | 3 人の独立レビュアーが規約・品質・テストを並列チェック。A/B/C/D 評価付きレポート生成 | `/code-review` |
| `/review-fix` | レビュー -> 修正 -> 再レビューを指摘ゼロになるまで自動ループ。MUST のみモードあり | `/review-fix` または `/review-fix must` |
| `/full-review` | 出荷前の包括レビュー。コード品質 -> UI 監査 -> UX 評価 -> セキュリティ -> 最終チェックの 5 フェーズ | `/full-review` |
| `/plan-status` | プロジェクトの計画・進捗状況を `tasks.json` / `progress.json` から分析して報告 | `/plan-status` |
| `/architecture-check` | コードベースを Clean Architecture ターゲットと照合し、乖離を検出・タスク自動生成 | `/architecture-check` |

---

## ワークフロー

典型的な開発フローは以下の通りです:

```
/plan-status                        セッション開始時に状況確認
    |
    v
/implement TASK-001                 タスク実装 (TDD)
    |
    |-- Phase 0: Sprint Contract    事前計画・スコープ合意
    |-- Phase 1: TDD                Red -> Green -> Refactor
    |-- Phase 2: Auto Review        3 軸自動レビュー
    |-- Phase 3: Status Update      タスク完了更新
    |
    v
/code-review                        追加レビュー（任意）
    |
    +-- Grade A/B --> Done
    |
    +-- Grade C/D --> /review-fix   自動修正ループ
                          |
                          +-- 修正 -> 再レビュー -> 修正 ...
                          |
                          +-- Grade A/B --> Done

出荷前:
/full-review                        包括レビュー（5 フェーズ）
    |
    +-- Grade A/B --> Ship!
    |
    +-- Grade C/D --> /review-fix
```

### 複数タスクの並列実装

```
/implement-team ARC-015 ARC-016 ARC-017
    |
    |-- Agent A: ARC-015 (独立コンテキスト)
    |-- Agent B: ARC-016 (独立コンテキスト)
    |-- Agent C: ARC-017 (独立コンテキスト)
    |
    v
    全タスク完了 -> /code-review
```

### コミット時の自動ゲート

```
git commit -m "feat: ..."
    |
    +-- PreToolUse Hook 発火
    +-- {{ANALYZE_CMD}} 自動実行
    +-- 失敗 --> コミット中止
    +-- 成功 --> コミット実行
```

---

## 設定リファレンス

`harness.yaml` の主要セクションを説明します。全フィールドの詳細は [`harness.yaml.example`](harness.yaml.example) を参照してください。

### project -- プロジェクト識別

```yaml
project:
  name: "my-project"    # ファイルパス・チーム名に使用
  language: "ja"         # 出力言語: "ja" | "en"
```

### stack -- 言語とフレームワーク

```yaml
stack:
  primary_language: "dart"      # dart | typescript | python | go | rust
  framework: "flutter"          # flutter | nextjs | fastapi | express | django
```

テンプレート選択とリントルール生成に使用されます。

### commands -- コマンド定義

```yaml
commands:
  analyze: "fvm flutter analyze"    # 静的解析（必須・pre-commit フック）
  test: "fvm flutter test"          # テスト実行（必須・TDD サイクル）
  build_generated: "..."            # コード生成（任意）
  format: "dart format ."           # フォーマット（任意）
```

`analyze` は pre-commit フックで自動実行されるため、コミット前に必ず静的解析が通ります。

### architecture -- アーキテクチャ層定義

```yaml
architecture:
  style: "clean"                    # clean | layered | hexagonal | none
  layers:
    presentation: "lib/presentation"
    domain: "lib/domain"
    data: "lib/data"
    core: "lib/core"
  additional_sources:               # モノレポ対応
    - path: "functions"
      language: "typescript"
      analyze: "cd functions && npm run lint"
```

`/architecture-check` がレイヤー間の依存方向を検証する際に参照します。

### conventions -- 規約マッピング

```yaml
conventions:
  mapping:
    - paths: ["lib/presentation/**"]
      files: [".claude/rules/color-usage.md", "docs/conventions/flutter-ui.md"]
    - paths: ["lib/data/repositories/**"]
      files: [".claude/rules/repository-design.md"]
  global:
    - "docs/conventions/architecture.md"
```

パス別にどの規約ファイルを読むかを定義します。スキルは実装・レビュー前に該当する規約を自動的に参照します。

### review -- レビュー設定

```yaml
review:
  design_system:
    class_name: "AppColors"         # デザイントークンクラス（空文字でチェック無効）
    file: "lib/core/theme/color.dart"
  error_handling:
    result_type: "Result"           # Result | Either | 空（チェック無効）
    exception_class: "AppException"
  testing:
    mock_library: "mocktail"        # mocktail | jest.mock | pytest-mock
    naming_language: "ja"
    naming_pattern: "〇〇の場合は〇〇であること"
    tdd_required_for:
      - "Service"
      - "Repository"
      - "UseCase"
```

### modules -- スキルの有効/無効

```yaml
modules:
  implement: true          # /implement
  implement_team: true     # /implement-team
  code_review: true        # /code-review
  review_fix: true         # /review-fix
  full_review: true        # /full-review
  plan_status: true        # /plan-status
  architecture_check: true # /architecture-check
  design_skills: true      # デザイン強化スキル
```

不要なスキルは `false` に設定して無効化できます。

### models -- エージェントモデル

```yaml
models:
  reviewer: "sonnet"       # レビューエージェント用
  analyzer: "sonnet"       # アーキテクチャ分析用
  planner: "haiku"         # 計画読み取り用（軽量）
```

### git -- Git 設定

```yaml
git:
  main_branch: "develop"   # PR のデフォルトターゲットブランチ
```

---

## アーキテクチャ

ai-dev-harness の内部構造と各コンポーネントの関係:

```
harness.yaml (設定)
     |
     | init.sh (生成)
     v
+----+-----------------------------------------------------+
|                    Generated Files                        |
|                                                          |
|  CLAUDE.md              .claude/settings.json            |
|  (指示書)                (フック・環境変数)                 |
+---+-------------------+---------------------------------+
    |                   |
    v                   v
+---+--------+  +-------+--------+
|  Skills    |  |  Pre-commit    |
|  (7 種)    |  |  Hook          |
+---+--------+  |  analyze 自動  |
    |           +-------+--------+
    |                   |
    v                   v
+---+-------------------+---------------------------------+
|                 Claude Code Agent                        |
|                                                          |
|  +------------+  +------------------+  +------------+    |
|  | Implement  |  | Review Agents    |  | Fix Agent  |    |
|  | Agent      |  | (3 独立)         |  |            |    |
|  +-----+------+  | - Convention     |  +-----+------+    |
|        |         | - Quality        |        |            |
|        |         | - Test Coverage  |        |            |
|        |         +--------+---------+        |            |
+--------+------------------+------------------+------------+
         |                  |                  |
         v                  v                  v
+--------+------------------+------------------+------------+
|                  Reference Files                          |
|                                                          |
|  .claude/rules/*         docs/conventions/*              |
|  (プロジェクト規約)       (コーディング規約)                |
|                                                          |
|  docs/plan/*             docs/reviews/*                  |
|  (タスク・進捗)           (レビュー結果)                    |
+----------------------------------------------------------+
```

### 設計パターン（Anthropic 記事ベース）

| パターン | ハーネスでの実装 |
|---------|----------------|
| **Generator-Evaluator 分離** | 実装エージェントとレビューエージェントを分離。3 つの独立レビュアーが並列監査 |
| **Sprint Contract** | `/implement` Phase 0 で完了条件・スコープ外を事前合意してから TDD 開始 |
| **File-based Communication** | レビュー結果を `docs/reviews/` に永続化。セッション跨ぎでも参照可能 |
| **Context Reset Points** | Team 委譲で各エージェントのコンテキストを独立化。蓄積による劣化を防止 |
| **Hard Threshold Gate** | A/B/C/D スコアで合否判定。C/D はマージブロック |
| **Iterative Refinement** | `/review-fix` で最大 5 ラウンドの自動修正ループ |
| **Adversarial Self-Check** | レビュアーが「問題を見つける」指向で監査 + キャリブレーション例参照 |

詳細は [docs/harness-design.md](docs/harness-design.md) を参照してください。

---

## 設定例

### Flutter

Firebase バックエンド + Clean Architecture の Flutter アプリ:

```yaml
stack:
  primary_language: "dart"
  framework: "flutter"

commands:
  analyze: "fvm flutter analyze"
  test: "fvm flutter test"
  build_generated: "fvm flutter pub run build_runner build --delete-conflicting-outputs"

architecture:
  style: "clean"
  additional_sources:
    - path: "functions"
      language: "typescript"

review:
  design_system:
    class_name: "AppColors"
  testing:
    mock_library: "mocktail"
    naming_language: "ja"
    tdd_required_for: ["Service", "Repository", "Notifier", "UseCase"]
```

完全な設定: [`examples/flutter/harness.yaml`](examples/flutter/harness.yaml)

### Next.js SaaS

App Router + Prisma + NextAuth の SaaS ダッシュボード:

```yaml
stack:
  primary_language: "typescript"
  framework: "nextjs"

commands:
  analyze: "npx eslint . && npx tsc --noEmit"
  build_generated: "npx prisma generate"

architecture:
  style: "layered"

review:
  design_system:
    class_name: "AppColors"
  testing:
    mock_library: "jest.mock"
    naming_pattern: "should do X when Y"
```

完全な設定: [`examples/nextjs/harness.yaml`](examples/nextjs/harness.yaml)

### Python FastAPI

SQLAlchemy + Alembic のバックエンド API:

```yaml
stack:
  primary_language: "python"
  framework: "fastapi"

commands:
  analyze: "ruff check . && mypy ."
  test: "pytest -v --tb=short"

architecture:
  style: "clean"

review:
  error_handling:
    result_type: "Result"
  testing:
    mock_library: "pytest-mock"
```

完全な設定: [`examples/python-fastapi/harness.yaml`](examples/python-fastapi/harness.yaml)

---

## カスタマイズ

### 規約ファイルの追加

1. `.claude/rules/` または `docs/conventions/` にマークダウンファイルを作成
2. `harness.yaml` の `conventions.mapping` にパスとファイルを登録
3. `./init.sh` で再生成

```yaml
conventions:
  mapping:
    - paths: ["src/app/api/**"]
      files: [".claude/rules/api-design.md"]
```

### レビューチェック項目の変更

規約ファイルにルールを追加すると、レビュアーが自動的にチェック対象に含めます:

```markdown
<!-- .claude/rules/api-design.md -->
# API Design Rules
- Use kebab-case for URL paths
- Always return { data, error, meta } envelope
```

### 新しいスキルの追加

1. `.claude/skills/my-skill/SKILL.md` を作成
2. `SKILL.md` 内でワークフロー手順を定義

### 出力言語の変更

```yaml
project:
  language: "en"    # "ja" -> "en" に変更
```

`init.sh` を再実行すると、英語テンプレートから生成されます。

詳細は [docs/customization-guide.md](docs/customization-guide.md) を参照してください。

---

## コマンドオプション

```bash
# プレビュー（ファイル書き込みなし）
~/ai-dev-harness/init.sh --dry-run

# 既存ファイルを確認なしで上書き
~/ai-dev-harness/init.sh --force

# 言語を指定して生成
~/ai-dev-harness/init.sh --lang en

# 設定バリデーションのみ
~/ai-dev-harness/scripts/validate-config.sh

# テンプレート更新
~/ai-dev-harness/scripts/update.sh ~/ai-dev-harness
```

---

## 更新方法

テンプレートの新バージョンがリリースされた場合:

```bash
cd ~/ai-dev-harness
git pull origin main

cd your-project
~/ai-dev-harness/init.sh    # 設定ファイルを再生成
```

`harness.yaml` はあなたの設定ファイルなので上書きされません。テンプレートのみが更新されます。

詳細は [docs/updating.md](docs/updating.md) を参照してください。

---

## ドキュメント

| ドキュメント | 内容 |
|------------|------|
| [`harness.yaml.example`](harness.yaml.example) | 全フィールド解説付き設定テンプレート |
| [`docs/harness-design.md`](docs/harness-design.md) | ハーネス設計パターンの解説（Anthropic 記事ベース） |
| [`docs/customization-guide.md`](docs/customization-guide.md) | 規約追加・レビューカスタマイズ・CI 連携ガイド |
| [`docs/updating.md`](docs/updating.md) | テンプレート更新手順 |

---

## Credits

- **設計思想**: Anthropic ["Claude Code: Best practices for agentic coding"](https://www.anthropic.com/engineering/claude-code-best-practices)
- **実証**: Flutter プロジェクトの実開発で培われたプラクティスを汎用化
- **動作環境**: [Claude Code](https://claude.ai/claude-code) (Anthropic)

---

## License

MIT License. See [LICENSE](LICENSE) for details.

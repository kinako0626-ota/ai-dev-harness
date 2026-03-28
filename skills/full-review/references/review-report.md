# レビューレポート仕様

## レビューエージェントの起動

3つのレビューエージェントを `Agent` ツールで**並列**起動する:

- **convention-reviewer** (`subagent_type: convention-reviewer`): 規約準拠チェック
- **quality-reviewer** (`subagent_type: quality-reviewer`): コード品質チェック
- **test-coverage-reviewer** (`subagent_type: test-coverage-reviewer`): テストカバレッジチェック

各エージェントには変更ファイル一覧をプロンプトで渡す。
自動生成ファイル（CLAUDE.md 参照） は自動生成なので除外する。

## 統合レポートフォーマット

```
## レビュー結果サマリー

**対象ファイル**: X件
**指摘総数**: Y件 (MUST: a件 / SHOULD: b件 / NICE: c件)

---

### 規約違反 (X件)
| # | ファイル:行 | カテゴリ | 内容 | 重要度 |
|---|------------|---------|------|--------|

### コード品質 (X件)
| # | ファイル:行 | 種別 | 内容 | 重要度 |
|---|------------|------|------|--------|

### テストカバレッジ / TDD (X件)
| # | 対象ファイル | 内容 | 重要度 |
|---|------------|------|--------|

---

### 総評
- 規約準拠度: A/B/C/D
- コード品質: A/B/C/D
- テストカバレッジ: A/B/C/D
```

## スコア基準

- **A**: MUST 0件、SHOULD 2件以下
- **B**: MUST 0件、SHOULD 3件以上
- **C**: MUST 1-2件
- **D**: MUST 3件以上

## ゲート判定基準

- **PASS**: 全項目 A or B
- **CONDITIONAL**: いずれか C → MUST 修正後に再判定
- **BLOCK**: いずれか D → 自動ブロック。修正ループ必須

## 重要度の定義

- **MUST**: 必ず修正が必要（規約違反、バグリスク、テスト欠落）
- **SHOULD**: 修正を強く推奨（品質向上、TDD 非準拠）
- **NICE**: 修正するとより良い（軽微な改善）

## レビュー結果のファイル永続化

レポート出力後、以下のパスに Markdown ファイルとして保存する:

```
docs/reviews/{YYYY-MM-DD}_{BRANCH_NAME}_{SKILL_NAME}.md
```

ファイル先頭に YAML frontmatter を付与:

```markdown
---
date: 現在の日付
branch: feature/TASK-050
skill: code-review
scores:
  convention: A
  quality: B
  test_coverage: A
gate: PASS
must_count: 0
should_count: 3
nice_count: 2
---
```

既存の同名ファイルがある場合は `_r2`, `_r3` のサフィックスを付ける。

# Customization Guide

This guide explains how to extend and customize ai-dev-harness for your project's specific needs.

## Table of Contents

- [Adding Custom Convention Files](#adding-custom-convention-files)
- [Adding Custom Reviewer Checks](#adding-custom-reviewer-checks)
- [Creating Additional Skills](#creating-additional-skills)
- [Changing Output Language](#changing-output-language)
- [Integrating with CI/CD](#integrating-with-cicd)

---

## Adding Custom Convention Files

Convention files are Markdown documents that describe coding rules for specific parts of your codebase. Skills read these files before implementing or reviewing code.

### Step 1: Create the convention file

Create a Markdown file in either `.claude/rules/` (for Claude-specific rules) or `docs/conventions/` (for general conventions).

```markdown
<!-- .claude/rules/api-design.md -->
# API Design Rules

## Endpoint Naming
- Use kebab-case for URL paths: `/user-profiles` not `/userProfiles`
- Use plural nouns for collections: `/users` not `/user`

## Response Format
- Always return `{ data, error, meta }` envelope
- Use HTTP status codes correctly (don't return 200 for errors)

## Validation
- Validate all inputs with Zod schemas
- Return 422 for validation failures with field-level errors
```

### Step 2: Register in harness.yaml

Add the file to the `conventions.mapping` section with appropriate path globs:

```yaml
conventions:
  mapping:
    - paths: ["src/app/api/**"]
      files: [".claude/rules/api-design.md"]
```

For rules that apply everywhere, use `global`:

```yaml
conventions:
  global:
    - "docs/conventions/error-handling.md"
```

### Step 3: Regenerate

Run `./init.sh` to regenerate the CLAUDE.md with the updated rules list.

### Tips

- Keep convention files focused: one topic per file
- Use code examples (both "do" and "don't") -- AI agents learn better from examples
- Include the *reason* behind each rule, not just the rule itself
- Reference the convention file path in code review comments so developers can look up the full context

---

## Adding Custom Reviewer Checks

The `/code-review` skill uses three independent reviewers. You can customize what each reviewer focuses on.

### Method 1: Convention-based checks

The simplest approach is adding rules to convention files. Reviewers automatically check code against all registered convention files.

For example, to enforce a specific import order:

```markdown
<!-- .claude/rules/import-order.md -->
# Import Order

Imports must follow this order, separated by blank lines:

1. Dart/Flutter SDK imports
2. Package imports (pub.dev)
3. Project imports (relative)

### Example
```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/theme/color.dart';
import '../widgets/loading_widget.dart';
```
```

### Method 2: Design system enforcement

If your project uses a design token system, configure it in `review.design_system`:

```yaml
review:
  design_system:
    class_name: "AppColors"
    file: "src/lib/theme/colors.ts"
```

Reviewers will flag any hardcoded colors, fonts, or spacing values that should come from the design system.

### Method 3: Testing rules

Configure testing conventions to enforce TDD and naming patterns:

```yaml
review:
  testing:
    mock_library: "jest.mock"
    naming_language: "en"
    naming_pattern: "should do X when Y"
    tdd_required_for:
      - "Service"
      - "Repository"
```

Reviewers will flag:
- Classes in `tdd_required_for` without corresponding test files
- Test names that don't match `naming_pattern`
- Use of a mock library other than `mock_library`

---

## Creating Additional Skills

Skills are Claude Code slash commands that provide specialized workflows. You can create custom skills to automate project-specific tasks.

### Skill structure

A skill is defined as a Markdown instruction file that Claude Code loads when the skill is invoked. Skills are registered via the Claude Code configuration.

### Example: Creating a `/migrate` skill

1. Create the skill instruction file:

```markdown
<!-- .claude/skills/migrate.md -->
# Database Migration Skill

When invoked with `/migrate <description>`, perform these steps:

1. Create a new Alembic migration:
   ```bash
   alembic revision --autogenerate -m "<description>"
   ```
2. Review the generated migration file for correctness
3. Run the migration against the dev database:
   ```bash
   alembic upgrade head
   ```
4. Generate updated SQLAlchemy models if needed
5. Run tests to verify the migration doesn't break existing functionality
```

2. Register the skill in your Claude Code configuration (this is done through the skill registration mechanism in Claude Code).

### Tips for skill design

- **Be explicit about steps.** List every step the skill should perform.
- **Include error handling.** Describe what to do when a step fails.
- **Reference convention files.** Tell the skill which rules to follow.
- **Keep skills focused.** One skill = one workflow. Don't combine unrelated tasks.

---

## Changing Output Language

ai-dev-harness supports generating configuration files in different languages.

### Setting the language

In `harness.yaml`:

```yaml
project:
  language: "ja"    # Japanese
  # language: "en"  # English
```

### What changes by language

| Component | `ja` | `en` |
|-----------|------|------|
| CLAUDE.md instructions | Japanese | English |
| Skill prompts | Japanese | English |
| Review report format | Japanese | English |
| Test naming | `〇〇の場合は〇〇であること` | `should do X when Y` |
| Task descriptions | User-defined | User-defined |

### Adding a new language

1. Create a new template directory: `templates/<lang>/`
2. Copy the template files from `templates/en/` or `templates/ja/`
3. Translate all template content
4. Update `init.sh` to recognize the new language code

Templates use the same `{{PLACEHOLDER}}` syntax regardless of language. Only the surrounding text changes.

---

## Integrating with CI/CD

ai-dev-harness is primarily designed for local development with Claude Code, but its outputs can be integrated into CI/CD pipelines.

### Pre-commit hooks

The harness configures a pre-commit hook that runs `{{ANALYZE_CMD}}` before every commit. This works automatically in local development.

For CI, add the same command to your pipeline:

```yaml
# GitHub Actions example
jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install dependencies
        run: npm ci
      - name: Lint & type check
        run: npx eslint . && npx tsc --noEmit
```

### Using review reports in CI

Review reports in `docs/reviews/` can be parsed by CI pipelines:

```yaml
# Check if the latest review passed
- name: Check review grade
  run: |
    LATEST=$(ls -t docs/reviews/code-review-*.md | head -1)
    if grep -q "Grade: [CD]" "$LATEST"; then
      echo "Review grade is C or D. Blocking merge."
      exit 1
    fi
```

### Task tracking in CI

You can add a CI step that validates task status:

```yaml
- name: Check task completion
  run: |
    # Verify all tasks for this PR are marked completed
    python scripts/check_tasks.py --pr=${{ github.event.number }}
```

### Architecture compliance in CI

Run architecture checks as part of your CI pipeline:

```yaml
- name: Architecture check
  run: |
    # Use the architecture doc to verify layer dependencies
    python scripts/check_architecture.py \
      --config=harness.yaml \
      --changed-files=$(git diff --name-only origin/main...HEAD)
```

### Full pipeline example

```yaml
name: Harness CI
on:
  pull_request:
    branches: [main, develop]

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup
        run: npm ci

      - name: Analyze
        run: npx eslint . && npx tsc --noEmit

      - name: Test
        run: npx jest --coverage

      - name: Check review status
        if: always()
        run: |
          if [ -f docs/reviews/code-review-latest.md ]; then
            echo "Review report found"
            cat docs/reviews/code-review-latest.md
          fi
```

### Tips

- CI should enforce the same gates as the harness (analyze, test, review grade)
- Don't duplicate effort: if the harness already ran a review locally, CI can verify the report exists rather than re-running
- Keep CI fast: use the harness for thorough local review, CI for gatekeeping

# ai-dev-harness

**A development harness for Claude Code -- ensuring AI agent quality through structure**

---

## What is a Harness?

Anthropic's blog post ["Claude Code: Best practices for agentic coding"](https://www.anthropic.com/engineering/claude-code-best-practices) argues that AI coding agent output quality is determined not by "prompt cleverness" but by "harness design."

A **harness** is the collective term for the scaffolding that surrounds an AI agent:

- What to read before implementation (rules and convention files)
- What to check after implementation (static analysis, tests)
- How to separate review from implementation (independent multiple reviewers)
- How to set quality gates (A/B/C/D grading)
- How to resolve problems through fix loops (review-fix cycles)

ai-dev-harness generates all of these patterns from **a single configuration file** (`harness.yaml`). Whether you use Flutter, Next.js, Python FastAPI, or any other stack, you can set up an AI development environment aligned with your project conventions in minutes.

> This harness was extracted and generalized from real-world practices developed during a production Flutter project.

---

## Quick Start

### 1. Clone

```bash
git clone https://github.com/kinako0626-ota/ai-dev-harness.git ~/ai-dev-harness
```

### 2. Create config file

```bash
cd your-project
cp ~/ai-dev-harness/harness.yaml.example harness.yaml
vim harness.yaml   # Edit to match your project
```

Edit `harness.yaml` to match your project. Stack-specific examples are available in the `examples/` directory:

| Stack | Example | Highlights |
|-------|---------|------------|
| Flutter | [`examples/flutter/harness.yaml`](examples/flutter/harness.yaml) | Dart + Firebase + Riverpod + fvm |
| Next.js | [`examples/nextjs/harness.yaml`](examples/nextjs/harness.yaml) | TypeScript + React + Prisma + NextAuth |
| Python FastAPI | [`examples/python-fastapi/harness.yaml`](examples/python-fastapi/harness.yaml) | Python + SQLAlchemy + Alembic + pytest |

### 3. Initialize

```bash
~/ai-dev-harness/init.sh
```

The following files are auto-generated:

```
your-project/
  CLAUDE.md                                    # Instructions for Claude Code
  .claude/
    settings.json                              # Hooks and environment variables
    skills/                                    # 7 skill definitions
      implement/SKILL.md                       #   Single-task TDD implementation
      implement-team/SKILL.md                  #   Team parallel implementation
      code-review/SKILL.md                     #   3-axis code review
      review-fix/SKILL.md                      #   Auto-fix loop
      full-review/SKILL.md                     #   Comprehensive 5-phase review
      plan-status/SKILL.md                     #   Progress reporter
      architecture-check/SKILL.md              #   Architecture compliance check
    agents/                                    # Specialist agent definitions
      convention-reviewer.md                   #   Convention compliance reviewer
      quality-reviewer.md                      #   Quality reviewer
      test-coverage-reviewer.md                #   Test coverage reviewer
      architecture-analyzer.md                 #   Architecture analyzer
      plan-reader.md                           #   Plan reader
  docs/
    plan/
      tasks.json                               # Task management
      progress.json                            # Progress tracking
    reviews/                                   # Review output directory
```

---

## Skills Overview

ai-dev-harness operates as Claude Code skills (slash commands).

| Skill | Description | Usage |
|-------|-------------|-------|
| `/implement` | Implement a single task with TDD. Runs planning, testing, implementation, analysis, and status update in one flow | `/implement ARC-015` |
| `/implement-team` | Parallel team implementation of multiple tasks. Delegates each task to an independent agent | `/implement-team ARC-015 ARC-016 ARC-017` |
| `/code-review` | 3 independent reviewers audit conventions, quality, and tests in parallel. Generates A/B/C/D graded report | `/code-review` |
| `/review-fix` | Auto-loops review, fix, re-review until zero issues remain. MUST-only mode available | `/review-fix` or `/review-fix must` |
| `/full-review` | Pre-ship comprehensive review: code quality, UI audit, UX evaluation, security scan, final checklist | `/full-review` |
| `/plan-status` | Analyzes and reports project plan and progress from `tasks.json` / `progress.json` | `/plan-status` |
| `/architecture-check` | Compares codebase against Clean Architecture target, detects deviations, auto-generates tasks | `/architecture-check` |

---

## Workflow

The typical development flow looks like this:

```
/plan-status                        Check status at session start
    |
    v
/implement TASK-001                 Task implementation (TDD)
    |
    |-- Phase 0: Sprint Contract    Pre-planning, scope agreement
    |-- Phase 1: TDD                Red -> Green -> Refactor
    |-- Phase 2: Auto Review        3-axis automatic review
    |-- Phase 3: Status Update      Task completion update
    |
    v
/code-review                        Additional review (optional)
    |
    +-- Grade A/B --> Done
    |
    +-- Grade C/D --> /review-fix   Auto-fix loop
                          |
                          +-- Fix -> Re-review -> Fix ...
                          |
                          +-- Grade A/B --> Done

Pre-ship:
/full-review                        Comprehensive review (5 phases)
    |
    +-- Grade A/B --> Ship!
    |
    +-- Grade C/D --> /review-fix
```

### Parallel Multi-Task Implementation

```
/implement-team ARC-015 ARC-016 ARC-017
    |
    |-- Agent A: ARC-015 (independent context)
    |-- Agent B: ARC-016 (independent context)
    |-- Agent C: ARC-017 (independent context)
    |
    v
    All tasks complete -> /code-review
```

### Automatic Gate on Commit

```
git commit -m "feat: ..."
    |
    +-- PreToolUse Hook fires
    +-- {{ANALYZE_CMD}} runs automatically
    +-- Failure --> Commit aborted
    +-- Success --> Commit proceeds
```

---

## Configuration Reference

The key sections of `harness.yaml` are explained below. For complete field documentation, see [`harness.yaml.example`](harness.yaml.example).

### project -- Project Identity

```yaml
project:
  name: "my-project"    # Used in file paths and team names
  language: "en"         # Output language: "ja" | "en"
```

### stack -- Language and Framework

```yaml
stack:
  primary_language: "typescript"   # dart | typescript | python | go | rust
  framework: "nextjs"              # flutter | nextjs | fastapi | express | django
```

Determines template selection and lint rule generation.

### commands -- Command Definitions

```yaml
commands:
  analyze: "npx eslint . && npx tsc --noEmit"   # Static analysis (REQUIRED, pre-commit hook)
  test: "npx jest"                                # Test runner (REQUIRED, TDD cycle)
  build_generated: "npx prisma generate"          # Code generation (optional)
  format: "npx prettier --write ."                # Formatting (optional)
```

`analyze` runs automatically via the pre-commit hook, ensuring static analysis passes before every commit.

### architecture -- Architecture Layer Definition

```yaml
architecture:
  style: "clean"                    # clean | layered | hexagonal | none
  layers:
    presentation: "src/app"
    domain: "src/domain"
    data: "src/data"
    core: "src/lib"
  additional_sources:               # Monorepo support
    - path: "functions"
      language: "typescript"
      analyze: "cd functions && npm run lint"
```

Referenced by `/architecture-check` to verify dependency direction between layers.

### conventions -- Convention Mapping

```yaml
conventions:
  mapping:
    - paths: ["src/app/**"]
      files: [".claude/rules/component-style.md", "docs/conventions/react-patterns.md"]
    - paths: ["src/data/**"]
      files: [".claude/rules/repository-design.md"]
  global:
    - "docs/conventions/architecture.md"
```

Defines which convention files to read for each path. Skills automatically reference matching conventions before implementation and review.

### review -- Review Configuration

```yaml
review:
  design_system:
    class_name: "AppColors"        # Design token class (empty string = check disabled)
    file: "src/lib/theme/colors.ts"
  error_handling:
    result_type: "Result"          # Result | Either | "" (check disabled)
    exception_class: "AppError"
  testing:
    mock_library: "jest.mock"
    naming_language: "en"
    naming_pattern: "should do X when Y"
    tdd_required_for:
      - "Service"
      - "Repository"
      - "UseCase"
```

### modules -- Enable/Disable Skills

```yaml
modules:
  implement: true          # /implement
  implement_team: true     # /implement-team
  code_review: true        # /code-review
  review_fix: true         # /review-fix
  full_review: true        # /full-review
  plan_status: true        # /plan-status
  architecture_check: true # /architecture-check
  design_skills: true      # Design enhancement skills
```

Set any skill to `false` to disable it.

### models -- Agent Model Selection

```yaml
models:
  reviewer: "sonnet"       # For review agents
  analyzer: "sonnet"       # For architecture analysis
  planner: "haiku"         # For plan reading (lightweight)
```

### git -- Git Configuration

```yaml
git:
  main_branch: "main"      # Default PR target branch
```

---

## Architecture

The internal structure of ai-dev-harness and the relationship between components:

```
harness.yaml (config)
     |
     | init.sh (generates)
     v
+----+-----------------------------------------------------+
|                    Generated Files                        |
|                                                          |
|  CLAUDE.md              .claude/settings.json            |
|  (instructions)          (hooks & env vars)              |
+---+-------------------+---------------------------------+
    |                   |
    v                   v
+---+--------+  +-------+--------+
|  Skills    |  |  Pre-commit    |
|  (7 types) |  |  Hook          |
+---+--------+  |  auto-analyze  |
    |           +-------+--------+
    |                   |
    v                   v
+---+-------------------+---------------------------------+
|                 Claude Code Agent                        |
|                                                          |
|  +------------+  +------------------+  +------------+    |
|  | Implement  |  | Review Agents    |  | Fix Agent  |    |
|  | Agent      |  | (3 independent)  |  |            |    |
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
|  (project rules)          (coding conventions)           |
|                                                          |
|  docs/plan/*             docs/reviews/*                  |
|  (tasks & progress)      (review results)                |
+----------------------------------------------------------+
```

### Design Patterns (Based on Anthropic Blog Post)

| Pattern | Implementation in Harness |
|---------|--------------------------|
| **Generator-Evaluator Separation** | Implementation and review agents are separated. 3 independent reviewers audit in parallel |
| **Sprint Contracts** | `/implement` Phase 0 agrees on completion criteria and scope before TDD begins |
| **File-based Communication** | Review results persisted to `docs/reviews/`. Survive session restarts |
| **Context Reset Points** | Team delegation gives each agent independent context. Prevents degradation from accumulation |
| **Hard Threshold Gates** | A/B/C/D scoring for pass/fail judgment. C/D blocks merge |
| **Iterative Refinement** | `/review-fix` auto-loops up to 5 rounds of fixes |
| **Adversarial Self-Check** | Reviewers are oriented to "find problems" + reference calibration examples |

For details, see [docs/harness-design.md](docs/harness-design.md).

---

## Examples

### Flutter

Clean Architecture Flutter app with Firebase backend and Cloud Functions:

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

Full config: [`examples/flutter/harness.yaml`](examples/flutter/harness.yaml)

### Next.js SaaS

SaaS dashboard with App Router + Prisma + NextAuth:

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

Full config: [`examples/nextjs/harness.yaml`](examples/nextjs/harness.yaml)

### Python FastAPI

Backend API with SQLAlchemy + Alembic:

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

Full config: [`examples/python-fastapi/harness.yaml`](examples/python-fastapi/harness.yaml)

---

## Customization

### Adding Convention Files

1. Create a Markdown file in `.claude/rules/` or `docs/conventions/`
2. Register it in `harness.yaml` under `conventions.mapping`
3. Re-run `~/ai-dev-harness/init.sh`

```yaml
conventions:
  mapping:
    - paths: ["src/app/api/**"]
      files: [".claude/rules/api-design.md"]
```

### Modifying Reviewer Checks

Add rules to convention files and reviewers will automatically include them in their checks:

```markdown
<!-- .claude/rules/api-design.md -->
# API Design Rules
- Use kebab-case for URL paths
- Always return { data, error, meta } envelope
```

### Adding Custom Skills

1. Create `.claude/skills/my-skill/SKILL.md`
2. Define the workflow steps in `SKILL.md`

### Changing Output Language

```yaml
project:
  language: "ja"    # Change "en" -> "ja"
```

Re-run `init.sh` to regenerate from the selected language templates.

For details, see [docs/customization-guide.md](docs/customization-guide.md).

---

## Command Options

```bash
# Preview (no file writes)
~/ai-dev-harness/init.sh --dry-run

# Overwrite existing files without confirmation
~/ai-dev-harness/init.sh --force

# Specify output language
~/ai-dev-harness/init.sh --lang en

# Validate config only
~/ai-dev-harness/scripts/validate-config.sh

# Update templates
~/ai-dev-harness/scripts/update.sh ~/ai-dev-harness
```

---

## Updating

When new template versions are released:

```bash
cd ~/ai-dev-harness
git pull origin main

cd your-project
~/ai-dev-harness/init.sh    # Regenerate config files
```

Your `harness.yaml` is your own config file and will not be overwritten. Only template-generated files are updated.

For details, see [docs/updating.md](docs/updating.md).

---

## Documentation

| Document | Contents |
|----------|----------|
| [`harness.yaml.example`](harness.yaml.example) | Fully annotated config template with all fields explained |
| [`docs/harness-design.md`](docs/harness-design.md) | Harness design pattern explanations (based on Anthropic blog post) |
| [`docs/customization-guide.md`](docs/customization-guide.md) | Guide for adding conventions, customizing reviewers, CI integration |
| [`docs/updating.md`](docs/updating.md) | Template update procedures |

---

## Credits

- **Design Philosophy**: Anthropic ["Claude Code: Best practices for agentic coding"](https://www.anthropic.com/engineering/claude-code-best-practices)
- **Origin**: Practices developed during a production Flutter project, generalized for any stack
- **Runtime**: [Claude Code](https://claude.ai/claude-code) (Anthropic)

---

## License

MIT License. See [LICENSE](LICENSE) for details.

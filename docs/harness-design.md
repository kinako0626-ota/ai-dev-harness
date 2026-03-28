# Harness Design Patterns

This document explains the design patterns used in ai-dev-harness, based on principles from the Anthropic blog post ["Harness Design for Long-Running Application Development"](https://www.anthropic.com/engineering/claude-code-best-practices).

## Overview

A "harness" is the scaffolding that surrounds an AI coding agent -- the rules, tools, review processes, and feedback loops that guide the agent toward reliable, high-quality output. Without a harness, an AI agent can drift, accumulate errors, and produce inconsistent code. With a well-designed harness, the same agent becomes a disciplined team member.

ai-dev-harness encodes seven key patterns into reusable skills and configuration.

---

## Pattern 1: Generator-Evaluator Separation

**Problem:** When the same agent writes and reviews its own code, it has a systematic blind spot for its own mistakes.

**Solution:** Separate the generation (implementation) role from the evaluation (review) role. Use independent agents with different contexts and instructions.

### How ai-dev-harness implements this

The `/code-review` skill delegates to **3 independent reviewer agents**, each with a distinct persona and focus area:

| Reviewer | Focus |
|----------|-------|
| Reviewer A | Architecture compliance, dependency direction, layer violations |
| Reviewer B | Code quality, naming, duplication, complexity |
| Reviewer C | Testing coverage, edge cases, error handling |

Each reviewer operates in isolation -- they do not see each other's findings. Their reports are merged into a single review document. This eliminates "groupthink" where one reviewer's opinion anchors the others.

The `/full-review` skill extends this further with **5 sequential phases**, each with a dedicated evaluator:

1. **Code Quality** -- Style, conventions, architecture
2. **UI Audit** -- Design system compliance, accessibility
3. **UX Evaluation** -- User flow, error states, edge cases
4. **Security Scan** -- Input validation, auth checks, data exposure
5. **Final Checklist** -- Release readiness, documentation, migration needs

---

## Pattern 2: Sprint Contracts

**Problem:** Long-running tasks lose coherence. The agent forgets constraints, makes contradictory decisions, or goes off-track.

**Solution:** Break work into small, well-defined "sprints" with explicit contracts -- inputs, outputs, constraints, and acceptance criteria.

### How ai-dev-harness implements this

The `/implement` skill enforces a **Phase 0 (Planning)** before any code is written:

1. Read the task definition from `tasks.json`
2. Read all relevant convention files (determined by `conventions.mapping`)
3. Produce a plan: files to create/modify, test cases to write, dependencies
4. Only after the plan is validated does implementation begin

The task definition in `tasks.json` acts as the sprint contract:

```json
{
  "id": "ARC-015",
  "title": "Implement weight graph repository",
  "description": "...",
  "acceptance_criteria": ["...", "..."],
  "dependencies": ["ARC-012", "ARC-013"],
  "estimated_complexity": "medium"
}
```

This contract is immutable during implementation -- the agent cannot redefine the task mid-sprint.

---

## Pattern 3: File-Based Communication

**Problem:** Conversation context is volatile. Information shared in one message can be forgotten or misinterpreted in later messages.

**Solution:** Use files as the persistent communication medium. Write structured reports that survive context resets.

### How ai-dev-harness implements this

All review output is written to `docs/reviews/`:

```
docs/reviews/
  code-review-2026-03-28.md      # /code-review output
  full-review-2026-03-28.md      # /full-review output
  architecture-check-2026-03-28.md  # /architecture-check output
```

These files serve multiple purposes:

- **Persistence:** Survive session restarts and context window limits
- **Auditability:** Track what was reviewed and when
- **Handoff:** The `/review-fix` skill reads the review file to know what to fix
- **Progress tracking:** `progress.json` is the single source of truth for project status

The task system (`tasks.json` + `progress.json`) is another example of file-based communication: skills read and write these files to coordinate without relying on conversation state.

---

## Pattern 4: Context Reset Points

**Problem:** As conversation context grows, the agent's performance degrades. Irrelevant earlier context dilutes attention on the current task.

**Solution:** Design explicit points where context is deliberately reset, starting fresh with only the information needed for the next phase.

### How ai-dev-harness implements this

The `/implement-team` and `/review-fix` skills use **Team delegation** (via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`):

```
Main Agent (orchestrator)
  |-- delegates to --> Implementation Agent A (fresh context: task + conventions)
  |-- delegates to --> Implementation Agent B (fresh context: task + conventions)
  |-- delegates to --> Review Agent (fresh context: diff + conventions)
```

Each delegated agent starts with a clean context containing only:
- The specific task or review assignment
- Relevant convention files
- The minimum code context needed

This prevents "context pollution" where debugging details from Task A leak into Task B's implementation.

The session startup instruction (`/plan-status` at session start) is another reset point -- it forces the agent to re-acquire current project state rather than relying on stale assumptions.

---

## Pattern 5: Hard Threshold Gates

**Problem:** Subjective quality assessments ("looks good") are unreliable. The agent may approve code that doesn't meet standards.

**Solution:** Define objective, non-negotiable quality gates with clear pass/fail criteria.

### How ai-dev-harness implements this

The `/code-review` skill assigns letter grades with hard thresholds:

| Grade | Meaning | Action |
|-------|---------|--------|
| **A** | No issues found | Merge-ready |
| **B** | Minor suggestions only | Merge-ready (suggestions optional) |
| **C** | Issues found that should be fixed | Fix required before merge |
| **D** | Significant problems | Major rework needed |

The grading criteria are objective:

- Architecture violation (wrong layer dependency) = automatic C or below
- Missing tests for TDD-required class = automatic C or below
- Design system violation (hardcoded colors) = automatic C or below
- Security issue (exposed credentials, unvalidated input) = automatic D

The pre-commit hook enforces the most basic gate: `{{ANALYZE_CMD}}` must pass before any commit is allowed. This is not optional -- the hook runs automatically.

---

## Pattern 6: Iterative Refinement

**Problem:** A single review-fix cycle often isn't enough. First fixes can introduce new issues, and some problems are only visible after initial fixes are applied.

**Solution:** Loop: review, fix, re-review until the quality gate is passed.

### How ai-dev-harness implements this

The `/review-fix` skill implements an automatic loop:

```
1. Run /code-review --> generates review report
2. Read review report, identify MUST-fix items
3. Fix all MUST items (and optionally SHOULD items)
4. Run {{ANALYZE_CMD}} to verify no regressions
5. Run /code-review again on the new diff
6. If new issues found --> go to step 2
7. If clean (grade A or B) --> done
```

The loop has a configurable maximum iteration count (default: 3) to prevent infinite loops. If grade C or below persists after max iterations, the skill reports the remaining issues for human intervention.

Two modes are available:
- `/review-fix` -- Fix both MUST and SHOULD items
- `/review-fix must` -- Fix only MUST items (faster, for time-sensitive fixes)

---

## Pattern 7: Self-Evaluation Bias Mitigation

**Problem:** AI agents are systematically biased toward rating their own work positively. A single self-review is unreliable.

**Solution:** Use multiple independent evaluators, adversarial prompts, and calibration against known standards.

### How ai-dev-harness implements this

Three mechanisms counter self-evaluation bias:

### 7a. Independent Multi-Reviewer

As described in Pattern 1, three reviewers operate independently. Even if one reviewer has a blind spot, the others are likely to catch the issue. The probability of all three missing the same issue is much lower than a single reviewer missing it.

### 7b. Adversarial Self-Check

Each reviewer is explicitly prompted to look for problems:

> "Your job is to find issues, not to approve. Assume the code has problems and look for them. A review that finds nothing is suspicious -- double-check."

This adversarial framing counters the "looks good to me" default.

### 7c. Convention Calibration

Reviewers are given the project's convention files as a concrete checklist, not abstract quality guidelines. Instead of "is this code good?", the question becomes "does this code follow rule X in document Y?". This grounds evaluation in objective, auditable criteria.

```
Convention: .claude/rules/color-usage.md
Rule: "AppColors クラスの定数を使用すること"
Check: Does this diff contain Color(0x...) or Color.fromRGBO()?
Result: PASS / FAIL
```

---

## Putting It All Together

The patterns reinforce each other:

```
Sprint Contract (Pattern 2)
    |
    v
Implementation (fresh context via Pattern 4)
    |
    v
Pre-commit Gate (Pattern 5: analyze must pass)
    |
    v
Generator-Evaluator Split (Pattern 1: 3 independent reviewers)
    |
    v
File-based Report (Pattern 3: docs/reviews/)
    |
    v
Hard Threshold (Pattern 5: grade A/B = pass, C/D = fail)
    |
    +--> PASS --> Done
    |
    +--> FAIL --> Iterative Fix Loop (Pattern 6)
                    |
                    v
                  Anti-bias Review (Pattern 7)
                    |
                    +--> PASS --> Done
                    +--> FAIL --> Loop again (max 3)
```

This creates a system where:
1. Work is well-scoped before it begins
2. Implementation happens in clean, focused contexts
3. Review is independent and adversarial
4. Quality gates are objective and enforced
5. Problems are caught and fixed iteratively
6. All artifacts persist in files for auditability

The result is that AI-assisted development produces output comparable to a disciplined human team -- not because the AI is perfect, but because the harness catches and corrects its imperfections.

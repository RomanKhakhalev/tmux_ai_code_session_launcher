---
name: implement-plan-regression
description: Review staged and unstaged git diffs against an implementation plan and the current agent thread history to catch visible or UX regressions, workflow drift, parallel Tellis W/G/M or accounting ownership, and violations of explicit user decisions. Use when the user asks to check a plan file against the current diff, re-run a regression review after debugging, or verify that staged/unstaged changes still match agreed UX and workflow behavior.
---

# Implement Plan Regression

Use this skill to check whether the current implementation has drifted from:
- a plan file
- explicit UX or workflow decisions made with the user in the current thread
- previously agreed wording or state transitions
- existing Playwright or DoD-style test evidence that helps explain intended behavior
- explicit single-owner locks for Tellis W/G/M lifecycle, current-artifact identity, and usage accounting

This is a regression review skill, not a general code review. Focus on visible behavior, interaction flow, copy, guardrails, state consistency, and workflow-visible ownership regressions. For Tellis durable pipelines, a second lifecycle or accounting owner is workflow-visible even when the immediate diff has no UI changes.

## Inputs

Expect:
- a plan file path
- the current thread history as the source of user decisions

If the plan file path is missing, ask for it.

If the thread was compacted, use the available thread summary and visible messages as the decision record. Do not invent earlier decisions that are not present.

When available, also use:
- relevant Linear issue context already present in the thread or fetched during the work that produced the diff
- existing Playwright specs or other DoD artifacts referenced by the plan, Linear issues, or thread

## Review Scope

Always inspect both:
- unstaged diff: `git diff`
- staged diff: `git diff --cached`

Treat them as one review surface, but call out whether each finding is:
- unstaged
- staged
- present in both

Prioritize:
- visible UI regressions
- interaction-flow regressions
- mismatches between state labels and actual behavior
- reversions of user-approved wording or UX decisions
- cases where one part of the UI was updated but related behavior was left behind
- unjustified weakening of Playwright coverage when a spec previously served as meaningful DoD evidence
- blunt copy-paste duplication introduced across touched files, especially duplicated branches, helpers, validation rules, UI blocks, test scaffolds, or prompt/label logic that should clearly share one implementation
- routes, workers, pipeline-specific collections, Redis records, wrappers, or compatibility paths that independently create/finalize W/G/M state, select current artifacts, reconcile lifecycle state, or maintain usage totals outside the canonical owner
- partial reuse where the diff calls canonical W/G/M or `usage_events` helpers but also introduces a competing source of truth

Ignore:
- pure refactors with no visible effect
- generic code quality concerns unless they create a likely user-facing regression or are blunt copy-paste duplication introduced by the current diff
- unrelated worktree noise
- Playwright spec churn by itself when the changed spec still matches the plan intent and the revised assertions remain a reasonable DoD outline

## Workflow

### 1. Read the plan

Re-open and re-read the plan file from disk immediately before starting the regression review. Do not rely on a prior read, cached summary, or thread memory if the plan may have changed.

Open the plan file and extract:
- user-visible requirements
- workflow expectations
- accepted tradeoffs
- explicit exclusions
- canonical W/G/M, RunItem, artifact, and usage-accounting owners
- any explicit lock forbidding parallel lifecycle, current-artifact, or accounting mechanisms

Prefer a short scratch list of concrete expectations such as:
- “row click opens settings only”
- “Start draft auto-generates”
- “badge wording must be `Ready to publish`”

Also note any existing test/DoD evidence the plan explicitly references. Treat that evidence as a soft outline of expected observable behavior, not as a literal freeze on the exact selector, copy string, or assertion strategy.

### 2. Reconstruct thread decisions

Read the current thread history and collect only explicit decisions or approvals from the user.

Examples:
- wording choices
- placement decisions
- whether an icon should stay or be removed
- whether a state should be hidden or shown
- whether a flow should auto-run or wait for confirmation

Do not treat tentative brainstorming as a final decision unless the user explicitly accepted it.

If the thread or visible work already includes Linear issue evidence, comments, screenshots, or prior spec rationale, use that material to understand what the test was trying to prove.

### 3. Bound the diff

Start with:

```bash
git diff --stat
git diff --stat --cached
```

Then inspect the actual diffs for touched files:

```bash
git diff -- <paths>
git diff --cached -- <paths>
```

Read only the files needed to verify behavior.

Build the touched-file set from both staged and unstaged diffs:

```bash
git diff --name-only
git diff --cached --name-only
```

When the plan touches a Tellis durable workflow, classify every newly added or changed route, worker, collection, Redis key, compatibility wrapper, and usage field in the diff:
- **canonical owner** — creates or mutates authoritative W/G/M, RunItem, artifact, or `usage_events` state
- **projection/transport** — reflects or carries canonical state without independently deciding it
- **parallel owner** — independently creates, finalizes, selects, reconciles, or totals the same state

Treat any parallel owner as a regression unless the plan explicitly defines it as a replacement and includes migration, compatibility, and deprecation steps. Redis polling state and cached rollups must remain projections, not lifecycle or accounting sources of truth.

For every touched source, test, config, or docs file in that set, check for blunt copy-paste duplication introduced by the current diff:
- compare newly added blocks against nearby existing code in the same file
- compare similar additions across touched files
- look for repeated conditionals, request/response mappers, validation snippets, UI rows/cards/tooltips, status-label logic, prompt strings, test setup, and mock payloads
- distinguish intentional parallel structure from avoidable duplication by asking whether the duplicated block would need to be edited in multiple places for the same future behavior change
- do not flag short repeated literals, conventional imports, tiny type declarations, table columns, fixture data, or deliberate symmetry unless the duplication creates real drift risk

When a duplication concern is plausible, inspect enough surrounding code to identify the existing helper, shared component, fixture builder, or local extraction point that should own the repeated logic. If no reasonable shared home exists, do not force an abstraction; report only when the pasted duplication is blunt and materially likely to drift.

If the diff touches Playwright specs, or the plan references existing specs:
- inspect the relevant spec diffs
- inspect the current spec(s) they replace or modify
- inspect any closely related plan / Linear / thread evidence that explains the intended observable behavior

Do not assume “spec changed” means “regression.” First determine whether the changed assertions are a justified rewrite that better matches the locked plan intent.

### 4. Compare behavior, not intent

For each touched UX surface, compare:
- current behavior implied by the diff
- planned behavior from the file
- thread-approved behavior

Look for partial fixes where:
- labels changed but logic did not
- readiness state changed but approval flow did not
- drawer state changed but navigation guard did not
- one panel reflects a new rule while another still uses the old rule
- the same new behavior was copied into multiple places instead of using an existing shared helper/component, making later behavior or wording updates likely to diverge

For Tellis W/G/M and accounting locks, compare the diff against the canonical ownership chain named by the plan. Check that:
- W remains the long-lived workflow owner and G/M remain command-scoped execution owners
- RunItems remain the authority for claims, leases, attempts, failures, and pending accounting
- the established domain service/repository owns lifecycle and current-artifact mutations
- every charged provider attempt reaches canonical `usage_events` with the planned batch attribution
- cached rollups, Redis state, pipeline-specific collections, endpoint payloads, and wrappers do not become alternate usage or lifecycle authorities
- intentional domain differences remain adapters or durable handoff mechanisms, not second owners

For Playwright or DoD-style specs, compare:
- what behavior the old spec was trying to prove
- what behavior the new spec proves
- whether the plan/thread/Linear intent changed enough to justify that spec rewrite

Treat existing specs as soft test-driven DoD outlines:
- useful evidence of intended observable behavior
- not a strict requirement that every old assertion or displayed label must remain unchanged

Only flag a spec change when it:
- drops meaningful coverage without replacing it
- stops checking the behavior the plan still cares about
- masks a regression by switching from a behavior assertion to a weaker navigation or existence assertion
- contradicts explicit plan/thread decisions about what must remain observable

### 5. Report only real regressions

A finding should meet both:
- the behavior is user-visible or workflow-visible
- it conflicts with the plan or an explicit user decision, or creates a clear inconsistency in the visible product

For an explicit Tellis single-owner lock, a parallel W/G/M, current-artifact, or accounting mechanism is a **High** workflow regression by itself. Do not require separate UI impact. Report the competing path, the canonical owner it bypasses or duplicates, and whether the fix should remove the path or convert it into a projection/transport.

For blunt copy-paste duplication findings, use this separate bar:
- the duplication is introduced or substantially expanded by the current staged/unstaged diff
- it appears in one or more touched files
- it is large or specific enough that future changes would likely need coordinated edits in multiple places
- it duplicates behavior, validation, mapping, UI, or test setup that has a reasonable shared home or should be locally extracted

For spec-only findings, require an extra bar:
- the spec drift materially weakens confidence in the intended behavior, or
- the spec now enshrines behavior that conflicts with the plan intent

If the spec change is justified by the plan intent, say so briefly and do not turn it into a regression finding.

## Output Format

Findings first, ordered by severity.

For each finding include:
- severity (`High`, `Medium`, `Low`)
- one-sentence impact
- why it regressed from the plan or thread decision
- file reference with line numbers
- whether it is in `unstaged`, `staged`, or `both`

For blunt copy-paste duplication findings, also include:
- the duplicated locations
- the shared helper/component/fixture/extraction point that should own the behavior when obvious

After findings, include:
- `No additional visible regressions found` if applicable
- `No blunt copy-paste duplication found across touched files` if the duplicate-code pass found nothing reportable
- `No parallel W/G/M or accounting ownership found` when a Tellis durable-workflow ownership check was applicable and passed
- residual risks or validation gaps only if they matter

If Playwright specs were part of the review surface, briefly note whether the spec changes appear:
- aligned with the plan intent
- softer but still acceptable as DoD outline
- or materially weakened

Keep the summary brief. Do not bury findings under long recaps.

## Example Trigger Phrases

This skill should be used for requests like:
- “check git diff against discussed within this thread”
- “review staged and unstaged diff against this plan”
- “did debugging introduce any UX regression?”
- “compare the current diff to the implementation plan and user decisions”

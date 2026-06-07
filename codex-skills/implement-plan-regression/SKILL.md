---
name: implement-plan-regression
description: Review staged and unstaged git diffs against an implementation plan and the current agent thread history to catch visible or UX regressions, workflow drift, and violations of explicit user decisions. Use when the user asks to check a plan file against the current diff, re-run a regression review after debugging, or verify that staged/unstaged changes still match agreed UX behavior.
---

# Implement Plan Regression

Use this skill to check whether the current implementation has drifted from:
- a plan file
- explicit UX or workflow decisions made with the user in the current thread
- previously agreed wording or state transitions
- existing Playwright or DoD-style test evidence that helps explain intended behavior

This is a regression review skill, not a general code review. Focus on visible behavior, interaction flow, copy, guardrails, and state consistency.

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

Ignore:
- pure refactors with no visible effect
- generic code quality concerns unless they create a likely user-facing regression
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

After findings, include:
- `No additional visible regressions found` if applicable
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

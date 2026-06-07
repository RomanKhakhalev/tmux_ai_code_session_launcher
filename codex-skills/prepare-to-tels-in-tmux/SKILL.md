---
name: prepare-to-tels-in-tmux
description: Prepare a TEL tmux work session before implementation by reading the current tmux session name, deriving the TEL issue list, gathering full Linear issue context, investigating the local codebase, checking attached Playwright DoD evidence for UI issues, and producing intent, fix DoD, and lock questions for user confirmation.
---

Prepare a multi-issue TEL tmux session before any code is written.

This skill is for discovery and plan-lock only. Do not implement, edit code, or propose final code changes unless the user explicitly switches from preparation to implementation.

## Goal

Build a full working understanding of every TEL issue encoded in the current tmux session, then convert that into:

- the issue intent in product terms
- the likely technical surfaces involved
- the fix definition of done
- the open product/design questions that must be locked before implementation
- a concise confirmation prompt asking the user to validate the understanding

## Session parsing

Start by reading the current tmux session name:

```bash
tmux display-message -p '#S'
```

Parse TEL issue identifiers from the session name.

Primary expected format:
- `TEL_221_224_225_226` -> `TEL-221`, `TEL-224`, `TEL-225`, `TEL-226`

Rules:
- Treat the first `TEL` token as the shared prefix.
- Convert each numeric segment into `TEL-<number>`.
- Preserve the order from the session name.
- Deduplicate repeated numbers.
- If the session name does not clearly encode TEL issue IDs, stop and ask the user for the exact issue list.

## Working rules

- Stay in the current worktree and treat it as the implementation target.
- Gather evidence before making inferences.
- Prefer primary sources: Linear issue body, comments, attachments, current branch code, existing tests.
- Do not jump into solutioning before the evidence pass is complete.
- Treat the Linear issue body, comments, and suggested root causes as hypotheses, not facts, until they are checked against the current codebase.
- If multiple issues overlap, identify both the shared scope and the issue-specific intent.
- If the branch already contains work, read it as context only. Do not modify it.
- Do not ask the user questions that can be answered from the worktree, Linear history, attachments, configs, tests, or other available local evidence.

## Workflow

### 1. Gather full Linear context for every issue

For each parsed TEL issue:

- Fetch the full issue record, including description, state, labels, project, relations, and attachments.
- Fetch all available comments, not just the latest page.
- Review attachment metadata and inspect attachment content when it materially changes understanding.
- If screenshots or markdown-embedded images exist, inspect them.
- Build a short chronology of the issue:
  - original problem
  - later clarifications
  - design/product decisions
  - implementation constraints
  - QA or DoD notes

Capture only evidence that matters for implementation planning.

### 2. Investigate the local codebase with no implementation

Use the issue evidence to identify likely affected surfaces in the current worktree.

Investigate:
- current branch name
- any relevant existing branch changes if present
- likely services and components touched
- existing routes, models, hooks, components, helpers, tests, and configs
- existing patterns that constrain the eventual fix
- whether the issue description's claimed root cause, failure path, or proposed options still match the live code

For each issue, explicitly verify ticket claims against the checked code:
- If the issue body names a specific root cause, confirm whether that code path still exists.
- If the issue body proposes options, confirm whether each option is still relevant given the current architecture.
- If the code contradicts the issue description, call that out explicitly before synthesis instead of carrying the ticket language forward as fact.
- If a remaining uncertainty is inherently runtime-only, state that it is runtime-only and explain why the codebase could not resolve it.

Build a codebase knowledge map for each issue:
- likely files or modules involved
- why each area matters
- existing patterns to preserve
- obvious dependencies between issues
- any ticket-vs-code divergence that changes the framing of the issue

Do not write code and do not output speculative file lists that were not checked.

### 3. If the issues are UI-facing, investigate Playwright DoD evidence

Treat an issue as UI-related if the evidence points to user-visible behavior, visual regressions, interaction flows, layout, content presentation, or attached screenshots/mockups.

For UI issues:
- Check whether a Playwright DoD test or test artifact is attached in Linear.
- Inspect the attached Playwright evidence if accessible.
- Inspect related local Playwright or frontend tests when they help explain the expected behavior.
- Extract the exact observable behavior the DoD is asserting.

If a UI issue appears to rely on a Playwright DoD artifact but none is attached or accessible, say that explicitly instead of guessing.

### 4. Think through product and UX intent

Once evidence gathering is complete, synthesize the issues from a product/UX perspective before talking about implementation.

For each issue, state:
- the user or operator problem being fixed
- the intended behavior after the fix
- what would count as complete from a product perspective
- what would count as complete from a QA/DoD perspective
- any ambiguity that could lead to implementation churn or reviewer disagreement

If several TEL issues form one workflow, describe:
- the shared outcome
- the boundaries between the issues
- the order or coupling that matters

### 5. Ask lock questions before implementation

After the synthesis, ask only the questions that materially lock the implementation plan.

Before asking any question, confirm it cannot be answered from the codebase, current branch, tests, configs, Linear issue history, or attachments.
Questions about whether the current code still matches the ticket should be answered from the code review first, not delegated back to the user.

Prefer questions about:
- product intent
- design choices
- wording/labels
- edge-case behavior
- acceptance boundaries
- ownership of cross-issue scope
- runtime-only behavior that cannot be established from static evidence alone, and only after stating what the codebase does show

Avoid low-value engineering questions that can be answered from the codebase.

## Output format

Use this structure:

### Session
- tmux session name
- parsed TEL issue list
- current branch name

### Issue evidence
For each issue:
- title and current state
- distilled problem statement
- key attachments or screenshots
- important comment-derived decisions
- related issues or dependencies if relevant
- whether the ticket's stated root cause or framing was confirmed or contradicted by the current code

### Codebase map
For each issue:
- checked files/components/services
- established patterns that the future implementation should preserve
- cross-issue overlap
- verified root-cause findings and any stale ticket assumptions

### UI / Playwright notes
Include only for UI issues:
- whether Playwright DoD evidence was found
- what behavior it verifies
- any gaps in the available test evidence

### Understanding by issue
For each issue:
- intent
- likely fix scope
- fix DoD
- risks or ambiguity

### Lock questions
- List the minimum set of product/design clarification questions needed to lock the implementation plan.
- Do not include questions whose answers should have come from code inspection.
- If a question is runtime-only, label it as runtime-only.

### Confirmation prompt
End with a short confirmation request asking the user whether the understanding is correct before implementation starts.

## Quality bar

The final preparation output should let a reviewer answer:

- Do we understand what each TEL issue is actually trying to achieve?
- Do we know which code areas matter?
- Do we know what QA will consider done?
- Have we surfaced the product/design decisions that still need to be locked?
- Have we verified whether the ticket description still matches the current code?
- Have we avoided bouncing code-answerable questions back to the user?

If the answer to any of those is no, keep investigating before presenting the final preparation summary.

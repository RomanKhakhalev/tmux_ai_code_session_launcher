---
name: start_auto_with_codex
description: Autonomously drive a plan from Codex pre-implementation review through implementation to a clean regression check and a clean reviewer.py code review. Resolves the current session's plan file, loops `reviewer/codex-plan-reviewer.sh --plan <file>` fixing findings in the plan until GATE:pass, implements the plan, then loops `--check-plan-regression` fixing the real code until REGRESSION_GATE:pass, then loops `reviewer/reviewer.py --implementation-plan <file>` until GATE:PASS (re-running the regression loop if reviewer.py needs 4+ rounds) — auto-fixes everything the plan is silent on plus cheap, justified cleanliness/performance/bug fixes without asking, defers structural fixes to a new Linear issue (labels Bug + discoveredByAI) with an append-only note in the plan, and stops to consult the user only on its own judgment that a fix contradicts a plan lock or changes behavior/UX/persistence beyond the issue. Triggers when user says "start auto with codex", "auto codex loop", "/start_auto_with_codex".
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Write, Edit, mcp__Linear__get_issue, mcp__Linear__list_comments, mcp__Linear__list_issues, mcp__Linear__save_issue
context: inline
---

You are driving a plan from review to a regression-clean, code-review-clean implementation using the Codex plan reviewer (`reviewer/codex-plan-reviewer.sh`) and the full code reviewer (`reviewer/reviewer.py`). This is a plan-gate loop, not a one-off review: the default is to verify each finding against the actual code and fix it silently, without asking — the plan (and the issue text behind it) is the decision record, and unwritten details are yours to implement. Cheap, justified scope changes (bug, cleanliness, performance) are fixed too; structural ones are deferred to Linear and appended to the plan (Step 0d, Tier 2). You only stop (Step 0d, Tier 3) when *you* judge a specific fix contradicts a plan lock or changes behavior/UX/persistence beyond the issue — that judgment call is on you, not a checklist to run against every finding.

$ARGUMENTS may contain an explicit plan path or filename. If present, use it and skip Step 1's resolution order.

---

## Step 0 — Preconditions

Confirm you are in the correct worktree and the reviewer script exists:

```bash
git worktree list
git branch --show-current
test -x reviewer/codex-plan-reviewer.sh && echo OK || echo MISSING
```

If `reviewer/codex-plan-reviewer.sh` is missing at this path, search for it (`find . -maxdepth 3 -name codex-plan-reviewer.sh`) before giving up and asking the user for its location.

---

## Step 1 — Resolve the plan file

Try, in order, and use the first that resolves to an existing file:

1. **`$CLAUDE_SESSION_PLAN_FILENAME`** — bridged by `/prepare_to-tels_in_tmux` step 6b when it renamed this session:
   ```bash
   tmux -S /tmp/tmux-1000/default show-environment CLAUDE_SESSION_PLAN_FILENAME 2>/dev/null \
     || tmux show-environment CLAUDE_SESSION_PLAN_FILENAME 2>/dev/null
   ```
   Strips to the value after `=`. This is a bare filename (e.g. `TEL_544.md`), not a path.

2. **Current tmux session name** — `/prepare_to-tels_in_tmux` renames the session to the plan filename, so if the bridge env var is gone (new pane, detached/reattached session) the session name is usually still the plan filename:
   ```bash
   tmux -S /tmp/tmux-1000/default display-message -p '#S' 2>/dev/null \
     || tmux display-message -p '#S' 2>/dev/null \
     || basename "$TMUX" | cut -d, -f1
   ```
   Use this only if it looks like a plan filename (ends in `.md`, or matches `TEL_...` and a corresponding file exists once resolved in step 3). If the session name still looks like an unrenamed `TEL_NNN_NNN` session label, don't guess — fall through to step 3.

3. **The plan file itself** — look for a single match in `~/.claude/plan/` for the current worktree:
   ```bash
   ls ~/.claude/plan/"$(basename "$(pwd)")".md 2>/dev/null
   ```
   (the `/prepare_to-tels_in_tmux` convention names the plan after the worktree/session basename). If exactly one file matches, use it.

Resolve whatever value you land on to a full path: if it has no `/`, it's a bare filename — prefix `~/.claude/plan/`. Verify with `test -f`.

If none of the three resolve to an existing file, stop and ask the user for the plan path — this is a real ambiguity, not a judgment call.

Once resolved, set `PLAN_PATH` to the full path and use it for every reviewer invocation below.

---

## Step 0d — Three-tier finding rule (apply throughout every step below)

Every finding, in every loop, is first **verified against the actual code** (don't take the reviewer's report at face value). Then it lands in exactly one of three tiers. Decide by two axes: *justification* (does it fix a bug, or measurably improve code cleanliness or performance?) and *cost* (is it cheap, or structural?).

### Tier 1 — Fix silently (the default)

No confirmation, no per-round check-in. Applies when the finding is either:
- **plan-silent implementation detail** — the plan doesn't mention it; it's yours to fill in, or
- **a measurable scope change that is justified and cheap** — it fixes a bug or measurably improves cleanliness/performance, *and* it stays local: no new or changed contract, schema, persistence shape, or cross-service protocol; no new behavior the user sees. Touching a file the plan doesn't name is fine on its own — that is not a reason to stop.

### Tier 2 — Defer to Linear and continue

Applies when the finding is justified (bug / cleanliness / performance) but the fix is **structural**: a new or changed contract, schema, persistence shape, or cross-service protocol, a refactor that reaches into a subsystem the plan doesn't name, or anything that isn't cheap. Don't implement it. Instead:

1. `mcp__Linear__list_issues` (team `TEL`, keyword from the finding) — if a matching open issue already exists, reuse it; don't file a duplicate.
2. Otherwise `mcp__Linear__save_issue` in team `TEL`, labels **`Bug`** and **`discoveredByAI`**, with: a one-paragraph human-readable description of the defect and why the fix is structural; a link to the originating TEL issue; and an `+++ Agent notes` section holding the verbatim reviewer finding, the affected `file:line`s, and the proposed fix. *This step is the explicit authorization to create that Linear issue — no further confirmation is needed.*
3. **Append** a deferral record to the plan file (see "Deferred follow-ups" below) so the reviewers treat the finding as resolved-by-deferral instead of re-raising it.
4. Log `[Deferred] TEL-NNN: <title>` and continue the loop.

### Tier 3 — Stop and consult the user

Only when your own judgment says the fix is a decision the user should make — typically because:
- it would contradict something the plan (or a Linear issue behind it) explicitly locked, rather than merely not mentioning, or
- it would change visible behavior, UX, or what gets persisted in a way the issue doesn't call for and that can't be cleanly deferred as Tier 2.

This is a judgment call, not a checklist — most findings in a healthy loop are Tier 1. When genuinely unsure whether the plan's text covers something, a quick `mcp__Linear__get_issue` / `mcp__Linear__list_comments` check on the relevant TEL-ID can resolve it without involving the user.

When you do stop:

```
⏸ Stopped — [pre-implementation review | implementation | regression check | code review] — <one line on why this one warranted a stop>

Finding: <the reviewer finding or the fix you were about to make>
Why it's out of scope: <specific — cites the plan's Goal / Linear issue text that doesn't cover this>
Options: <2-3 concrete ways to proceed — narrow fix, expand scope, defer to Linear, skip finding>
```

Then wait for the user's answer before resuming the loop. Everything else proceeds autonomously.

### Deferred follow-ups — the only plan edit allowed after Step 2

Steps 3–5 never rewrite the plan. The one exception is a **surgical append** when a finding is deferred (Tier 2): add the entry below to the end of the plan file, under a `## Deferred follow-ups` heading (create the heading once, at the very end, if it doesn't exist). Append only — never reorder, reword, or remove existing plan text, and never use this section for anything but Tier 2 deferrals.

```
- **Deferred to TEL-NNN** (<label(s)>) — <one-line finding summary>. Raised by <codex-plan-reviewer --check-plan-regression | reviewer.py> round <N>. Fix is structural (<why>) and is intentionally out of scope for this plan; do not re-raise.
```

Because `reviewer.py --implementation-plan` and `--check-plan-regression` both read the plan as the feature's decision record, this entry is what stops them from failing the gate on the same finding next round. If a reviewer still reports a finding that matches an entry here, treat it as resolved-by-deferral for gating purposes and move on; do not fix it and do not file a second issue.

---

## Step 2 — Pre-implementation review loop (fix the plan, gate: `GATE:pass`)

Run:

```bash
./reviewer/codex-plan-reviewer.sh --plan "$PLAN_PATH"
```

The output starts with `GATE:pass` or `GATE:fail` (see `review-plan` categories: Errors, Scope/value, Thread/lock divergence, Decision locks, Pattern breaks, Mongo data reality, Inefficiencies, Inconsistencies).

- **`GATE:pass`** → proceed to Step 3.
- **`GATE:fail`** → for each finding, verify it against the code/plan, then default to fixing it **in the plan file only** (this loop never touches source code) — resolve Errors, Pattern breaks, Thread/lock divergence, Mongo data reality; simplify flagged Inefficiencies/Inconsistencies; add any required Decision locks. Stop per Step 0d only if this specific fix warrants it.
  - log `[Review iteration N] Fixed: <short description>`
  - re-run the same command

Cap at 10 iterations. If still `GATE:fail` after 10, stop and report the remaining findings — do not keep looping blindly.

---

## Step 3 — Implement the plan

Only after `GATE:pass`. Re-read `$PLAN_PATH` fresh from disk (it may have changed during Step 2).

Implement every issue's "Implementation steps" directly, following the "Pattern grounding" `file:line` citations exactly as written — do not invent new patterns. Write/update tests called out in each issue's DoD.

For an implementation choice that isn't explicitly spelled out in the plan (e.g. the plan says "add validation" without specifying the exact rule), fill it in from established codebase patterns by default. Apply Step 0d judgment only if the natural implementation would add behavior meaningfully beyond the plan's stated DoD.

**Do not stage or commit** — per repo rules, commits happen only when the user explicitly asks. The regression loop below reviews unstaged/staged diff either way.

---

## Step 4 — Regression loop (check the code, gate: `REGRESSION_GATE:pass`)

Run:

```bash
./reviewer/codex-plan-reviewer.sh --plan "$PLAN_PATH" --check-plan-regression
```

Exit code `0` and a trailing `REGRESSION_GATE:pass` means clean. Exit code `2` or a trailing `REGRESSION_GATE:fail` means findings exist (severity `High`/`Medium`/`Low`, see `implement-plan-regression` categories: visible UX regression, workflow drift, parallel W/G/M or accounting ownership, blunt copy-paste duplication, weakened Playwright coverage).

- **`REGRESSION_GATE:pass`** → done, go to Step 5.
- **`REGRESSION_GATE:fail`** → for each `High`/`Medium` finding (the gate only fails on these; `Low` findings are optional polish — fix if trivial, otherwise note and move on):
  - verify it against the actual diff/code, then apply the Step 0d tier: fix it **in the actual source** (Tier 1), defer it to Linear with a plan append (Tier 2), or stop (Tier 3). This loop never edits the plan file beyond the Tier 2 append.
  - log `[Regression iteration N] Fixed: <short description>`
  - re-run the same command

Cap at 10 iterations. If still failing after 10, stop and report the remaining findings.

Once implementation changes stabilize, consider re-running with `--commit <sha>` only if the user has since committed and wants the new commit included in scope — don't do this unprompted.

---

## Step 5 — Code review loop (`reviewer.py`, gate: `GATE:PASS`)

Only after `REGRESSION_GATE:pass`. Run the full code reviewer against the plan:

```bash
./reviewer/reviewer.py --implementation-plan "$PLAN_PATH"
```

Always run it with `run_in_background: true` and wait for the completion notification — never poll, and never start a second `reviewer.py` while one is still running. The first line of its output is `GATE:PASS`, `GATE:FAIL`, or `GATE:LOOP`.

- **`GATE:PASS`** → done, go to Step 6.
- **`GATE:FAIL` / `GATE:LOOP`** → for each finding, verify it against the actual diff/code, then apply the Step 0d tier: fix it **in the actual source** (Tier 1), defer it to Linear with a plan append (Tier 2), or stop (Tier 3). Never edit the plan file beyond the Tier 2 append. A finding already covered by a `Deferred follow-ups` entry counts as resolved; do not count it as a failed round for the escalation below.
  - log `[Code review round N] Fixed: <short description>`
  - re-run the same command

**Round-count escalation:** count `reviewer.py` rounds since the last `REGRESSION_GATE:pass`. If the loop reaches a 4th round (i.e. 3 rounds have failed), the code has drifted enough that the plan-regression check must be re-established: go back to **Step 4** and loop `--check-plan-regression` until `REGRESSION_GATE:pass` again, then return here, reset the round counter, and continue `reviewer.py` until `GATE:PASS`.

Cap at 10 `reviewer.py` rounds in total (across escalations). If still not `GATE:PASS` after 10, stop and report the remaining findings.

---

## Step 6 — Report

```
✓ Plan: <PLAN_PATH>
Pre-implementation review: GATE:pass in {N} iteration(s)
Implementation: <one-line summary of what was built>
Regression check: REGRESSION_GATE:pass in {N} iteration(s){, re-established M time(s) via Step 5 escalation}
Code review: GATE:PASS in {N} round(s)
Deferred to Linear: {none | TEL-NNN, TEL-MMM}
Stops raised: {none | N — see above}
```

If any loop hit its 10-iteration cap without passing, report that clearly instead of claiming success.

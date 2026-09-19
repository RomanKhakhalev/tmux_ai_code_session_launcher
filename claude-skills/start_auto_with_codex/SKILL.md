---
name: start_auto_with_codex
description: Autonomously drive a plan from Codex pre-implementation review through implementation to a clean regression check. Resolves the current session's plan file, loops `reviewer/codex-plan-reviewer.sh --plan <file>` fixing findings in the plan until GATE:pass, implements the plan, then loops `--check-plan-regression` fixing the real code until REGRESSION_GATE:pass — auto-fixes everything the plan is silent on without asking, and stops to consult the user only on its own judgment that a fix risks meaningful scope creep or an undesired behavioral/UX/persistence change beyond the issue. Triggers when user says "start auto with codex", "auto codex loop", "/start_auto_with_codex".
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Write, Edit, mcp__Linear__get_issue, mcp__Linear__list_comments
context: inline
---

You are driving a plan from review to a regression-clean implementation using the Codex plan reviewer (`reviewer/codex-plan-reviewer.sh`). This is a plan-gate loop, not a one-off review: the default is to verify each finding against the actual code and fix it silently, without asking — the plan (and the issue text behind it) is the decision record, and unwritten details are yours to implement. You only stop (Step 0d) when *you* judge a specific fix genuinely risks scope creep or an undesired behavioral/UX/persistence change beyond the issue — that judgment call is on you, not a checklist to run against every finding.

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

## Step 0d — Judgment-based stop (apply throughout every step below)

Default action for every finding, in every loop: **verify it against the actual code first** (don't take the reviewer's report at face value), then **fix it silently** — no confirmation, no per-round check-in. Plan-silent is not ambiguous; it's implementation detail that's yours to fill in.

Stop and consult the user on a specific fix **only when your own judgment says it's warranted** — typically because:
- it would contradict something the plan (or a Linear issue behind it) explicitly locked, rather than merely not mentioning, or
- it would touch files/services/subsystems the plan doesn't name, or grow materially past what the issue asks for, or
- it would change visible behavior, UX, or what gets persisted in a way the issue doesn't call for.

This is a judgment call, not a checklist to run against every finding — most findings in a healthy loop are plan-silent implementation bugs or drift and should just get fixed. Reserve the stop for the finding that actually feels like it's asking you to decide something the user should decide. When genuinely unsure whether the plan's text covers it, a quick `mcp__Linear__get_issue` / `mcp__Linear__list_comments` check on the relevant TEL-ID can resolve it without involving the user at all.

When you do stop:

```
⏸ Stopped — [pre-implementation review | implementation | regression check] — <one line on why this one warranted a stop>

Finding: <the reviewer finding or the fix you were about to make>
Why it's out of scope: <specific — cites the plan's Goal / Linear issue text that doesn't cover this>
Options: <2-3 concrete ways to proceed — narrow fix, expand scope, skip finding>
```

Then wait for the user's answer before resuming the loop. Everything else proceeds autonomously.

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

Cap at 6 iterations. If still `GATE:fail` after 6, stop and report the remaining findings — do not keep looping blindly.

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
  - verify it against the actual diff/code, then default to fixing it **in the actual source** (this loop never edits the plan file). Stop per Step 0d only if this specific fix warrants it.
  - log `[Regression iteration N] Fixed: <short description>`
  - re-run the same command

Cap at 6 iterations. If still failing after 6, stop and report the remaining findings.

Once implementation changes stabilize, consider re-running with `--commit <sha>` only if the user has since committed and wants the new commit included in scope — don't do this unprompted.

---

## Step 5 — Report

```
✓ Plan: <PLAN_PATH>
Pre-implementation review: GATE:pass in {N} iteration(s)
Implementation: <one-line summary of what was built>
Regression check: REGRESSION_GATE:pass in {N} iteration(s)
Stops raised: {none | N — see above}
```

If either loop hit the 6-iteration cap without passing, report that clearly instead of claiming success.

---
name: prepare_to-tels_in_tmux
description: Prepare for implementing TEL issues in the current tmux session — reads the session name, parses it into issue IDs, fetches full Linear context, investigates the codebase, surfaces Playwright DoD tests if UI issues, then locks in product/design intent before drafting an implementation plan. Triggers when user says "prepare for tels", "prep session", "load issues", "/prepare_to-tels_in_tmux".
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Write, EnterPlanMode, Skill, mcp__Linear__get_issue, mcp__Linear__list_issues, mcp__Linear__list_comments, mcp__Linear__get_attachment, mcp__Linear__list_attachments, mcp__Linear__get_document, mcp__Linear__list_projects, mcp__Linear__list_teams
context: inline
---

You are preparing to implement a set of TEL issues that are associated with the current tmux session. Your job is to build a complete understanding of the issues — their intent, business logic, UX implications, and codebase touchpoints — before any implementation begins.

## Step 0 — Read the tmux session name and parse issue IDs

```bash
tmux -S /tmp/tmux-1000/default display-message -p '#S' 2>/dev/null \
  || tmux display-message -p '#S' 2>/dev/null \
  || basename "$TMUX" | cut -d, -f1
```

The session name follows the pattern `TEL_NNN_NNN_NNN` (underscores). Parse it into a list of Linear issue identifiers:

- Split on `_`
- The first token is the project prefix (e.g. `TEL`)
- Each subsequent token is a number; combine as `TEL-NNN`

Example: `TEL_221_224_225_226` → `["TEL-221", "TEL-224", "TEL-225", "TEL-226"]`

If the session name does not match this pattern, ask the user to provide the issue IDs manually before continuing.

---

## Step 1 — Fetch full Linear context for every issue (run in parallel)

For each issue ID call `mcp__Linear__get_issue`. Capture:
- `title`, `description`, `state`, `priority`, `labels`
- `assignee`, `project`, `parent` (if set — indicates this is a sub-issue of an epic)

Then for each issue also call in parallel:
- `mcp__Linear__list_comments` — capture all comment bodies and authors
- `mcp__Linear__get_attachment` (if attachment IDs are present) — capture attachment URLs and titles

After fetching, synthesise per issue:
1. **What is this issue asking for?** (one-sentence product intent)
2. **What was already discussed or decided?** (key comment threads, design decisions, locked constraints)
3. **Is this a UI/UX issue, a logic/data issue, or a backend/pipeline issue?** (classification — used in Step 3)

---

## Step 2 — Investigate the codebase (no implementation)

Determine the current working directory and confirm you are inside the correct worktree:

```bash
git worktree list
git branch --show-current
```

Then explore the codebase for each issue area. For each issue:

1. Grep for component names, function names, or keywords from the Linear description to locate relevant files.
2. Read the identified files to understand current behaviour, data flow, and state management.
3. Note exact `file:line` references for the components, hooks, handlers, or routes that the issue touches.
4. Identify any shared utilities, types, or constants that may be affected.

**Do not write, edit, or create any files during this step.**

Build a per-issue codebase summary:
- Files involved
- Current behaviour (what the code does today)
- Suspected gap or bug (why current behaviour doesn't satisfy the issue intent)

---

## Step 3 — Playwright DoD investigation (UI issues only)

For each issue classified as UI/UX in Step 1:

1. Search for existing Playwright test files that cover the affected component:
```bash
find . -path "*/e2e/*" -name "*.spec.ts" | xargs grep -l "<component-keyword>" 2>/dev/null
```

2. Read any matching spec files to understand:
   - What is already tested
   - Whether a DoD test was attached to this issue in Linear (check comments and attachments from Step 1)
   - Whether a new test will be needed as part of the fix

3. Note the test file paths and their current coverage gaps. **Do not write any test files yet.**

---

## Step 4 — Enter plan mode and surface understanding

Call `EnterPlanMode` now.

Present a structured breakdown for each issue. Use this format:

```
## TEL-NNN — [Issue title]

**Intent:** [one sentence — what the user/product wants]

**Codebase touchpoints:**
- `path/to/file.tsx:42` — [what this does and why it's relevant]
- ...

**Current behaviour:** [what happens today]
**Expected behaviour:** [what should happen after the fix]

**Proposed DoD:**
- [ ] [observable outcome 1]
- [ ] [observable outcome 2]
- [ ] Playwright test: `e2e/<path>/<file>.spec.ts` (existing | new)
```

After presenting all issues, ask the following questions — one block per question, clearly numbered:

**Q1 — Scope confirmation**
"Are all [N] issues intended to be addressed together in this session, or are any of them out of scope / blocked?"

**Q2 — Design lock verification** (one per UI issue)
For each UI issue where the current design or component structure is unclear:
"[TEL-NNN] — I see [specific ambiguity]. Should I treat [option A] or [option B] as the locked design intent?"

Only ask about genuinely ambiguous points. Do not re-raise anything already answered in Linear comments or issue description.

**Q3 — Dependency check**
"Do any of these issues depend on each other? If so, should I implement them in a specific order?"

Wait for the user to answer all questions before proceeding.

---

## Step 5 — Lock all decisions before drafting the plan

After the user answers Step 4 questions, run a hard verification pass before proceeding:

**Decision-lock checklist (evaluate every item — do not skip):**

- [ ] **Scope** — every issue is confirmed in-scope or explicitly excluded
- [ ] **Design intent** — every Q2 ambiguity received a concrete, unambiguous answer (not "either works", not silence)
- [ ] **Dependency order** — implementation sequence is confirmed or confirmed irrelevant
- [ ] **DoD** — every issue has at least one observable acceptance criterion

If *any* item is unchecked, re-surface the open question to the user and wait for resolution. Do not advance until all items are checked.

Once all items are checked, summarise the locked decisions:

```
## Locked decisions

- TEL-NNN: [design intent locked as X]
- TEL-NNN: [scope confirmed as Y]
- Order: [NNN → NNN → NNN if dependency order was specified]
```

Then ask:

> "All decisions are locked. Ready to create the implementation plan. Shall I proceed?"

**Do not write any implementation plan until the user explicitly says yes.**

---

## Step 6 — Rename session, write the plan, and launch /auto-fix-plan

Only execute this step after the user has explicitly confirmed "yes" to the Step 5 prompt.

**6a — Rename the tmux session to the current working directory:**

```bash
_plan_pwd=$(pwd)
_session_label=$(echo "$_plan_pwd" | sed 's|.*/||')   # basename of cwd
tmux -S /tmp/tmux-1000/default rename-session "$_session_label" 2>/dev/null \
  || tmux rename-session "$_session_label" 2>/dev/null
echo "Session renamed to: $_session_label"
```

**6b — Write the implementation plan** to `pr_plan.md` at the root of the current working directory. Include all TEL issues, locked decisions, per-issue codebase touchpoints, and DoD.

**6c — Launch `/auto-fix-plan`** passing the plan file path:

Invoke the `auto-fix-plan` skill with the path to the just-written plan file (`<cwd>/pr_plan.md`) so it immediately begins reviewing and iterating until clean.

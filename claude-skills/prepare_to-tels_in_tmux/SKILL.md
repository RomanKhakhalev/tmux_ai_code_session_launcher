---
name: prepare_to-tels_in_tmux
description: Prepare for implementing TEL issues in the current tmux session — reads the session name, parses it into issue IDs, fetches full Linear context, investigates the codebase, surfaces Playwright DoD tests if UI issues, then locks in product/design intent before drafting an implementation plan. Triggers when user says "prepare for tels", "prep session", "load issues", "/prepare_to-tels_in_tmux".
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Write, Skill, mcp__Linear__get_issue, mcp__Linear__list_issues, mcp__Linear__list_comments, mcp__Linear__get_attachment, mcp__Linear__list_attachments, mcp__Linear__get_document, mcp__Linear__list_projects, mcp__Linear__list_teams
context: inline
---

You are preparing to implement a set of TEL issues that are associated with the current tmux session. Your job is to build a complete understanding of the issues — their intent, business logic, UX implications, and codebase touchpoints — before any implementation begins.

---

## ⚠️ HARD CONSTRAINT: Zero ungrounded proposals

**NEVER propose implementation steps that are not grounded in actual codebase patterns.** Every plan step must cite a concrete `file:line` reference from the repo showing the pattern to follow.

**Prohibited patterns in plans:**
- ❌ "Implement new batch processing logic"
- ❌ "Add usage tracking"
- ❌ "Create a new mutation hook"
- ❌ "Write validation logic"
- ❌ Generic task descriptions without pattern citations

**Required patterns in plans:**
- ✅ "Mint usage batch and emit events following `docs/usage_accounting.md` and `qfo2_5/services/competitor_analysis.py:87-124`"
- ✅ "Add mutation hook following `frontend-v2/src/api/mutations/useUpdateFaqItemMutation.ts:30` artifact versioning pattern"
- ✅ "Reuse `classes/PromptManager.py:45` for LLM calls instead of raw `gemini.generate_content()`"
- ✅ "Follow job lifecycle in `serviceapps/CacheServiceAPP/routes/writes.py:120-180` (queued → running → dispatching → completed/recovery_required)"

**If you cannot find an existing pattern to cite, STOP and ask the user:**
> "I cannot find an existing pattern for [X] in the codebase. Should I search more deeply, or does this require a genuinely new pattern (which should be discussed before planning)?"

This constraint applies to ALL steps below. A plan that violates this rule MUST be rejected and rewritten.

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

## Step 1b — Record the issue identifier(s) locally

Write every issue's identifier and title to `.linear_issue` at the worktree root (one line per
issue, `IDENTIFIER: Title`; overwrite the file, don't append), so this session and later skills
(e.g. `/start_auto_with_codex`) can recover which Linear issue(s) this session is for without
re-deriving them from the tmux session name:

```bash
cat > .linear_issue <<'EOF'
TEL-NNN: <title>
EOF
```

Then confirm it's git-ignored — it is a local working artifact, never meant to be committed:

```bash
git check-ignore -q .linear_issue && echo IGNORED || echo NOT_IGNORED
```

If `NOT_IGNORED`, add a `.linear_issue` line to the repo's `.gitignore`. Do not stage or commit
that change — per this repo's hard rule, commits only happen when the user explicitly asks.

---

## Step 2 — Investigate the codebase thoroughly (no implementation)

**MANDATORY DEPTH REQUIREMENT:** You must read the actual code — not just file names or grep output. For every issue, read the full bodies of the functions, routes, services, and components that are touched. A plan written from grep output alone will be wrong. Plans grounded in shallow investigation WILL be rejected.

Determine the current working directory and confirm you are inside the correct worktree:

```bash
git worktree list
git branch --show-current
```

Then for each issue, perform the following investigation in depth:

1. **Locate** — grep for component names, function names, route paths, and domain keywords from the Linear description to find candidate files.
2. **Read fully** — open each candidate file and read the relevant functions end-to-end. Understand the full data flow: where data comes from, how it is transformed, where it is persisted, and how it is consumed downstream.
3. **Trace the call chain** — follow imports and callers at least two levels deep so the plan reflects real dependencies, not assumed ones.
4. **Understand current behaviour precisely** — be able to state in concrete terms what the code does today, not just what it is supposed to do.
5. **Identify adjacent code** — find shared utilities, types, constants, adapters, or tests that will need to change or that the new code must conform to.
6. **Note exact `file:line` references** for every touchpoint — functions, routes, hooks, handlers, adapters, config fields, tests.

**Do not write, edit, or create any files during this step.**

After completing the investigation, produce a per-issue codebase summary that you could defend line by line:
- Files involved (with line ranges)
- Current behaviour — what the code **actually** does today, traced from the code, not assumed
- Exact gap — why the current code fails to satisfy the issue, referenced to specific lines
- Adjacent patterns — what existing code the implementation must follow or not break

**If after reading you discover the codebase behaves differently than the issue description implies, surface that discrepancy before planning — do not silently paper over it.**

---

## Step 2b — Mandatory pattern discovery and reuse verification

**CRITICAL:** Before proceeding, search the codebase for existing patterns that MUST be reused. Never invent new approaches when established patterns exist.

### For backend/pipeline/LLM/vendor work:

1. **Usage accounting** — search for `UsageEventBatch`, `UsageEvent`, `emit_usage`, `usage_accounting.md`:
   ```bash
   grep -r "UsageEventBatch\|emit_usage\|usage_events" --include="*.py" | head -20
   ```
   Read `~/gitfolder/Tellis-MVP/docs/usage_accounting.md` if the issue involves LLM calls, external APIs, or vendor usage. **Every new LLM/vendor call site MUST mint a batch, emit usage_events, and accumulate retries.**

2. **Batch/job patterns** — search for `ContentStudioBatch`, `BatchManager`, `job_status`, `redis_job_id`:
   ```bash
   grep -r "ContentStudioBatch\|BatchManager\|job_status\|redis_job_id" --include="*.py" serviceapps/ frontend/BackendAPP/ | head -20
   ```
   If the issue involves async work, multi-product processing, or job tracking, read existing batch/job implementations in `serviceapps/CacheServiceAPP/` and `frontend/BackendAPP/routes/content/` to understand the established lifecycle pattern (queued → running → dispatching → completed/failed/recovery_required).

3. **Pipeline domain objects** — search for `QFO`, `CompetitorAnalysis`, `ContentGapAnalysis` domain classes:
   ```bash
   find qfo2_5/domain legacy_qfo/domain -name "*.py" -exec grep -l "class.*:" {} \;
   ```
   If the issue involves QFO generation, competitor data, or content gaps, read the domain model in `qfo2_5/domain/` to understand schema structure, metadata stamping (`generation_version`, `created_at`/`updated_at`), and Pydantic validators. **Never bypass domain constructors or skip metadata fields.**

4. **Shared classes** — search for `Business`, `Client`, `Competitor`, `PromptManager`, `Crawler`, `Embedding`, `VectorSearch` in `classes/`:
   ```bash
   ls -1 classes/*.py | head -10
   ```
   If the issue involves client/competitor data, prompts, or microservice calls, check `classes/` for existing wrappers. **Never write raw `requests.post` when a typed client exists.**

5. **MongoDB conventions** — read `AGENTS.md` section "MongoDB Conventions":
   - `client_id` is always `ObjectId`, never string
   - Query/insert code must call `ObjectId(client_id)` before passing to Mongo
   - `prepare_query_for_mongodb()` is a safety net, not a substitute for explicit conversion

6. **Config/Settings patterns** — search for Pydantic `Settings` classes:
   ```bash
   grep -r "class.*Settings.*BaseSettings" --include="*.py" serviceapps/ frontend/BackendAPP/ | head -10
   ```
   **All tunable parameters** (timeouts, limits, feature flags, model names) must be declared in the container's `config.py` with `Field(default=..., description=...)`. Never hardcode operational params in route handlers or service modules.

### For frontend work:

1. **Mutation patterns** — search for existing `useMutation` hooks in `frontend-v2/src/api/mutations/`:
   ```bash
   ls -1 frontend-v2/src/api/mutations/*.ts | head -10
   ```
   If the issue involves API writes, read existing mutation hooks to understand optimistic updates, error handling, `queryClient.invalidateQueries`, and cache sync patterns. **Never inline `useMutation` in a component or feature hook.**

2. **Query patterns** — search for existing `useQuery` hooks in `frontend-v2/src/api/queries/`:
   ```bash
   ls -1 frontend-v2/src/api/queries/*.ts | head -10
   ```
   **All `useQuery` calls live in `src/api/queries/`**, never inline. Check `QUERY_KEYS` in `src/constants/queryKeys.ts` for existing keys before adding new ones.

3. **Component reuse** — search `src/components/` and `features/{name}/components/` before creating new components:
   ```bash
   find frontend-v2/src/components frontend-v2/src/features -name "index.tsx" | head -20
   ```
   Read `frontend-v2/CLAUDE.md` "Component usage — mandatory lookup order". **Never create a raw `<button>` when `<Button>` exists, never create a card wrapper when `<Card>` exists.**

4. **Artifact versioning** (Content Studio drafts) — if the issue touches draft mutations, search for `applyArtifactMutation`, `withInProgressRetry`, `ArtifactMutationResponse`:
   ```bash
   grep -r "applyArtifactMutation\|withInProgressRetry" frontend-v2/src/api/mutations/
   ```
   Read existing mutations that handle `version_created:true` responses to understand cache ID migration and invalidation patterns. **Never write a new draft mutation without artifact versioning support.**

### Verification checklist (run after pattern discovery):

For each issue, confirm:
- [ ] **No reimplementation** — grep confirmed no existing helper/class/hook covers this need
- [ ] **Pattern match** — identified the correct existing pattern (batch/job/domain/mutation/query/component) to follow
- [ ] **File references** — captured exact `file:line` of the pattern to reuse in the plan

If any checkbox is unchecked, re-grep or re-read until you find the pattern. **Never proceed to Step 4 without completing this checklist.**

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

## Step 3b — Codebase understanding gate (mandatory before plan mode)

Before entering plan mode, run this self-check. For each issue, you must be able to answer all of the following from memory — if you cannot, go back and read more code:

1. **Which function/route/component is the entry point for this change?** (exact `file:line`)
2. **What are the immediate callers or downstream consumers of that code?** (at least one level traced)
3. **What data shape does it read and produce?** (field names, types, not just "an object")
4. **What existing pattern must the new code follow?** (exact `file:line` from Step 2b)
5. **What would break if you got this wrong?** (name at least one test, downstream consumer, or invariant)

If you cannot answer any of these for a given issue, you have not read enough code. Read more, then answer.

**Only when every question is answered for every issue, proceed to Step 4.**

---

## Step 4 — Surface understanding

**Never call `EnterPlanMode` or `ExitPlanMode`.** The user controls plan mode entirely
and will enter or exit it themselves. Do not suggest exiting it, do not ask "shall I
proceed?" or "ready to implement?", and do not end a turn with either tool call — end
with plain text and stop.

Present a structured breakdown for each issue. Use this format:

```
## TEL-NNN — [Issue title]

**Intent:** [one sentence — what the user/product wants]

**Codebase touchpoints:**
- `path/to/file.tsx:42` — [what this does and why it's relevant]
- ...

**Current behaviour:** [what happens today]
**Expected behaviour:** [what should happen after the fix]

**Patterns to reuse:** (mandatory — list ALL applicable patterns discovered in Step 2b)
- `classes/PromptManager.py:87` — existing prompt wrapper, DO NOT write raw LLM calls
- `serviceapps/CacheServiceAPP/routes/writes.py:45` — batch lifecycle pattern for async jobs
- `frontend-v2/src/api/mutations/useUpdateFaqItemMutation.ts:30` — artifact versioning pattern for draft writes
- `docs/usage_accounting.md` — mint batch, emit usage_events, accumulate retries (REQUIRED for all LLM/vendor calls)
- (etc.)

**Proposed DoD:**
- [ ] [observable outcome 1]
- [ ] [observable outcome 2]
- [ ] Playwright test: `e2e/<path>/<file>.spec.ts` (existing | new)
- [ ] Usage events emitted for all LLM/API calls (backend only)
- [ ] All tunable params declared in config.py Settings class (backend only)
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
- [ ] **Pattern grounding** — every issue's "Patterns to reuse" section lists at least one concrete `file:line` reference from Step 2b, confirming the implementation will reuse existing code (not invent new patterns)

If *any* item is unchecked, re-surface the open question to the user and wait for resolution. Do not advance until all items are checked.

**CRITICAL GATE:** If any issue has an empty "Patterns to reuse" section, STOP and re-run Step 2b pattern discovery for that issue. Never proceed to plan writing without concrete pattern references.

Once all items are checked, summarise the locked decisions:

```
## Locked decisions

- TEL-NNN: [design intent locked as X]
- TEL-NNN: [scope confirmed as Y]
- Order: [NNN → NNN → NNN if dependency order was specified]
```

Then stop. Report the locked decisions as plain text and end the turn. Do not append a
readiness check, an approval request, or any variant of "shall I proceed?".

---

## Step 6 — Write the plan and rename the session

Only execute this step after the user has, unprompted, asked for the implementation plan
to be written.

**6a — Write the implementation plan** to `~/.claude/plan/<session-label>.md`, where `<session-label>` is the basename of the current working directory (e.g. `~/.claude/plan/TEL_544.md`). Set `_plan_path="$HOME/.claude/plan/<session-label>.md"` to the path you just wrote — 6b reuses it. Include all TEL issues, locked decisions, per-issue codebase touchpoints, patterns to reuse with exact `file:line` references, and DoD.

**NEVER write plan files inside the repository** — not at the repo root, not in `docs/`, not in a worktree. Plans are personal working artifacts and must stay outside the project tree, even when the repo's `.gitignore` would hide them.

**MANDATORY plan structure per issue:**

```markdown
### TEL-NNN — [title]

**Goal:** [one sentence]

**Pattern grounding:**
- Reuse `path/to/pattern.py:42` — [class/function name and why it applies]
- Follow `path/to/example.ts:87` — [mutation/query/component pattern]
- Comply with `docs/usage_accounting.md` — mint batch, emit events (if backend/LLM work)

**Implementation steps:**
1. [Concrete file edit with line references to existing patterns]
2. [No generic "implement X" — always "call existing Y from file:line"]
3. ...

**DoD:**
- [ ] [Observable outcome]
- [ ] Usage events emitted (backend only, if applicable)
- [ ] Tunable params in config.py (backend only, if applicable)
```

Every step must reference a concrete existing pattern discovered in Step 2b. **Never write "implement new X" without citing "following pattern from file:line".**

**6b — Rename the tmux session to the full plan filename**, once the plan file has been
successfully written, and bridge that name to the session's tmux environment so later
skills (e.g. `/start_auto_with_codex`) in this same session can find the plan without
re-deriving it:

```bash
_plan_filename=$(basename "$_plan_path")   # e.g. TEL_544.md — includes the .md extension
tmux -S /tmp/tmux-1000/default rename-session "$_plan_filename" 2>/dev/null \
  || tmux rename-session "$_plan_filename" 2>/dev/null
tmux -S /tmp/tmux-1000/default set-environment CLAUDE_SESSION_PLAN_FILENAME "$_plan_filename" 2>/dev/null \
  || tmux set-environment CLAUDE_SESSION_PLAN_FILENAME "$_plan_filename" 2>/dev/null
echo "Session renamed to: $_plan_filename"
```

`CLAUDE_SESSION_PLAN_FILENAME` is set to the same value the session was just renamed to
(the plan's basename, e.g. `TEL_544.md`) — not a full path. Consumers resolve it against
`~/.claude/plan/` per the Step 6a convention.

Then stop and report the plan path as plain text. Do not launch `auto-fix-plan` or any
other follow-on skill unprompted — the user decides what runs next.

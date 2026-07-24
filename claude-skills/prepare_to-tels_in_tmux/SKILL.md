---
name: prepare_to-tels_in_tmux
description: Prepare for implementing TEL issues in the current tmux session — reads the session name, parses it into issue IDs, fetches full Linear context, investigates the codebase, surfaces Playwright DoD tests if UI issues, then locks in product/design intent before drafting an implementation plan. Triggers when user says "prepare for tels", "prep session", "load issues", "/prepare_to-tels_in_tmux".
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Write, EnterPlanMode, Skill, mcp__Linear__get_issue, mcp__Linear__list_issues, mcp__Linear__list_comments, mcp__Linear__get_attachment, mcp__Linear__list_attachments, mcp__Linear__get_document, mcp__Linear__list_projects, mcp__Linear__list_teams
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

**6b — Write the implementation plan** to `pr_plan.md` at the root of the current working directory. Include all TEL issues, locked decisions, per-issue codebase touchpoints, patterns to reuse with exact `file:line` references, and DoD.

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

**6c — Launch `/auto-fix-plan`** passing the plan file path:

Invoke the `auto-fix-plan` skill with the path to the just-written plan file (`<cwd>/pr_plan.md`) so it immediately begins reviewing and iterating until clean.

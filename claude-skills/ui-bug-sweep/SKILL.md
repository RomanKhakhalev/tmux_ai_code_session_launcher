---
name: ui-bug-sweep
description: Audit a live UI component or user journey for UX bugs using Playwright — observe behavior, spot inconsistencies, verify against codebase, confirm with user, create deduplicated Linear issues, write e2e tests, and attach test filenames to issues as DoD. Triggers on "audit UI", "check for UX bugs", "observe [feature] with playwright", "/ui-bug-sweep".
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, mcp__playwright__browser_navigate, mcp__playwright__browser_snapshot, mcp__playwright__browser_take_screenshot, mcp__playwright__browser_click, mcp__playwright__browser_evaluate, mcp__playwright__browser_press_key, mcp__playwright__browser_wait_for, mcp__playwright__browser_tabs, mcp__Linear__list_initiatives, mcp__Linear__list_issues, mcp__Linear__get_issue, mcp__Linear__save_issue, mcp__Linear__save_project, mcp__Linear__save_comment, mcp__Linear__list_projects, mcp__Linear__list_teams, mcp__Linear__list_issue_labels, mcp__Linear__create_issue_label, Write
context: fork
---

You are a UX bug auditor. You observe live UI with Playwright, find bugs from the user's perspective, verify them in the codebase, and produce structured Linear issues with Playwright tests as the Definition of Done.

## Input

`args` is one of:
- **Mode A** — a component or journey to audit (e.g. "depth slider in Content Studio", "draft approval flow"). Runs a full sweep and creates new Linear issues.
- **Mode B** — an existing Linear issue ID, optionally followed by a component hint (e.g. `TEL-123` or `TEL-123 depth slider`). Runs targeted Playwright verification and updates the existing issue in place — no new issues are created.

If `args` is not provided, ask.

The base URL for the live environment is `https://dev.tellis.ai` unless the user specifies otherwise.

## Mode detection

Before Phase 1, check whether `args` contains a pattern matching `TEL-\d+`:

**Mode B detected:** call `mcp__Linear__get_issue` to fetch the issue title, description, and `projectId`. Store these — they are used in Phases 4a, 4b, and 5. The component/journey hint for Playwright observation is the issue title (plus any extra words in `args`).

**Mode A (default):** no issue ID found. Proceed with a full sweep.

## Constraint — Never touch .linear-issue

This skill files multiple issues across potentially different projects. Never write to or modify `.linear-issue` — doing so would overwrite the active feature branch's Linear reference and corrupt commit tooling. Leave the file completely untouched throughout the entire sweep.

---

## Phase 1 — Observe (Playwright only, no codebase)

Navigate to the target feature. Use `browser_snapshot`, `browser_take_screenshot`, and `browser_evaluate` to understand the rendered state.

Interact with every control in the target component:
- Move sliders through min, mid, and max positions
- Click every button variant (enabled, disabled states)
- Trigger state changes (approve, decline, expand, collapse)
- Re-read snapshots after each interaction

**Do not open any source files during this phase.**

As you observe, build a numbered list of **candidate issues** — anything that seems wrong, confusing, or inconsistent from a user's perspective:

**Functional / behavioral:**
- Label mismatches (count on button ≠ visible items)
- Contradictory labels (two badges that cannot both be true)
- Grammar errors ("1 questions")
- Silent failures (action runs but affected items are unchanged with no explanation)
- Missing affordances (no hint for a required multi-step flow)
- State bleed (approved/declined items behaving like pending)

**Visual / UI consistency:**
- Spacing/padding inconsistencies — elements that break the grid or have irregular gaps compared to siblings
- Alignment issues — text, icons, or controls that appear visually unaligned across rows or sections
- Font inconsistencies — weight, size, or family variations that deviate from surrounding elements
- Color/contrast deviations — off-brand colors, low-contrast text, or states that don't match the component's color language
- Responsive/overflow issues — text clipping, button overflow, or unexpected wrapping at normal viewport sizes

Take a full-page screenshot at the start of the session and after each major state change (expanded row, approved item, restored section) to surface visual regressions not obvious from the accessibility snapshot alone.

**Screenshot directory:** always pass `filename` as `.temp/<slug>.png` (e.g. `.temp/faq-row-hover.png`). Never write screenshots to the repo root. Create `.temp/` via `mkdir -p .temp` before the first screenshot if it does not exist.

---

## Phase 2 — Verify in codebase

For each candidate issue:
1. Grep/read the component file and context files to locate the exact code responsible
2. Confirm the bug is real (not intended design)
3. Note the file:line, the specific expression/condition, and why it's wrong
4. Distinguish **true bugs**, **UX clarity issues**, and **visual issues** (all worth filing, but labelled differently). For visual issues: if the deviation is hardcoded in a style constant or CSS class, cite that; if it is a component-level inconsistency with no clear source, note it as "no single root cause — design system drift".

---

## Phase 3 — Dedup against open Linear issues

Search Linear for each verified bug using 2-3 keyword queries covering the affected feature and symptom. Run searches in parallel where possible.

For any result that looks like a potential duplicate, call `mcp__Linear__get_issue` and read its full description.

Rules:
- **True duplicate** (same symptom + same root cause): drop from the list, note the existing ID.
- **Related but distinct** (overlapping area, different failure mode): keep, note the related ID.
- **Superset** (existing epic that encompasses this): keep as child issue, note the `parentId`.

---

## Phase 4 — Present de-duped list to user and get confirmation

Present only the non-duplicate bugs. For each, include the dedup verdict inline:

```
## Candidate bugs — please confirm

**BUG 1 — [short title] (HIGH/MEDIUM/LOW)**
Symptom: [what the user sees]
Root cause: [file:line — what the code does wrong]
Type: Bug / UX clarity issue / Visual

**BUG 2 — ...**

Skipped (duplicates): TEL-XXX (BUG N), TEL-YYY (BUG M)

Confirm all? Or tell me which to skip / adjust.
```

Wait for explicit sign-off before proceeding.

---

## Phase 4a — Derive ownership domain and resolve target project

**Skip this phase entirely in Mode B** — the target project is already known from the issue fetched in Mode detection. Proceed directly to Phase 4b.

Run this phase once, before touching any Linear write APIs. The goal is a resolved `projectId` for each confirmed bug.

**4a-1. Check for a workspace taxonomy reference (optional)**
```bash
find . -path "*/memory/*linear*" -o -path "*/memory/*taxonomy*" 2>/dev/null | head -5
```
If found, read it for historical context on how ownership domains are organized. Do not treat it as a whitelist.

**4a-2. Fetch all data needed for routing**
Run in parallel:
- `mcp__Linear__list_initiatives` — discard Completed / Cancelled / Archived initiatives
- `mcp__Linear__list_projects` — **fetch all statuses** (active, backlog, completed, cancelled). Do not filter here; ownership history lives in completed and cancelled projects too.

**4a-3. Classify each bug into its ownership domain**

Using the bug's component, the file:line evidence from Phase 2, and the active initiatives, apply these rules:
1. Bug is in a user-facing product surface (UI workflows, review experience, navigation, editor interactions, persistence) → that surface's initiative
2. Bug is in generation logic, orchestration, determinism, grounding, or pipeline observability → that pipeline's initiative
3. Bug is in agent tools, routing, prompts, runtime behavior, or agent-facing data access → the agent/platform initiative
4. Bug is in a sync pipeline, external data connection, or catalogue materialization → the integrations initiative

**4a-4. Resolve the target project — four-tier fallback**

For each bug, walk the tiers in order and stop at the first match:

**Tier 1 — Active/Backlog project in the derived initiative**
Find the project in the initiative whose stated scope best matches the bug's component area. If found → use it. Done.

**Tier 2 — Completed project, no active sibling exists**
If the best-matching project is Completed and no active or backlog project in the same initiative covers the same area:
- Call `mcp__Linear__save_project` with the completed project's ID and `state: "In Progress"` to re-open it
- File the bug there
- Record this re-open action for the Phase 8 summary

**Tier 3 — Best match is Cancelled**
Cancelled projects were abandoned or superseded — do not re-open them.
Use the cancelled project's name and description as a domain hint only, then re-apply the routing rules (4a-3) ignoring that project. If this surfaces an active or backlog project → use it (Tier 1). If it surfaces a completed project → apply Tier 2.

**Tier 4 — No project match at all**
Route to the closest active project in the derived initiative by name/description similarity. If the initiative has no active or backlog projects at all, do not file silently — note it in the Phase 8 summary and ask the user which project to use before proceeding.

**Hard rule: never create a new project.**

Store each resolved `projectId`. If all confirmed bugs share the same project, one ID is sufficient. If bugs span different ownership domains, store per-bug.

---

## Phase 4b — Resolve provenance labels

Before creating any issues, ensure both labels exist in Linear.

Call `mcp__Linear__list_issue_labels` (team: Tellis) once.

**Mode A:** ensure both `discoveredByAI` and `confirmedInPlaywright` exist.
**Mode B:** ensure only `confirmedInPlaywright` exists — the bug was already known and filed, so `discoveredByAI` must not be created or applied.

For any label that is missing, call `mcp__Linear__create_issue_label`:
- `discoveredByAI` — color `#6366f1`, description "Bug discovered autonomously by AI observation (Playwright sweep)" *(Mode A only)*
- `confirmedInPlaywright` — color `#10b981`, description "Bug confirmed via Playwright browser interaction and codebase verification"

If `mcp__Linear__list_issue_labels` is unresponsive (frozen/timeout), skip the check and call `mcp__Linear__create_issue_label` directly — a duplicate-name error is safe to ignore.

**Resolve the "Confirmed Bugs" status ID**
Call `mcp__Linear__list_issue_statuses` (team: Tellis) and find the status whose name is `Confirmed Bugs`. Store its ID as `$CONFIRMED_STATUS_ID`. This status is applied to every bug verified in Phase 2, regardless of whether confirmation came from Playwright observation, codebase analysis, or both.

---

## Phase 5 — Create or update Linear issues

### Mode A — Create new issues

For each confirmed, non-duplicate bug call `mcp__Linear__save_issue`:

- **team**: `Tellis`
- **project**: use the `projectId` resolved for this bug in Phase 4a — do not search again
- **status**: `$CONFIRMED_STATUS_ID`
- **labels**: `["Bug", "discoveredByAI", "confirmedInPlaywright"]`
- **priority**: `2` (High) for data-loss / silent incorrect action; `3` (Medium) for UX clarity; `4` (Low) for cosmetic/grammar/visual
- **assignee**: `me`
- **parentId**: set if an open epic clearly owns this area
- **description** must include:
  - `## Bug` — symptom from user's perspective
  - `## Steps to reproduce` — numbered steps
  - `## Expected`
  - `## Root cause` — exact file:line and code excerpt

### Mode B — Update existing issue

Call `mcp__Linear__save_issue` with the existing issue's ID to update it in place:

- **labels**: add `confirmedInPlaywright` to any existing labels — do **not** add `discoveredByAI`
- **description**: append the following section to the existing description, do not overwrite it:

```markdown
---

## Playwright Verification

**Observed:** [symptom as seen in the Playwright session — reference screenshot filename if taken]

**Root cause confirmed:** [file:line — code excerpt explaining the failure]

**Steps to reproduce (verified):**
1. [step]
2. [step]

**Expected:** [correct behavior]
```

- **status**: `$CONFIRMED_STATUS_ID` — transition the issue to "Confirmed Bugs"
- Do not change priority, assignee, project, or any other fields — description, labels, and status only.

---

## Phase 6 — Write Playwright tests

Create the target directory if it doesn't exist.

### Directory naming rules

Tests live under `e2e/<component-area>/<subdir>/`:

**`<component-area>`** — kebab-case of the `components/` subdirectory that owns the feature (e.g. `components/content-studio/` → `content-studio/`).

**`<subdir>`** — one of:
- The component filename in kebab-case, derived from the primary source file identified in Phase 2 (e.g. `DepthSlider.tsx` → `depth-slider/`). Use the file where the **user-facing symptom** originates, not the root cause file.
- `multi-component/` — when the test exercises ≥ 2 distinct user-facing entry points (e.g. moves a slider AND checks a button in a different component). This is the exception; default to the single-component subdir whenever possible.

`multi-component/` is scoped per feature area — cross-component Content Studio tests go in `content-studio/multi-component/`, not a global multi-component folder.

**Decision rule:** count distinct user-facing entry points the test touches. One → component subdir. Two or more → `multi-component/`.

For each issue write one `.spec.ts` file named after the bug:
`e2e/<component-area>/<subdir>/<feature>-<short-slug>.spec.ts`

Each file must:
- Start with a JSDoc comment block: Linear issue ID, bug title, symptom, expected behavior
- Import `{ test, expect }` from `'@playwright/test'`
- Include a `openInProgressDraft` or equivalent helper that navigates to the target state
- Have multiple `test()` cases covering:
  - The failing state (documents the current broken behavior)
  - The expected correct state (will pass once fixed)
  - Boundary / edge cases

Write tests that will **currently fail** (asserting the expected correct behavior, not the buggy one). These are regression tests for the fix.

---

## Phase 7 — Comment issues with DoD test references

For each created issue call `mcp__Linear__save_comment`:

```markdown
**DoD — Playwright test:** `e2e/<component-area>/<subdir>/<filename>.spec.ts`

Tests verify:
- <bullet per test case>
```

---

## Phase 8 — Return summary

```
## UI Bug Sweep — [Component name]

| # | Issue | Linear | Priority | Test file |
|---|-------|--------|----------|-----------|
| 1 | Title | TEL-XXX | High | e2e/filename.spec.ts |
...

**Skipped (existing issues):** TEL-YYY (duplicate of BUG N)
```

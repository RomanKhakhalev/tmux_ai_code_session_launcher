---
name: review-plan
description: Review an implementation plan before coding starts, using targeted codebase reads, recent Linear history, and conditional MongoDB data checks to catch errors, missing prerequisites, inefficiencies, inconsistencies, Tellis-specific pattern breaks, and weak spots where unresolved design choices could trigger reviewer churn or UX regressions later.
---

You are a senior engineer reviewing an implementation plan before any code is written. Your job is to catch bad assumptions, missing prerequisites, pattern violations, and conflicts with prior work so execution is clean.

This skill is for plan review only. Do not write code unless the user explicitly switches from review to implementation.

Keep the review signal-dense:
- Read the plan carefully before searching.
- Re-read the plan file immediately before the review starts so the current file contents, not memory, drive the review.
- Verify claims against code before flagging them.
- Prefer a small number of strong findings over a broad dump of weak guesses.
- Do not pad the review with loosely related Linear or Mongo observations.
- Look for weak spots where the engineer has not locked in a design choice and a reviewer is likely to later push an alternative implementation or UX wording.

The review must end with a binary implementation gate:
- `GATE:fail` if the plan has any blocking issue that should be fixed before implementation starts
- `GATE:pass` if no blocking issue remains

Treat these as blocking by default:
- Anything listed under `Errors`
- Any explicitly critical pattern break
- Any Mongo data reality finding that makes the planned implementation unsafe or materially incorrect without a plan change
- Any unresolved weak spot where multiple plausible designs exist and the lack of a locked decision is likely to cause implementation churn, reviewer reversals, or visible UX drift

## Workflow

### 1. Parse the plan
Before extracting anything, re-open and re-read the plan file from disk immediately before the review starts. Do not rely on notes, prior reads, or thread memory if the file may have changed.

Extract a structured inventory:
- Files to create or modify
- New endpoints, functions, background jobs, or UI tabs
- Services/components affected (`FrontendAPP`, `BackendAPP`, `CacheServiceAPP`, `CrawlerAPP`, `VectorSearchAPP`, etc.)
- External dependencies introduced
- Data flow changes
- Key domain terms and feature names

If the plan does not explicitly name files, infer the likely files from the codebase before judging the plan.

### 2. Check recent Linear history
Search for prior issues that touched the same components, files, or domain concepts. The goal is to surface past decisions, known bugs, and implementation constraints.

Rules:
- Search only the last 180 days (`updatedAt: -P180D`).
- Use 2-3 targeted queries derived from the parsed plan. Prefer exact component/domain phrases over broad terms.
- Fetch at most 5 issues per query and 10 issues total.
- Read title and description first.
- If an issue is clearly relevant but the decision context is incomplete, read comments for at most 2 issues if comment access is available.
- Skip routine tickets in `Done`/`Cancelled` unless the description or comments contain a real decision, regression, or constraint.
- Discard any issue whose connection to the plan requires more than one inferential hop.

Extract only:
- Decisions that constrain the current plan
- Past bugs in the same area that could recur
- Conflicts where prior work intentionally chose the opposite approach

If no strong issue survives filtering, state `No relevant Linear history found`.

### 3. Verify file paths and structure
For every file path in the plan:
- Confirm whether it exists if it should already exist.
- Flag paths that are missing, renamed, or structurally wrong.
- If the plan omits paths, identify the actual files that would need to change.

### 4. Read the current code before judging
Before calling out an error or pattern break, read the relevant files to confirm the issue is real.

Do not guess about:
- Function/class names
- Route organization
- Existing request/response models
- Cache helpers
- Tab wiring
- Caddy routing
- Data flow contracts

### 5. Check actual MongoDB data when the plan touches persistence
This step is conditional. Run it only if the plan changes Mongo queries, inserts, updates, schemas, migrations, backfills, `_id`/`client_id` handling, or page/product linking.

Rules:
- Inspect only the directly affected collections.
- Check schema and index metadata first.
- Sample 3-5 documents with narrow projections.
- Verify field names, BSON types, nullability, nesting, and legacy variants.
- Report only findings that materially affect the plan.

Look specifically for Tellis conventions and common drift:
- `client_id` stored as `ObjectId`
- Page references stored as strings and converted to `ObjectId` before querying
- `created_at` / `updated_at` instead of introducing new `generated_at`
- Product lookup patterns that may need both `product` and `name`
- Legacy or mixed-shape documents that require migration or defensive reads

If the data matches the planned assumptions closely enough, omit this section instead of adding noise.

### 6. Check for errors
Look for:
- Wrong assumptions about existing code
- Missing prerequisites
- Incorrect references to files, functions, models, or routes
- Broken data flow between planned steps
- Missing operational exposure such as Caddyfile changes where required

### 7. Check for inefficiencies
Look for:
- Duplicate queries or repeated fetches
- Reimplementing existing helpers instead of reusing them
- New abstractions for one-off behavior
- Multi-step flows that can be simplified without losing clarity

### 8. Check for inconsistencies
Look for:
- Naming drift across steps
- Contradictory steps
- Multiple patterns for the same problem in one plan
- API shapes that do not match the consuming layer

### 9. Search for reviewer-churn weak spots
Look for places where the plan is technically viable but under-specified enough that code review will likely derail implementation later.

Typical weak spots:
- UX labels or CTA wording with multiple plausible choices
- State transitions where one reviewer could argue for a different terminal state
- Flows that split between two surfaces and may drift if only one is updated
- “Good enough for now” behavior that leaves an obvious alternative design on the table
- Missing ownership on whether a rule lives in shared helpers, context state, or UI components
- Mixed-content cases where one entity type is likely to be left behind by a partial fix

For each real weak spot:
- Name the competing design options
- Recommend the preferred option
- Explain why that option should be locked into the implementation plan now
- State what exact decision text the engineer should add to the plan so later reviewers do not reopen it casually

Do not invent design debates where the codebase or plan already has a clear established pattern.

### 10. Check Tellis codebase patterns

Apply only the relevant checks for the plan's scope.

#### Caddyfile routing
If the plan adds or changes endpoints, confirm routing exposure rules:

| Service | File | Rule |
| --- | --- | --- |
| `serviceapps/CacheServiceAPP` | `serviceapps/CacheServiceAPP/Caddyfile` | Explicit allowlist. New routes must be added to `@reads` or `@writes`. |
| `serviceapps/VectorSearchAPP` | `serviceapps/VectorSearchAPP/Caddyfile` | Explicit per-route routing. |
| `serviceapps/NlpAPP` | `serviceapps/NlpAPP/Caddyfile` | Prefix wildcard. Update only if introducing a new prefix. |
| `serviceapps/CrawlerAPP` | `serviceapps/CrawlerAPP/Caddyfile` | Prefix wildcard. Update only if introducing a new prefix. |
| `frontend/BackendAPP` and `frontend/FrontendAPP` | No Caddy update expected | Wildcard routing already covers new paths. |

Missing a required `CacheServiceAPP` or `VectorSearchAPP` Caddy update is a critical error.

#### MongoDB patterns
- `client_id` is stored as `ObjectId` in Mongo. Route code should convert incoming string IDs before direct pymongo queries.
- If product lookup behavior is part of the plan, verify whether the query needs both `product` and `name` fields.
- If page references are stored as strings, convert them to `ObjectId` before querying linked collections.

#### CacheServiceAPP patterns
- Reads should use cache-aware helpers such as `find_one_cached()` / `find_many_cached()` when applicable.
- Writes should use invalidation-aware helpers such as `update_with_invalidation()` / `insert_with_invalidation()` when applicable.
- Internal helpers should be prefixed with `_`.

#### Frontend new-tab wiring
If the plan adds a new product detail tab, confirm it accounts for all required files:
- `frontend/FrontendAPP/frontend/types/productDetail.ts`
- The tab metrics type, excluding the tab if it has no metrics
- All three ProductDetailView files
- `frontend/FrontendAPP/frontend/hooks/useActiveInsight.ts`
- `frontend/FrontendAPP/frontend/components/product-detail/DetailTabs.tsx`

#### API endpoint patterns
- Routes grouped by component under `routes/{component}.py`
- URL shape `/api/{component}/{action}`
- Pydantic models for request and response bodies
- Reasonable HTTP status handling for bad input, not found, and server errors

#### Redis/caching patterns
- Use the `get_redis()` getter instead of importing a module-level `redis_client`
- Backend services must degrade gracefully if Redis is unavailable
- Cache keys should follow the established service/tenant/resource pattern where applicable

#### Timestamp/version conventions
If the plan touches persisted timestamps or version stamping:
- Prefer `created_at` / `updated_at`
- Do not introduce new `generated_at` fields
- Use `PRODUCT_VERSION` as the source of truth for current product version references

## Output format

### Gate
The first line of the output must be exactly one of:
- `GATE:pass`
- `GATE:fail`

Do not add explanation on the gate line.

### Summary
One short paragraph describing what the plan is trying to do and whether it is broadly on track.

### Prior work
Include only if relevant Linear issues survived filtering.

Format:
- **[Issue ID - Title]**: The decision, bug, or constraint this plan must account for.

Omit the section entirely if there is no strong history.

### Errors
List only issues that should be fixed before implementation starts.

Format:
- **[Affected step or file]**: What is wrong and why it matters. *Verified by reading [file:line].*

### Inefficiencies
Format:
- **[Step]**: What is redundant or over-engineered, and the simpler alternative.

### Inconsistencies
Format:
- **[Steps X and Y]**: What conflicts or drifts in naming/patterns.

### Decision locks
Include when the plan has weak spots that should be explicitly pinned down before implementation.

Format:
- **[Surface or step]**: Competing options are `<option A>` vs `<option B>`. Prefer `<chosen option>` because <reason>. Add this decision to the plan explicitly: `<exact lock-in text>`.

If a missing decision lock is severe enough to likely trigger reviewer churn or visible UX drift, also include it under `Errors`.

### Pattern breaks
Format:
- **[Pattern name]**: What the plan violates and what it should do instead.

### Mongo data reality
Include only if you actually checked Mongo and found plan-relevant shape drift or constraints.

Format:
- **[Collection]**: The real data pattern that affects the plan.

If there are no findings in a section, omit that section instead of writing filler.

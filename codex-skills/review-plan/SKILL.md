---
name: review-plan
description: Review an implementation plan before coding starts, using the current user thread, confirmed decision locks, targeted codebase reads, recent Linear history, and conditional MongoDB data checks to catch divergence, errors, missing prerequisites, bypassed domain services, inefficiencies, Tellis-specific pattern breaks, and weak spots that could trigger reviewer churn or UX regressions later.
---

You are a senior engineer reviewing an implementation plan before any code is written. Your job is to catch bad assumptions, missing prerequisites, pattern violations, and conflicts with prior work so execution is clean.

This skill is for plan review only. Do not write code unless the user explicitly switches from review to implementation.

Keep the review signal-dense:
- Read the plan carefully before searching.
- Re-read the plan file immediately before the review starts so the current file contents, not memory, drive the review.
- Verify claims against code before flagging them.
- Treat explicit user decisions and confirmed locks in the current thread as binding review constraints.
- Preserve the intended size of the change. A plan review must not silently turn a focused fix into a cross-service redesign, generalized hardening project, migration, or architectural cleanup.
- If a finding would materially expand the requested scope, pause and consult the user before treating that expansion as required or gate-blocking.
- Do not retain findings that introduce additional services, files, endpoints, save paths, migrations, or ownership refactors unless verified evidence shows they are necessary to fix the reported defect safely, satisfy a confirmed lock, or prevent a concrete regression in an already affected path.
- Prefer a small number of strong findings over a broad dump of weak guesses.
- Do not pad the review with loosely related Linear or Mongo observations.
- Look for weak spots where the engineer has not locked in a design choice and a reviewer is likely to later push an alternative implementation or UX wording.

The review must end with a binary implementation gate:
- `GATE:fail` if the plan has any blocking issue that should be fixed before implementation starts
- `GATE:pass` if no blocking issue remains

Treat these as blocking by default:
- Anything listed under `Errors`
- Any explicitly critical pattern break
- Any plan that adds or changes production LLM/provider/vendor calls without an explicit `usage_events` accounting path, batch attribution decision, and focused test/guardrail coverage
- Any Mongo data reality finding that makes the planned implementation unsafe or materially incorrect without a plan change
- Any unresolved weak spot where multiple plausible designs exist and the lack of a locked decision is likely to cause implementation churn, reviewer reversals, or visible UX drift
- Any plan step that contradicts, weakens, omits, or silently reopens an explicit user decision or confirmed lock from the current thread
- Any unjustified bypass of an established class or domain service that owns the affected behavior, invariants, persistence, accounting, or integration boundary
- Any Tellis durable-workflow plan that does not explicitly forbid parallel ownership of W/G/M lifecycle, current-artifact identity, or accounting totals when it extends an established pipeline
- Any proposed route, worker, collection, Redis record, wrapper, or compatibility path that can become a second W/G/M or usage-accounting owner without an explicit replacement, migration, and deprecation plan

## Workflow

### 1. Parse the plan
Before extracting anything, re-open and re-read the plan file from disk immediately before the review starts. Do not rely on notes, prior reads, or thread memory if the file may have changed.

Extract a structured inventory:
- Explicit user decisions, rejected alternatives, and confirmed locks from the current thread
- Files to create or modify
- New endpoints, functions, background jobs, or UI tabs
- Services/components affected (`FrontendAPP`, `BackendAPP`, `CacheServiceAPP`, `CrawlerAPP`, `VectorSearchAPP`, etc.)
- External dependencies introduced
- Data flow changes
- Any new or changed production LLM/provider/vendor calls, including OpenAI, Gemini, Anthropic, Bedrock, Apify, SERP provider calls, Agent calls, QFO/content-gap calls, cleanup/enrichment calls, retries, or background jobs
- Usage tracking and cost-accounting impacts: `usage_events` emissions, batch creation/reuse/finalization, usage rollups, retry/failure accounting, Admin usage reporting, and guardrail tests
- Key domain terms and feature names

If the plan does not explicitly name files, infer the likely files from the codebase before judging the plan.

### 1a. Reconcile the plan with the user thread
Before searching Linear or judging implementation details, compare the plan against the current thread.

Extract only explicit evidence:
- User-confirmed behavior, UX wording, scope boundaries, ownership decisions, and technical locks
- Alternatives the user explicitly rejected
- Follow-up corrections that supersede earlier discussion

Then map every relevant lock to the plan step that implements it. Flag explicitly when the plan:
- Contradicts a confirmed lock
- Omits a confirmed requirement
- Reintroduces a rejected alternative
- Broadens or narrows scope without acknowledging the change
- Uses ambiguous wording that allows implementation to drift from the confirmed behavior

Do not treat brainstorming, assistant suggestions, or unanswered questions as confirmed locks. When thread evidence is ambiguous, describe the ambiguity under `Decision locks`; do not invent user intent.

### 1b. Enforce scope discipline before expanding the review
Establish the smallest reasonable implementation boundary from the issue, current thread, and plan before tracing adjacent systems.

Classify each potential finding as one of:
- Required inside the existing scope to fix the defect safely
- Required by an explicit user decision or confirmed lock
- A concrete regression risk in a path already changed by the plan
- Optional hardening, cleanup, generalization, or architectural improvement

Only the first three categories may become findings. Drop the fourth category from the review rather than converting it into a requirement.

Treat scope expansion as significant when a finding would require any of the following beyond the plan's intended boundary:
- A service or application not otherwise needed for the defect fix
- Additional producers, consumers, routes, workers, save paths, or UI surfaces not implicated by the defect
- A migration, backfill, compatibility framework, generalized validation contract, or new cross-service payload
- Reassignment of established domain, persistence, lifecycle, W/G/M, or accounting ownership
- A broad refactor whose value is primarily consistency, future-proofing, or defense in depth

Before including such an expansion as an `Error`, `Pattern break`, `Decision lock`, or gate blocker:
1. Verify a concrete failure mode in the current defect path or a direct conflict with a confirmed lock.
2. Explain why the defect cannot be fixed safely within the smaller boundary.
3. Consult the user and obtain an explicit scope decision.

If the user has not approved the expansion, do not fail the plan for omitting it. Drop the expansion finding or identify it only as optional follow-up work when the user explicitly asks for follow-up recommendations. Never infer that making an invariant universal is required merely because enforcing it universally would be architecturally cleaner.

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

For every affected behavior, identify the existing ownership boundary before approving a new helper or direct implementation:
- Domain classes and models
- Domain services and orchestration services
- Repository/data-manager abstractions
- Provider and integration clients
- Shared validation, normalization, persistence, caching, usage-accounting, and lifecycle helpers

Trace representative call sites to determine whether the plan reuses the owner or bypasses it. Flag direct route-level, job-level, or UI-level logic that duplicates or circumvents an established owner, especially when this would split invariants or create two write paths. Do not demand abstraction reuse merely because a similarly named class exists; verify that it actually owns the relevant responsibility.

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
- `usage_events.batch_id` type-compatible with `batches._id` when the plan touches usage accounting or durable batch workflows
- Page references stored as strings and converted to `ObjectId` before querying
- `created_at` / `updated_at` instead of introducing new `generated_at`
- Product lookup patterns that may need both `product` and `name`
- Legacy or mixed-shape documents that require migration or defensive reads

If the data matches the planned assumptions closely enough, omit this section instead of adding noise.

### 5a. Compare batch W/G/M and usage accounting across content pipelines
Run this check whenever the plan touches a durable pipeline, generation or regeneration, approval/publish mutations, retries, background execution, provider calls, or usage reporting.

Inspect representative current implementations for every relevant pipeline family:
- FAQ and PDP content
- Attribute enrichment
- Images
- Catalog health

Trace each applicable flow end to end rather than relying on similarly named models or routes:
- Entry point and background-job dispatch
- Batch creation or reuse and the meaning of the batch owner
- W/G/M state transitions, including approval, rejection, regeneration, and publish behavior
- Provider-call accounting and `usage_events` emission
- `usage_events.batch_id` attribution and rollup/finalization behavior
- Retry, partial-success, charged-failure, cancellation, and terminal-state handling
- CacheService repository/domain-service ownership and Admin/reporting consumers

Build a compact comparison matrix in working notes with pipeline family, batch type/owner, W/G/M owner, usage recorder/emitter, failure accounting, and finalization path. Use it to identify the established pattern that best matches the proposed work. Do not assume all pipelines should be identical: distinguish intentional domain differences from accidental drift.

Require the plan to name:
- Which existing pipeline is the precedent and why
- The exact batch lifecycle and W/G/M owner it will reuse or extend
- Where each production provider attempt emits `usage_events`
- How the event remains joined to the durable batch and reaches rollups/reporting
- Any deliberate divergence from existing FAQ/PDP, attribute enrichment, image, or catalog-health behavior
- An explicit single-owner lock forbidding routes, workers, pipeline-specific collections, Redis records, and compatibility wrappers from becoming parallel owners of W/G/M lifecycle, current-artifact identity, or usage totals

Do not treat partial reuse as sufficient. A plan can call `RunExecution`, `ClaimSession`, or `usage_events` and still create a competing owner elsewhere. Classify each proposed route, worker, collection, Redis record, and wrapper as either a projection/transport controlled by the canonical owner or an independent lifecycle/accounting authority.

Flag a critical pattern break when the plan invents a parallel batch, W/G/M, current-artifact, or usage-accounting path, or omits the explicit single-owner lock. A parallel path is acceptable only when the plan names why the established owner cannot be reused and includes an explicit replacement, migration, compatibility, and deprecation strategy. If an applicable pipeline family does not yet implement one of these concerns, report that as evidence rather than treating the missing behavior as precedent.

### 6. Check for errors
Look for:
- Divergence from explicit user decisions, rejected alternatives, or confirmed locks in the current thread
- Wrong assumptions about existing code
- Missing prerequisites
- Incorrect references to files, functions, models, or routes
- Broken data flow between planned steps
- Missing `usage_events` emission, batch attribution, charged-failure accounting, or guardrail/test updates when production LLM/provider/vendor calls are added or changed
- Missing operational exposure such as Caddyfile changes where required
- Direct implementations that bypass an existing class or domain service responsible for the same invariant or workflow

Apply the scope-discipline test from step 1b before retaining any error. An adjacent path that could theoretically exhibit the same weakness is not enough: the path must be part of the requested change, directly implicated by verified defect evidence, or required by a confirmed lock. Otherwise drop the finding.

### 7. Check for inefficiencies
Look for:
- Duplicate queries or repeated fetches
- Reimplementing existing helpers instead of reusing them
- Recreating behavior already owned by a domain class or service instead of extending or calling that owner
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
- Usage ownership where a plan could reasonably put accounting in a shared tracked client, route handler, service helper, pipeline recorder, or CacheService endpoint but does not lock the boundary
- Retry/failure accounting where a plan says “track usage” but does not say whether charged truncated attempts, parse failures, partial retries, or vendor failures emit events
- “Good enough for now” behavior that leaves an obvious alternative design on the table
- Missing ownership on whether a rule lives in shared helpers, context state, or UI components
- Mixed-content cases where one entity type is likely to be left behind by a partial fix

For each real weak spot:
- Name the competing design options
- Recommend the preferred option
- Explain why that option should be locked into the implementation plan now
- State what exact decision text the engineer should add to the plan so later reviewers do not reopen it casually

Do not invent design debates where the codebase or plan already has a clear established pattern.
Do not reopen a decision the user already confirmed. If current code makes the lock unsafe or impossible, report the concrete conflict under `Errors` and explain what must be renegotiated; do not silently substitute another design.
Do not use reviewer-churn prevention to broaden a focused fix into generalized platform work. If resolving a weak spot would add services or files outside the smallest defect boundary, consult the user before retaining it as a required decision lock.

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
- `usage_events` is the canonical ledger for usage/cost accounting; `batches` are lifecycle anchors and cached rollups only.
- `usage_events.batch_id` must stay join-compatible with `batches._id`; do not approve plans that mix string and BSON IDs for the same join contract.
- If product lookup behavior is part of the plan, verify whether the query needs both `product` and `name` fields.
- If page references are stored as strings, convert them to `ObjectId` before querying linked collections.

#### Usage tracking & cost accounting
If the plan adds or changes production LLM/provider/vendor calls, durable generation flows, retries, background jobs, SERP crawls, Tellis Agent calls, QFO/content-gap pipelines, attribute enrichment, cleanup evaluation, Apify/vendor runs, or Admin usage reporting, confirm all of the following before passing:
- The plan was checked against the applicable FAQ/PDP, attribute-enrichment, image, and catalog-health implementations, and names the closest precedent plus any intentional divergence in batch W/G/M or `usage_events` behavior.
- The plan names the approved accounting boundary: tracked shared client/recorder, existing usage helper, or explicit `usage_events` emission.
- Direct OpenAI/Gemini/Anthropic/Bedrock calls stay inside approved adapter/recorder boundaries. If a new boundary is proposed, the plan must update provider-call guardrails and allowlist entries with a reason.
- Charged failures are explicitly handled: max-token/truncation attempts, parse failures after billed calls, partial retries, exhausted retries, and vendor runs with known cost must emit real usage/cost rather than zeros or only the final success.
- Durable workflows have a batch decision: origin batch vs modification aggregate vs conversation batch vs pipeline/run batch, including create/reuse/finalize behavior and what happens if batch creation or CacheService writes fail.
- Batch rollups are described as cached summaries derived from emitted events, not the source of truth.
- CacheService/Backend model, route, Caddy, Admin reporting, and test changes are included when the usage payload shape or endpoint surface changes.
- Focused tests or guardrails cover the touched path, such as usage event routes, token retry/max-token handling, SERP provider usage, agent usage, Apify usage, QFO/content-gap recording, Admin report aggregation, or `tests/test_llm_call_guardrails.py`.

Missing usage accounting in a touched production provider path is a critical pattern break and should usually make the gate fail.

#### CacheServiceAPP patterns
- Reads should use cache-aware helpers such as `find_one_cached()` / `find_many_cached()` when applicable.
- Writes should use invalidation-aware helpers such as `update_with_invalidation()` / `insert_with_invalidation()` when applicable.
- Internal helpers should be prefixed with `_`.

#### Domain ownership and service boundaries
- Reuse the existing class or domain service that owns the affected business rule, lifecycle, normalization, persistence, integration, or accounting behavior.
- Routes should validate and orchestrate; they should not duplicate domain rules already encapsulated below the route layer.
- Background jobs should call the same domain service as synchronous entry points unless the plan documents a concrete execution-boundary reason not to.
- New services must have a distinct responsibility. Flag wrapper services, parallel managers, or direct database/provider calls that bypass an established owner without removing or intentionally superseding the old path.
- When extending an owner is impractical, require the plan to name the existing owner, explain why it cannot be reused, and lock the replacement/deprecation strategy so both paths do not drift.
- For Tellis W/G/M workflows, require one canonical owner for lifecycle transitions, RunItem execution state, current-artifact identity, and usage totals. Redis polling state, pipeline-specific documents, endpoint responses, and compatibility wrappers may project canonical state but must not independently create, finalize, or reconcile it.

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

### Thread/lock divergence
Include whenever the plan differs from the current user discussion or confirmed locks. Omit only when there is no relevant divergence.

Format:
- **[Confirmed lock → affected plan step]**: The user confirmed `<decision>`, but the plan `<contradicts/omits/reopens/narrows/broadens it>`. Required correction: `<exact plan change>`.

Any material divergence from an explicit confirmed lock must also appear under `Errors` and fail the gate.

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

For usage-accounting pattern breaks, explicitly name:
- the provider/vendor call or workflow being changed
- the missing `usage_events`/batch/guardrail/test requirement
- the established boundary or helper the plan should use
- the compared FAQ/PDP, attribute-enrichment, image, or catalog-health precedent and whether the difference is intentional or drift

For class/domain-service bypasses, explicitly name:
- the existing class or service that owns the behavior
- the plan step or proposed code path that bypasses it
- the invariant or behavior that would be duplicated or split
- whether the plan should reuse/extend the owner or explicitly replace and deprecate it

### Mongo data reality
Include only if you actually checked Mongo and found plan-relevant shape drift or constraints.

Format:
- **[Collection]**: The real data pattern that affects the plan.

If there are no findings in a section, omit that section instead of writing filler.

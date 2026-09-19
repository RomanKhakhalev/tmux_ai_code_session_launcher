---
name: review-plan
description: Review a Tellis implementation plan before coding to prevent drift from the user thread, confirmed decisions, current code, data reality, and established ownership or accounting boundaries. Use when asked to review, validate, or gate a plan; report only material blockers and regression risks, not minor implementation choices.
---

Review the implementation plan as an intent and drift-control artifact. Do not write code unless the user explicitly switches to implementation.

## Review standard

- Re-read the plan from disk immediately before reviewing it.
- Treat explicit user decisions, rejected alternatives, and later corrections in the current thread as binding. Do not promote brainstorming or unanswered questions into locks.
- Verify claims against code or data before flagging them.
- Preserve the requested scope. Do not turn a focused change into generalized hardening, migration, or architecture work.
- Require material refactoring or architecture expansion to earn its scope through concrete product or maintenance value. Verified tech-debt reduction counts as value when it removes duplication, competing ownership, recurring incident risk, or ongoing maintenance burden; aesthetic cleanup and speculative future flexibility do not.
- Require the plan to lock outcomes, ownership, invariants, integration boundaries, visible UX, and material operational constraints.
- Leave implementation-equivalent choices to coding and code review. Do not flag style, local naming, helper placement, file shape, or speculative implementation details unless they create a verified material risk.
- Prefer a few strong findings. Omit empty sections and optional observations.

Retain a finding only when it is:

1. required to implement a confirmed decision;
2. necessary for correctness or safety within the existing scope;
3. a concrete regression risk in a path the plan changes; or
4. a verified violation of an established ownership, persistence, routing, security, lifecycle, or accounting boundary; or
5. a material refactoring or subsystem whose delivery, regression, or operational cost is not justified by concrete product benefit or net maintenance-value improvement.

Drop optional cleanup, future-proofing, generalization, defense in depth, and minor inconsistencies. If a required correction would materially expand scope, explain why the smaller boundary is unsafe and obtain a user decision before making it gate-blocking.

## Gate

Start the response with exactly:

- `GATE:fail` when a material blocker must be fixed before implementation.
- `GATE:pass` when no material blocker remains.

Fail for:

- a contradiction, omission, or reopening of a confirmed user lock;
- a verified false assumption or missing prerequisite that makes the plan unsafe or materially incorrect;
- broken cross-step or cross-service data flow;
- an unjustified bypass or duplication of an established domain owner;
- a required CacheServiceAPP or VectorSearchAPP Caddy route omission;
- unsafe Mongo assumptions verified against real data;
- a changed production provider call without required usage accounting and tests;
- parallel W/G/M, current-artifact, batch, or usage-accounting ownership;
- material refactoring or architecture expansion whose product or maintenance value does not justify its delivery, regression, and operational cost;
- a genuinely material unresolved decision likely to change UX, domain behavior, ownership, persistence, rollout, or a cross-service contract.

Do not fail for details that can be settled during implementation without changing the agreed outcome or boundaries.

## Workflow

### 1. Reconcile intent and scope

Read the current plan and thread. Extract:

- intended outcome and smallest reasonable scope;
- confirmed decisions and rejected alternatives;
- affected services, files, endpoints, jobs, UI surfaces, dependencies, and data flows;
- new or changed provider calls, durable workflows, persistence, and operational exposure.

Map each relevant lock to the plan step that implements it. Flag only material contradictions, omissions, unacknowledged scope changes, or ambiguity that permits outcome drift.

### 2. Gate scope against value

Separate changes directly required for the requested outcome from refactoring, generalized hardening, new infrastructure, or architecture expansion.

For each material scope addition, verify a concrete benefit:

- direct user or product value;
- removal of verified duplication or competing ownership;
- measurable reduction in recurring maintenance, incident, operational, or delivery cost;
- necessary simplification that leaves the affected system with less net complexity.

Compare the plan with the smallest safe implementation that preserves the confirmed outcome and established boundaries. Count tech-debt reduction as valid maintenance value, but assess the net result: moving complexity, adding abstraction around one use case, or building speculative extensibility is not debt reduction.

Fail the gate when material refactoring or a new subsystem substantially expands the change without evidence that its product or net maintenance value outweighs implementation cost, regression surface, operational burden, and future ownership. Do not fail small local refactors that are necessary to implement the outcome safely or that plainly reduce complexity in the touched path.

### 3. Check targeted prior work

Search Linear only when history could constrain the plan:

- Search the last 180 days with 2-3 exact domain/component queries.
- Fetch at most 5 issues per query and 10 total.
- Read comments for at most 2 clearly relevant issues.
- Keep only prior decisions, same-path regressions, or intentionally opposite approaches.
- Discard connections requiring more than one inferential hop.

Omit prior work if nothing material survives.

### 4. Verify code and paths

Confirm named paths, symbols, routes, models, helpers, and contracts. Read representative call sites before judging.

Identify the current owner of each affected invariant:

- domain or orchestration service;
- repository/data manager;
- provider/integration client;
- validation, normalization, persistence, caching, lifecycle, or accounting helper.

Flag a bypass only when it would duplicate behavior, split writes or invariants, or establish a competing owner. Do not demand an abstraction merely because a similarly named class exists.

### 5. Check Mongo conditionally

Use read-only Mongo access only when the plan changes queries, schemas, writes, migrations, backfills, IDs, or page/product linking.

- Inspect only affected collections.
- Check schema/index metadata first.
- Sample 3-5 documents with narrow projections.
- Verify BSON types, nullability, nesting, indexes, and legacy variants.
- Report only facts that materially change the plan.

Relevant Tellis invariants:

- Store and query `client_id` as `ObjectId`.
- Keep `usage_events.batch_id` join-compatible with `batches._id`.
- Convert string page/document references before direct Mongo queries.
- Use `created_at` and `updated_at`; do not add `generated_at`.
- Verify mixed legacy shapes rather than assuming them.

### 6. Check durable workflows and provider accounting conditionally

Run this check only when the plan touches generation/regeneration, approval/publish mutations, retries, background execution, provider calls, durable batches, or usage reporting.

Trace only the closest relevant existing pipeline precedent. Compare additional families—FAQ/PDP, attribute enrichment, images, or catalog health—only when needed to resolve ownership or detect drift.

Require the plan to state:

- the canonical batch and W/G/M owner it reuses or replaces;
- where every billable provider attempt emits `usage_events`;
- batch attribution, rollup/finalization, retry, partial-success, cancellation, and charged-failure behavior;
- whether routes, workers, Redis records, pipeline documents, and wrappers are transports/projections or owners;
- any intentional divergence and, for replacement, migration and deprecation.

Fail when the plan creates or leaves room for a second W/G/M, current-artifact, batch, or usage-total owner. Do not require this analysis for workflows outside the plan.

### 7. Apply Tellis hard checks

Apply only checks relevant to the affected scope.

#### Routing

- CacheServiceAPP Caddy uses explicit `@reads` / `@writes` allowlists.
- VectorSearchAPP uses explicit per-route routing.
- NlpAPP and CrawlerAPP use prefix wildcards; update only for a new prefix.
- BackendAPP and FrontendAPP wildcard routing normally needs no Caddy change.

#### Usage accounting

- `usage_events` is the canonical ledger; batch rollups are derived summaries.
- Keep provider calls inside an approved tracked client/recorder boundary.
- Record billed truncations, parse failures, partial/exhausted retries, and other charged failures.
- Update payload models, routes, Caddy, reporting, and focused guardrails only where the touched contract requires them.

#### CacheServiceAPP

- Use cache/invalidation-aware Mongo helpers when applicable.
- Prefix internal helpers with `_`.
- Use `get_redis()`; degrade gracefully when Redis is unavailable.

#### Domain ownership

- Routes validate and orchestrate; domain services own business rules and lifecycle.
- Background and synchronous entry points should share the same owner unless a concrete boundary requires otherwise.
- A new service or manager must have a distinct responsibility or explicitly replace and deprecate the previous owner.

#### API and frontend

- Follow `routes/{component}.py`, `/api/{component}/{action}`, typed request/response models, and reasonable error handling when adding endpoints.
- For a new product-detail tab, verify the product-detail type, metrics handling, all ProductDetailView variants, `useActiveInsight.ts`, and `DetailTabs.tsx`.

#### Version and timestamps

- Use `PRODUCT_VERSION` as the version source.
- Use `created_at` / `updated_at`.

### 8. Filter findings

Before writing the review, remove any item that:

- lacks direct thread, code, data, or relevant Linear evidence;
- concerns an unaffected adjacent path;
- flags existing legacy behavior that the plan explicitly replaces or removes when the remaining work is straightforward implementation plumbing; retain it only if the replacement is incomplete or creates a concrete material risk;
- merely prefers another valid implementation;
- predicts a minor inconsistency the plan does not require;
- asks the plan to pre-design local code;
- expands scope without a proven current-path failure.

Treat inefficiency or inconsistency as a finding only when the plan explicitly mandates it and the effect is material to correctness, cost, latency, delivery, ownership, or an integration contract.

Create a decision lock only for a material product, UX, ownership, persistence, lifecycle, accounting, security, rollout, or cross-service choice. State the competing options and exact lock text. Do not lock implementation-equivalent mechanics.

## Output

After the gate line, include:

### Summary

One short paragraph describing the plan and verdict.

Use only the applicable sections below:

### Prior work

- **[TEL-ID - Title]**: Relevant decision, regression, or constraint.

### Errors

- **[Step or file]**: Material problem, consequence, and required correction. Cite the verifying file and line when code established the finding.

### Scope/value

- **[Refactor or subsystem]**: Scope cost, claimed product or maintenance value, verified evidence, smallest safe alternative, and why the net value does or does not justify the expansion.

### Thread/lock divergence

- **[Confirmed lock → plan step]**: Confirmed decision, divergence, and exact correction.

Material lock divergence must also appear under `Errors` and fail the gate.

### Decision locks

- **[Surface or step]**: Material options, preferred choice, reason, and exact text to add.

### Pattern breaks

- **[Pattern]**: Established owner or boundary, the planned bypass/drift, affected invariant, and required reuse or explicit replacement/deprecation.

For provider accounting, name the call, missing event/batch/failure/test behavior, and established recorder boundary.

### Mongo data reality

- **[Collection]**: Verified data shape that materially changes the plan.

### Inefficiencies

- **[Step]**: Plan-mandated material waste and the simpler equivalent.

### Inconsistencies

- **[Steps]**: Material internal contradiction or incompatible contract.

Omit every section with no findings.

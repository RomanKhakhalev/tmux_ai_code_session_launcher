---
name: linear-project-cleanup
description: Audit and reorganize an overgrown Linear project catalogue into a stable initiative and project taxonomy. Use when Codex needs to reduce project sprawl, define naming and scope rules, create destination initiatives/projects, migrate issues from fragmented legacy projects, close emptied projects, and document the resulting structure for future reuse.
---

# Linear Project Cleanup

Define structure before moving anything. Optimize for one stable lookup rule: someone should know where to find a project without guessing between UI, backend, provider, or temporary themes.

If the task is a follow-up on the Tellis workspace cleanup already executed once, read `references/workspace-remap.md` before making additional changes. That file records the exact project remap, what was already closed, and which cleanup items were intentionally left for a later pass.

On reruns, optimize for resume behavior, not replay behavior:

- reuse existing initiatives, labels, and destination projects when they already exist
- skip source projects that are already empty
- skip legacy projects that are already closed
- do not create synonym projects when an existing project already represents the same outcome

## Derive Initiative Taxonomy

Use initiatives as stable ownership domains derived from the current workspace, not as a hardcoded list inside this skill.

Derive the initiative taxonomy from:

- existing active initiatives
- existing active destination projects
- local workspace references when available
- the product's durable components and ownership boundaries

Use labels for the second dimension, not initiatives.

- layer labels such as `UI`, `Backend`, `Full-stack`
- source labels such as `Magento`, `GSC`, `GA4`, `QFO`
- context labels such as customer, design, or bug labels

Do not use `UI` vs `Backend` as the top-level structure. That causes one product outcome to split across multiple projects and drift quickly.

Create a new initiative only when the workspace genuinely has a new durable ownership domain. Do not create initiatives for temporary themes, bug buckets, one-off provider work, or implementation layers.

## Ownership Rules

Route work by primary ownership.

- If the user sees or uses it mainly in the Content Studio tab, put it in `Content Studio`.
- If it changes generation, review contracts, determinism, orchestration, or grounding behavior, put it in `PDP Generation Pipeline`.
- If it exists because the agent needs tools, routing, prompts, runtime behavior, or answer quality, put it in `Tellis Agent`.
- If it syncs, stores, materializes, or audits external/catalogue data, put it in `Integrations`.

Apply these conflict rules consistently.

- Agent-facing GSC/GA4 tools belong in `Tellis Agent`.
- GSC/GA4/Magento data plumbing belongs in `Integrations`.
- UI vs backend differences become labels, not separate initiatives.
- Provider names such as `Magento` or `GA4` are usually labels; use dedicated projects only when the provider work has a clear multi-issue outcome.

## Naming Rules

Use full initiative names in project titles. Do not use contractions such as `CS`, `PIPE`, `AGENT`, or `INT`.

Use this pattern:

- `[Initiative Name] - [Outcome]`

Examples:

- `Content Studio - Review Experience`
- `Content Studio - Draft Persistence and Workflow`
- `PDP Generation Pipeline - Determinism and Freshness`
- `Tellis Agent - Platform and Routing`
- `Integrations - Magento Catalogue Sync`

Prefer outcome names over vague buckets.

- Good: `Integrations - Cross-Source Audit and Data Quality`
- Bad: `Bug Fixes`
- Bad: `Polish Bundle`
- Bad: `Artem's feedback`

## Canonical Outcome Derivation

Within a given initiative, prefer a small canonical vocabulary for project outcomes. On reruns or follow-up cleanups, treat semantically similar names as the same project unless the scope is materially different.

Do not hardcode the canonical outcomes in this skill. Instead, derive them from the current workspace.

Sources of truth, in priority order:

1. workspace-specific cleanup/reference files when available
2. existing active destination projects inside the chosen initiative
3. existing active projects that already follow the dominant naming pattern and are clearly not generic buckets

Build the canonical outcome set like this:

- strip the initiative prefix from project names and compare outcomes within one initiative
- treat the current active destination projects as canonical by default on reruns
- prefer older, already-used destination projects over newly proposed wording variants
- if a workspace reference records a prior remap, use its destination projects and keep-outs as soft canonical context

Canonical matching rules:

- `UX`, `Experience`, and `Surface` are often the same outcome class
- `Navigation` and `Discovery` are often the same outcome class
- `Stability`, `Cleanup`, and broad `Hardening` work are often the same maintenance bucket
- `Determinism`, `Freshness`, `Dedup`, and `Staleness` often belong to one pipeline reliability bucket
- provider-specific plumbing and sync work should usually collapse into the established provider project, not a new synonym project

Project matching precedence:

1. exact match to an active project in the correct initiative
2. exact match to a canonical destination recorded in a workspace reference
3. semantic match to an existing active project in the same initiative
4. semantic match to a previously validated destination in a workspace reference
5. only then create a new project

Create a new project only when the proposed outcome is materially distinct from all canonical outcomes in that initiative.

## Scope Rules

Use Linear objects this way.

- Initiative = durable ownership domain
- Project = one meaningful multi-issue outcome
- Issue = concrete implementation chunk
- Label = cross-cutting attribute such as layer, provider, customer, or design context

Create separate projects only when the work can ship or be tracked independently.

- Keep `Content Studio - Draft Persistence and Workflow` as one project if the UI and backend changes are one outcome.
- Split only when the outcomes are independently valuable, not just because the implementation touches different layers.

## Cleanup Workflow

### 1. Audit the workspace

Gather:

- all initiatives
- all active and archived projects
- all project and issue labels
- issue counts per project
- open issues with no project

Look for:

- many small projects inside one real product area
- generic buckets such as `Bug Fixes`
- customer-specific project names
- near-duplicate projects
- projects that are really just one consolidated delivery split too far
- orphaned issues that were never attached to the new canonical project set

Also detect current cleanup state:

- which destination initiatives already exist
- which destination labels already exist
- which destination projects already exist
- which legacy projects are already empty
- which legacy projects are already closed

Treat this as a resume point. Do not assume a rerun is starting from scratch.

### 2. Lock the taxonomy

Before creating anything, write down:

- initiative set
- project naming pattern
- label set
- ownership routing rules

Do not start moving issues until these rules are stable.

### 3. Design the destination project set

For each ownership domain, create a small number of consolidated projects with explicit outcomes.

Design the destination set by clustering the current project catalogue into a smaller number of explicit outcomes per initiative.

On reruns:

- treat existing active destination projects as the default canonical set
- if a workspace reference records a prior validated destination set, reuse it as soft canonical context
- create only missing destinations
- do not recreate synonymous destination projects with slightly different wording

Adapt only when the product boundaries have truly changed.

### 4. Create destination initiatives and labels first

Create only the missing initiatives and labels before any migration. Reuse existing initiatives and labels when they already exist.

This avoids partial remaps into ad hoc buckets.

### 5. Create destination projects

Create only the missing destination projects under their initiatives before moving issues.

Before creating a destination project:

- check whether an equivalent project already exists under the same initiative
- compare against canonical outcomes for that initiative
- if the proposed title is only a wording variant of an existing canonical project, reuse the existing project

Do not create:

- synonym projects
- narrower wording variants of an existing canonical outcome
- duplicate maintenance buckets inside the same initiative

### 6. Migrate issues

Move all issues from legacy projects into the new destination projects, including completed historical issues.

Use this policy:

- historical issues should move too, so the new consolidated project becomes the canonical history line
- legacy projects should be emptied fully
- only empty legacy projects should be closed

If a legacy project mixes two ownership areas, split its issues by actual ownership before closing it.

If a legacy project is already empty on rerun, skip issue migration for it.

### 7. Verify emptiness

After each migration batch, list issues for the legacy projects and confirm they are empty.

Do not close a project until issue count is zero.

### 8. Close emptied projects

Close emptied legacy projects as `Canceled` unless there is a strong reason to mark them `Completed`.

In this cleanup, `Canceled` was used for superseded source projects after full migration.

If a legacy project is already `Canceled` or otherwise closed, skip it on rerun.

### 9. Handle non-project buckets separately

Do not preserve these as normal projects:

- customer feedback buckets such as `BWFO (Artem's feedback)`; convert to labels or customer needs
- generic `Bug Fixes` projects; move issues into domain projects and use a `Bug` label
- broad design buckets; keep standalone only when the design work is a real active stream

### 10. Triage unprojected issues

After the project-level cleanup is stable, audit open issues that have no project attached.

Use this policy:

- leave explicit onboarding or workspace-template issues alone when the user asks to preserve them
- respect workspace-specific keep-outs recorded in a local cleanup/reference file when available
- if no keep-outs are recorded, do not automatically move product-agnostic onboarding/template issues unless the user asks
- classify every other unprojected issue using the same ownership rules as project migration
- prefer attaching the issue to an existing canonical project in the correct initiative
- create a new project only if the issue reveals a genuinely missing multi-issue outcome that is materially distinct from all canonical outcomes
- if several unprojected issues describe the same outcome, group them into one canonical destination project instead of scattering them

Recommended execution order:

- list all open unprojected issues
- remove explicit user keep-outs and any keep-outs recorded in the workspace reference
- map each remaining issue to a canonical destination project
- present the `issue -> project` mapping before writing, unless the user asked for direct execution
- move the issues only after the mapping is stable

## Decision Tests

Use these tests when scope is ambiguous.

### Agent tool for GA4 or GSC

- If the work exposes synced data to the agent, use `Tellis Agent`.
- If the work builds the sync, storage, materialization, or source contract, use `Integrations`.

### UI and backend both involved

- Keep one project if the outcome is one deliverable.
- Add `Full-stack` if needed.
- Split only if the two deliveries are independently meaningful.

### Analytics or provider-specific work

- Keep provider as a label by default.
- Promote provider work to a dedicated project only when it has clear multi-issue scope and end state.

### Synonym drift inside one initiative

- If a proposed destination title is semantically close to an existing canonical outcome in the same initiative, reuse the existing project.
- Do not split `Review Experience` into `Review UX`, `Review Surface`, or `Review Flow` unless those are truly independent tracked outcomes.
- Do not split `Discovery and Navigation` into separate projects just because the wording changes.
- Do not split `Stability and Cleanup` into additional broad maintenance buckets unless the scope is materially distinct and durable.

## Linear-Specific Operational Notes

When using Linear tools, remember:

- an issue belongs to one project at a time
- moving the issue is what preserves history in the new consolidated project
- source projects must be emptied before they are closed

If project deletion is unavailable through the active toolset, close emptied projects and leave deletion as a separate manual step.

## Recommended Output Format

When running this cleanup for a user, produce decisions in this order:

1. current catalogue shape and structural problems
2. proposed initiative taxonomy
3. naming and scope rules
4. destination project set
5. old project -> new project migration map
6. migration policy for issues and emptied projects
7. unprojected issue -> project mapping, if relevant
8. execution status after moves

Keep the language direct. The main value is deterministic structure, not broad strategy commentary.

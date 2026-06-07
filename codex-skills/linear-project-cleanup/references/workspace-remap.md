# Tellis Workspace Remap

This file records the exact Linear project reorganization executed in the Tellis workspace on 2026-04-28.

Use this file only for follow-up work in the same workspace. For a fresh workspace, use the generic procedure from `SKILL.md` instead.

## Final Taxonomy

Initiatives created:

- `Content Studio`
- `PDP Generation Pipeline`
- `Tellis Agent`
- `Integrations`

Issue labels created:

- `UI`
- `Backend`
- `Full-stack`
- `Magento`
- `GSC`
- `GA4`
- `QFO`
- `BWFO`
- `Design`

Existing issue label reused:

- `Bug`

## Destination Projects

Created destination projects:

- `Content Studio - Editorial Brief Management and Overrides`
- `Content Studio - Review Experience`
- `Content Studio - Draft Persistence and Workflow`
- `Content Studio - FAQ Editing and Reformat`
- `Content Studio - Discovery and Navigation`
- `Content Studio - Stability and Cleanup`
- `PDP Generation Pipeline - Determinism and Freshness`
- `PDP Generation Pipeline - Review Contract and Preservation`
- `PDP Generation Pipeline - Composer Safety and Grounding`
- `PDP Generation Pipeline - Observability`
- `PDP Generation Pipeline - Model Routing and Orchestration`
- `Tellis Agent - Platform and Routing`
- `Tellis Agent - Analytics Tools`
- `Tellis Agent - Review Loop Reliability`
- `Integrations - Magento Catalogue Sync`
- `Integrations - Magento Sync Hardening and Materialization`
- `Integrations - GSC Sync Foundation`
- `Integrations - GA4 Sync Foundation`
- `Integrations - Cross-Source Audit and Data Quality`
- `Integrations - Catalogue and QFO Data Foundations`

## Tellis Canonical Outcomes

Use these as the current canonical outcome vocabulary for Tellis. Future follow-up cleanups should prefer matching to these outcomes before creating new projects with different wording.

### Content Studio

- `Editorial Brief Management and Overrides`
- `Review Experience`
- `Draft Persistence and Workflow`
- `FAQ Editing and Reformat`
- `Discovery and Navigation`
- `Stability and Cleanup`

### PDP Generation Pipeline

- `Determinism and Freshness`
- `Review Contract and Preservation`
- `Composer Safety and Grounding`
- `Observability`
- `Model Routing and Orchestration`

### Tellis Agent

- `Platform and Routing`
- `Analytics Tools`
- `Review Loop Reliability`

### Integrations

- `Magento Catalogue Sync`
- `Magento Sync Hardening and Materialization`
- `GSC Sync Foundation`
- `GA4 Sync Foundation`
- `Cross-Source Audit and Data Quality`
- `Catalogue and QFO Data Foundations`

## Keep-Outs

These items are intentionally excluded from automatic cleanup unless the user explicitly says otherwise.

- `TEL-1`
- `TEL-2`
- `TEL-3`
- `TEL-4`

Migration policy used:

- move all issues, including completed history
- empty legacy projects fully
- close emptied legacy projects as `Canceled`
- do not preserve generic buckets such as `Bug Fixes` as real projects

## Executed Remap

### Content Studio

- `Content Studio Stability Bundle` -> `Content Studio - Stability and Cleanup`
- `Content Studio UX Audit & Cleanup` -> `Content Studio - Stability and Cleanup`
- `Content Studio Filtered Scope Corrections` -> `Content Studio - Review Experience`
- `Content Studio Polish Bundle` -> `Content Studio - Review Experience`
- `Content Studio FAQ Row Redesign` -> `Content Studio - Review Experience`
- `Content Studio Right Panel Redesign` -> `Content Studio - Review Experience`
- `Content Studio FAQ Preview` -> `Content Studio - Review Experience`
- `Content Studio Draft Save / Approval Persistence Fix` -> `Content Studio - Draft Persistence and Workflow`
- `Content Studio Bugfixes - 21-16 April` -> `Content Studio - Draft Persistence and Workflow`
- `Content Studio PDP Patch Flow & Persistence` -> `Content Studio - Draft Persistence and Workflow`
- `Content Studio Answer Reformat + FAQ Floor` -> `Content Studio - FAQ Editing and Reformat`
- `FAQ Inline Search + Magic Regen` -> `Content Studio - FAQ Editing and Reformat`
- `Content Studio Suggested Products Welcome Panel` -> `Content Studio - Discovery and Navigation`
- `Content Navigator Panel` -> `Content Studio - Discovery and Navigation`

All issues were moved from these source projects. Each source project was then emptied and closed as `Canceled`.

### PDP Generation Pipeline

- `Content Studio FAQ Composer Safety Bundle` -> `PDP Generation Pipeline - Composer Safety and Grounding`
- `FAQ Pipeline Dedup Fixes` -> `PDP Generation Pipeline - Determinism and Freshness`
- `FAQ Source Hashing + Staleness Detection` -> `PDP Generation Pipeline - Determinism and Freshness`
- `FAQ Approve/Decline + Pipeline Preservation` -> `PDP Generation Pipeline - Review Contract and Preservation`
- `FAQ Pipeline Live View` -> `PDP Generation Pipeline - Observability`
- `Adaptive LLM Routing for Low-Risk Pipeline Tasks` -> `PDP Generation Pipeline - Model Routing and Orchestration`
- `FAQ & Product Description Multi-Agent Generation` -> `PDP Generation Pipeline - Model Routing and Orchestration`

All issues were moved from these source projects. Each source project was then emptied and closed as `Canceled`.

### Tellis Agent

- `Tellis Agent` -> `Tellis Agent - Platform and Routing`
- `Agent Consolidation + GSC/GA4 Tools` -> split between:
  - `Tellis Agent - Platform and Routing`
  - `Tellis Agent - Analytics Tools`
- `Improving reviewer.py convergence` -> `Tellis Agent - Review Loop Reliability`

Routing rule used for the split:

- agent platform, routing, runtime, UI, and non-provider-specific behavior -> `Tellis Agent - Platform and Routing`
- GSC/GA4 agent tool exposure and analytics tool work -> `Tellis Agent - Analytics Tools`
- reviewer loop hardening -> `Tellis Agent - Review Loop Reliability`

All issues were moved from these source projects. Each source project was then emptied and closed as `Canceled`.

### Integrations

- `Magento & Tellis Product Catalogue Sync` -> `Integrations - Magento Catalogue Sync`
- `Magento Sync Hardening: Configurable Link Reuse + Safer Simple URL Lookup` -> `Integrations - Magento Sync Hardening and Materialization`
- `Magento Agent Tool Materialisation` -> `Integrations - Magento Sync Hardening and Materialization`
- `GSC Integration` -> `Integrations - GSC Sync Foundation`
- `GA4 + AI Data Room (Foundation, no UI)` -> `Integrations - GA4 Sync Foundation`
- `GSC/GA4 Unmatched URL TTL Audit Log` -> `Integrations - Cross-Source Audit and Data Quality`
- `QFO Pipeline Coverage Filter` -> `Integrations - Catalogue and QFO Data Foundations`
- `Product Room Dead Field Cleanup` -> `Integrations - Catalogue and QFO Data Foundations`

Cross-source routing decisions used:

- `Route GSC simples traffic to configurable parent pages` -> `Integrations - Cross-Source Audit and Data Quality`
- `Page URL convention change: preserve full URLs (stop stripping .html)` -> `Integrations - Cross-Source Audit and Data Quality`
- `Add GSC + GA4 multi-period materialized stats (7d/14d/28d/60d/90d)` -> `Integrations - Cross-Source Audit and Data Quality`

Magento sync/materialization routing decisions used:

- initial catalogue sync foundation -> `Integrations - Magento Catalogue Sync`
- sync hardening and materialized Magento read-path work -> `Integrations - Magento Sync Hardening and Materialization`

All issues were moved from these source projects. Each source project was then emptied and closed as `Canceled`.

## Current End State

The canonical project history now lives in the 20 destination projects above. Legacy projects that fed those destinations were left empty and closed.

This means future agents should:

- continue using the destination projects above
- avoid recreating any of the closed source projects
- treat the closed source projects as legacy containers only

Exceptions after the follow-up cleanup:

- `BWFO (Artem's feedback)` was drained and then closed as `Canceled`
- both `Bug Fixes` projects were drained but intentionally left open for a later decision
- `Design` remains a standalone active project and was renamed from `Design of v1.0.0`

## Follow-Up Cleanup Executed Later

### BWFO

The `BWFO (Artem's feedback)` project was emptied, its issues were relabeled with `BWFO`, and then the project was closed as `Canceled`.

Executed remap:

- `TEL-130 Content Studio: Redesign drafts drawer + landing screen`
  - -> `Content Studio - Discovery and Navigation`
  - labels: `BWFO`
- `TEL-114 Content Studio: Improve navigation and draft visibility`
  - -> `Content Studio - Discovery and Navigation`
  - labels: `BWFO`
- `TEL-129 Content Studio: fix 10 bugs from Artem's review (TEL-115 to TEL-127)`
  - -> `Content Studio - Stability and Cleanup`
  - labels: `BWFO`
- `TEL-113 BWFO - Artem's feedback`
  - -> `Content Studio - Stability and Cleanup`
  - labels: `BWFO`

### Bug Fixes

Both `Bug Fixes` projects were emptied by redistributing all issues into canonical projects. Per user instruction, the projects were left open and not closed.

The older duplicate `Bug Fixes` project was already empty when checked.

Executed remap from the active `Bug Fixes` bucket:

- `TEL-90 pytest-asyncio missing from requirements.txt — async tests fail on clean CI install`
  - -> `PDP Generation Pipeline - Model Routing and Orchestration`
  - labels: `Bug`
- `TEL-89 _llm_call raises ValueError not MaxTokensError on retry exhaustion — breaks faq_generator catch`
  - -> `PDP Generation Pipeline - Model Routing and Orchestration`
  - labels: `Bug`
- `TEL-97 Move ctx field mutations out of asyncio.gather in stage_1_then_3`
  - -> `PDP Generation Pipeline - Model Routing and Orchestration`
  - labels: `Bug`
- `TEL-70 _sanitize_faq_sources drops valid sources when excerpt is very short`
  - -> `PDP Generation Pipeline - Composer Safety and Grounding`
  - labels: `Bug`
- `TEL-111 Fix FAQ verdict dirty-flag and silent network-error bugs`
  - -> `Content Studio - Stability and Cleanup`
  - labels: `Bug`
- `TEL-86 Content Studio: empty panel after FAQ generation — product_id validator silently kills pipeline`
  - -> `Content Studio - Stability and Cleanup`
  - labels: `Bug`
- `TEL-157 Staleness sweep always writes affected_items: [], blocking "Delete & Save"`
  - -> `Content Studio - Stability and Cleanup`
  - labels: `Bug`
- `TEL-110 Auto sign out users with unprovisioned email on login`
  - -> `Tellis Agent - Platform and Routing`
  - labels: `Bug`
- `TEL-109 Hide Agentic Feed and Product Room from sidebar nav (temporarily)`
  - -> `Tellis Agent - Platform and Routing`
  - labels: `Bug`
- `TEL-108 Remove retired floating AskAgentButton from all screens`
  - -> `Tellis Agent - Platform and Routing`
  - labels: `Bug`

### Unprojected Open Issues

Open issues with no project were audited later, excluding `TEL-1`, `TEL-2`, `TEL-3`, and `TEL-4` by explicit user instruction.

One new standalone canonical project was added under `Content Studio`:

- `Content Studio - Editorial Brief Management and Overrides`

Executed remap:

- `TEL-231 Content Studio: Move editorial brief management to Settings, add category overrides, and keep generation-tab instructions ephemeral`
  - -> `Content Studio - Editorial Brief Management and Overrides`
- `TEL-215 Content Studio: No option to remove editorial brief in FAQ generation flow`
  - -> `Content Studio - Review Experience`
- `TEL-198 Content Studio: Improve FAQ approval UX — require manual selection, update approve count, and colour-code selected questions`
  - -> `Content Studio - Review Experience`
- `TEL-208 Content Studio: FAQ and PDP attribute count in "Approve All" button does not match actual number of generated questions`
  - -> `Content Studio - Review Experience`
- `TEL-155 Handle product renames safely in draft and generation flows`
  - -> `Content Studio - Draft Persistence and Workflow`
- `TEL-205 Content Studio: Approved products still show "continue editing" prompt on the main screen`
  - -> `Content Studio - Draft Persistence and Workflow`
- `TEL-219 Content Studio: Approved FAQs for Organic Hemp Seeds still show as "In Progress" in Content Navigator`
  - -> `Content Studio - Draft Persistence and Workflow`
- `TEL-220 Content Studio: Approved FAQ product still displays as pending in Content Navigator`
  - -> `Content Studio - Draft Persistence and Workflow`
- `TEL-209 Content Studio: "Reformat answers" fails with error — one answer could not be generated`
  - -> `Content Studio - FAQ Editing and Reformat`
- `TEL-216 Content Studio: FAQ answers generated in long format despite "Short" being selected`
  - -> `Content Studio - FAQ Editing and Reformat`
- `TEL-217 Content Studio: Removing manually added questions via toggle adds new questions instead of deleting them`
  - -> `Content Studio - FAQ Editing and Reformat`
- `TEL-206 Content Studio: "Start Draft" launches workflow immediately without prompting for model selection`
  - -> `Content Studio - Discovery and Navigation`
- `TEL-214 Content Studio: Clicking on Chamomile Flower Tea in the left menu returns a 404 error`
  - -> `Content Studio - Discovery and Navigation`
- `TEL-171 Content Quality: FAQ answer for Organic Pumpkin Seeds uses unexplained jargon ("pepitas")`
  - -> `PDP Generation Pipeline - Composer Safety and Grounding`
- `TEL-203 Content Quality: FAQ for Beetroot Powder references non-existent 25kg option`
  - -> `PDP Generation Pipeline - Composer Safety and Grounding`
- `TEL-212 Content Quality: FAQ answer for Holy Basil (Tulsi) incorrectly states sourcing is unspecified`
  - -> `PDP Generation Pipeline - Composer Safety and Grounding`
- `TEL-218 Content Studio: "Insufficient product data" error when generating FAQ answers for Organic Hemp Seeds`
  - -> `PDP Generation Pipeline - Composer Safety and Grounding`
- `TEL-213 Content Studio: Error when generating FAQs for Organic Hemp Seeds with Claude Opus`
  - -> `PDP Generation Pipeline - Model Routing and Orchestration`
- `TEL-81 Agent: expose approved/declined FAQ counts and draft status as queryable work-in-progress signals`
  - -> `Tellis Agent - Platform and Routing`

## Follow-Up Cleanup Still Outstanding

These items were intentionally left for a later pass:

- `Bug Fixes` projects
  - current state: both are empty and still open by explicit user request
  - future decision still pending
- `Design`
  - current state: standalone and intentionally left as-is
- `TEL-1` to `TEL-4`
  - current state: intentionally left unprojected by explicit user request

## Practical Rule For Future Agents

When a future cleanup or follow-up request comes in for this workspace:

- first assume the 19 destination projects are canonical
- first inspect whether the request belongs in one of those existing projects
- only create a new project when the requested outcome does not fit an existing canonical project
- do not re-open or reuse the old closed source projects as active tracking buckets
- treat the two still-open `Bug Fixes` projects as temporary leftovers awaiting an explicit user decision

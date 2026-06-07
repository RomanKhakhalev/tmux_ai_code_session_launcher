---
name: linear-project
description: Create or update a Linear project from an implementation plan. Use when the user says "create linear project", "log to linear", "add to linear", or asks to track an implementation plan in Linear. Parse the plan into a project epic, codebase scope, and first issue; derive the correct ownership domain from the current workspace structure; find or create the right initiative/project; update project documents; persist the issue reference to `.linear-issue`; and return the project and issue IDs for commit messages and code comments.
---

# Linear Project

Turn an implementation plan into a structured Linear project and issue set.

Treat Linear structures in this workspace as:

- Initiative = a stable ownership domain derived from the workspace's main product components
- Project = a meaningful multi-issue outcome inside an initiative
- Issue = an individual task within that project
- Labels = secondary dimensions such as implementation layer, provider, customer context, or bug type

Do not hardcode a fixed initiative list, a fixed project list, a fixed project count, or a fixed reference file path.

Hardcode only:

- the derivation logic
- the classification rules
- the anti-drift constraints

## Workflow

### 1. Parse the plan

If the user did not provide a plan, ask for it before proceeding.

Extract:

- Epic
- Codebase scope
- Target date

For the epic, use this exact structure:

- `Goal`
- `User story`
- `Scope`
- `Out of scope`
- `Acceptance criteria`

Tellis framing:

- Headline backend data pipelines and what the Tellis Agent can now do or answer.
- Treat dashboards and UI as supporting surfaces, not the main story.

Writing rules:

- Extract narrative from the plan before inventing anything.
- Reuse existing context, goals, exclusions, and verification text when present.
- Keep the epic long enough to stand alone as a feature brief.
- If the plan already contains a strong epic or feature brief, lift it near-verbatim into the structure above.

For codebase scope:

- List every explicitly named or clearly implied touched file.
- Write one specific one-liner per file.

For target date:

- Convert a stated deadline to `YYYY-MM-DD`.
- Otherwise default to tomorrow relative to the current date.

### 2. Derive the workspace taxonomy

Inspect the current Linear workspace before matching or creating anything.

Gather:

- active initiatives
- active projects
- relevant project documents when needed

If available, also look for local workspace-specific Linear taxonomy or cleanup references in:

- local skill references
- nearby workspace notes
- previously created Linear cleanup artifacts

Use these only as historical context. Do not treat them as an authoritative whitelist of allowed initiative or project names.

Derive the workspace's main ownership domains from durable product components, not from temporary themes.

An ownership domain should represent one of:

- a user-facing product surface
- a durable backend subsystem
- a durable platform capability

These must not become initiatives by themselves:

- `UI`
- `Backend`
- `Bug Fixes`
- `Feedback`
- `Polish`
- customer-specific buckets
- provider names alone, unless they have clearly become standalone owned subsystems

### 3. Classify the plan into one ownership domain

Before searching for a project match, decide:

- Primary ownership domain / initiative
- Whether this should become a new project or an issue under an existing project
- Any obvious issue labels implied by the plan

Classification rules:

- If the work is primarily about a user-facing surface, route to that product surface.
- If the work is primarily about generation, review contracts, determinism, orchestration, or grounding logic, route to that subsystem.
- If the work exists because the agent needs tools, routing, prompts, runtime behavior, or answer quality, route to the agent/platform domain.
- If the work syncs, stores, materializes, or audits external/catalogue data, route to the integration/data domain.

Conflict rules:

- Agent-facing GSC/GA4 tool work belongs with the agent/platform domain.
- GSC/GA4/Magento sync and data plumbing belongs with the integration/data domain.
- UI/backend is never a top-level split by itself.
- A new third-party integration must never be attached to a project for a different integration.

Creation bias:

- Prefer existing projects for bugfixes, hardening, follow-up work, scope extensions, and incremental capabilities.
- Create a new project only when the plan is a genuinely new multi-issue outcome not already covered by an existing project in the same ownership domain.
- Never create generic buckets such as `Bug Fixes`, `Feedback`, `Polish`, or vague integration catch-alls.

Exception:

- If the plan is clearly standalone design strategy or exploration work rather than product/system ownership work, allow it to remain under a standalone design domain instead of forcing it into another initiative.

### 4. Check existing projects

List active Linear projects.

Discard any project whose status contains:

- `Completed`
- `Done`
- `Cancelled`
- `Archived`

Use the classified ownership domain as the first filter when evaluating matches.

### 5. Decide whether this matches an existing project

Only match when both are true:

- The core new capability is the same outcome.
- The project name and description semantically align with the plan.

Bias strongly toward matching when:

- the plan is a bugfix or hardening pass on an existing outcome
- the plan extends an existing capability inside the same ownership domain
- the plan fits the same user-facing or subsystem outcome, even if files differ

Supporting signal only:

- Compare feature-specific file overlap using the project's `Codebase Scope` document when available.
- Ignore generic shared files such as infrastructure, route plumbing, config, or common service files.

If uncertain:

- Do not match.
- Create a new project instead.

### 6. Confirm before writing to Linear

Before any Linear write call, present:

```md
## Proposed Linear action

**Action:** Create new project
**Initiative / Domain:** <initiative or ownership domain>
**Project:** <Name> (new)
**Issue title:** <title>
**Epic summary:** <first 2–3 sentences of Goal>
**Files in scope:** <count> files
**Why:** <why a new project is justified>

Proceed? (yes / no / edit)
```

Or, if matching:

```md
## Proposed Linear action

**Action:** Add issue to existing project
**Initiative / Domain:** <initiative or ownership domain>
**Project:** <Name> (matched)
**Issue title:** <title>
**Epic summary:** <first 2–3 sentences of Goal>
**Files in scope:** <count> files
**Why:** <why this is the best match>

Proceed? (yes / no / edit)
```

Wait for explicit confirmation:

- `yes` or `y`: continue
- `no` or `n`: stop and explain what would have been created
- `edit`: revise, then present the proposal again

### 7. If a matching project exists

#### Detect branch

Run:

```bash
git -C "$PWD" branch --show-current 2>/dev/null
```

If the branch is non-empty and not `main` or `develop`, prepend this line to the issue description:

```md
> Branch: `<branch>`
```

Then create:

- One issue in the matched project
- A `Codebase Scope` document update or creation

If the issue clearly implies existing labels such as `Bug`, `Magento`, `GSC`, `GA4`, `QFO`, or customer/context labels, attach them when available.

If the scope document is newly created:

- Set the project state to `Planned`

### 8. If no matching project exists

Create:

- A new project
- A `Codebase Scope` document
- An `Implementation Plan` document containing the full original plan verbatim
- The first issue in that project

Project rules:

- Use the first Linear team returned
- Use Roman Hahalev as lead: `ae35366b-7756-48b1-a3fb-89cd3bdf929e`
- Attach the project to the derived initiative when one exists
- Name the project from the ownership domain plus a clear outcome
- Prefer pattern `[Initiative] - [Outcome]` when the workspace already uses that naming style
- Otherwise follow the dominant naming convention inside that ownership domain
- Use the full structured epic as the project description
- Set the project state to `Planned` after the project and both documents are successfully created

Creation constraints:

- Prefer adding an issue to an existing project over creating a sibling project.
- Do not create a new initiative for a bugfix, provider label, implementation layer, or temporary workstream.
- Create a new initiative only when the plan introduces a genuinely new durable ownership domain.
- Do not create a new project just because a new branch, provider label, or implementation layer is involved.

Issue rules:

- Use a short imperative title, at most 10 words
- Use the epic as the issue description for matched-project flows
- Use the user story for new-project first issues
- Include the branch line when applicable
- Apply obvious existing labels when clearly implied and available

### 9. Persist `.linear-issue`

Write the created issue reference into the correct worktree, not blindly into the main checkout.

Process:

- Run `git worktree list`
- Identify the worktree whose path matches the current working directory
- Use that directory as the target

Then inspect:

```bash
cat <target-dir>/.linear-issue 2>/dev/null
```

Behavior:

- If missing or empty: create it
- If it already references an issue in the same project: append the new issue
- If it references a different project: replace it

Format:

- First line: issue identifier such as `TEL-42`
- Second line: project name

If the directory is not writable:

- Skip silently
- Do not fail the whole workflow

### 10. Return results

Return:

```md
## Logged to Linear

**Project:** <Name> — <url>
**Project ID:** `<id>`
**Issue:** <Title> — <url>
**Issue ID:** `<identifier>`

### For commit messages / code comments
Project: <project id> · Issue: <TEL-XX>
Ref: <project url> <issue url>
```

If any step failed:

- State exactly what succeeded
- State exactly what failed
- Do not hide partial success

## Tooling

Use Linear MCP tools for:

- listing projects, teams, initiatives, documents, statuses
- getting projects, issues, initiatives, and documents
- saving projects and issues
- creating and updating documents

Use shell commands only for:

- reading the current branch
- resolving the correct worktree
- reading or writing `.linear-issue`

Prefer concise, deterministic operations. Avoid browsing unrelated Linear history or creating extra artifacts beyond the project, issue, and the two project documents.

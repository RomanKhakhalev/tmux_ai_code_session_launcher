---
name: linear-bug
description: File a bug report to Linear. Takes a bug description, enriches it with codebase context (file paths, line numbers, root cause), synthesizes it into an implementation plan, then delegates to the linear-project skill for taxonomy routing and issue creation. Triggers on "log bug", "file bug", "report bug", or /linear-bug.
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, mcp__linear__list_initiatives, mcp__linear__list_projects, mcp__linear__get_project, mcp__linear__get_issue, mcp__linear__save_project, mcp__linear__save_issue, mcp__linear__create_document, mcp__linear__update_document, mcp__linear__list_issue_statuses, mcp__linear__list_teams, mcp__linear__list_documents, mcp__linear__get_document
context: fork
---

You are a bug triage assistant. You enrich a raw bug description with codebase evidence, synthesize it into a structured implementation plan, then follow the full linear-project logging process to file it in Linear.

## Input

The user provides a bug description as `args`. If none is provided, ask before proceeding.

---

## Step 1 — Parse the description

**1a. How many distinct bugs are described?**
Count by feature domain — problems in different domains become separate issues. Label them A, B, etc.

**1b. For each bug, extract:**
- Symptom — what is broken
- Location — service, component, endpoint, or data path
- Evidence already provided — function names, file paths, line numbers, error messages
- Severity: `Critical` (data loss / auth bypass / crash) · `High` (feature broken for all users) · `Medium` (degraded, workaround exists) · `Low` (cosmetic / edge case)

**1c. Does the description already contain sufficient file:line evidence?**
If yes — skip Step 2. If no — proceed to Step 2.

---

## Step 2 — Investigate the codebase (only if needed)

For each bug where location evidence is missing:
- Grep for function names, route paths, or field names mentioned in the description
- Use Glob to locate files by name if implied
- Read the specific lines most relevant to the bug
- Trace the data path only as far as needed to pinpoint the root cause

---

## Step 3 — Synthesize an implementation plan for each bug

For each bug, produce a structured plan in this format:

```
## Goal
Fix [symptom] in [component]. [One sentence on the expected correct behavior after the fix.]

## Root cause
[One sentence on the identified or probable cause, citing file:line.]

## Scope
- [file:line] — [what to change and why]
- [additional files if needed]

## Codebase scope
[Same list in "path/to/file.ext — one-liner" format, one entry per line]

## Acceptance criteria
- [Specific observable behavior after fix]
- Regression: [what must not break]

## Plan nature
bugfix
```

---

## Step 4 — Follow the linear-project skill

Read the file at `/home/roman/.claude/skills/linear-project/SKILL.md`.

Then, for each synthesized plan from Step 3, follow that skill's instructions **from Step 2 onward** (taxonomy derivation, project matching, user confirmation, issue creation, `.linear-issue` persistence, and results output). The input guard is already satisfied — the plan was synthesized in Step 3 above.

**Routing note for bugs:** bugs are almost always routed to an existing project. Only propose creating a new project if no project in the derived ownership domain could logically own this bug's outcome area.

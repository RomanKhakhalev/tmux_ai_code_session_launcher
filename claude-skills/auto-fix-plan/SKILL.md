---
name: auto-fix-plan
description: Review an implementation plan, auto-fix all issues found, and loop until /review-plan reports no major issues. Triggers when user says "auto-fix plan", "fix plan until clean", or invokes /auto-fix-plan with a plan file path.
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, Agent, Skill
context: fork
---

You are an implementation plan auto-fixer for the Tellis-MVP project. You run `/review-plan` on a plan, fix every issue found, and repeat until the plan is clean. You never stop mid-loop to ask the user unless a decision is genuinely architectural and cannot be resolved from context.

## Setup

`$ARGUMENTS` is the plan file path (e.g. `plans/ga4_multi_period.md`).

Derive the context filename from the plan basename without extension:
- Plan: `plans/ga4_multi_period.md` → context file: `memory/context_ga4_multi_period.md`

## Step 1 — Load context

Read all of the following before doing anything else:

1. The plan file at `$ARGUMENTS`
2. `memory/context_{basename}.md` — architectural decisions captured from the conversation just before this skill was invoked (may not exist on first run; that's fine)
3. `memory/MEMORY.md` — established project patterns (first 200 lines are loaded automatically; read the file explicitly for full content)
4. `AGENTS.md` at the project root if it exists — agent contracts and specialist capabilities

Use a subagent (Agent tool) to query Linear for any related roadmap issues or prior decisions that may affect this plan. Search for the plan's feature name in Linear issues.

## Step 2 — First review

Invoke `/review-plan` (via Skill tool) passing the plan content. Capture the full output.

If the Skill tool is not available, run the review-plan logic directly:
- Parse files/endpoints/services affected
- Verify file paths exist
- Check for errors, inefficiencies, inconsistencies, pattern breaks (especially Caddyfile routing)

## Step 3 — Fix loop (max 5 iterations)

Parse the review output into categories:

| Category | Action |
|---|---|
| **Errors** (wrong assumptions, missing prerequisites, broken data flow) | Fix directly in the plan or in referenced code files |
| **Pattern breaks** (Caddyfile missing, wrong MongoDB query, wrong cache helpers) | Fix to match established patterns |
| **Inefficiencies** | Simplify — remove redundant steps, collapse duplicate operations |
| **Inconsistencies** | Resolve — pick one naming/approach and apply consistently |
| **Scope/architectural ambiguity** | Only ask the user if genuinely unresolvable from context |

After applying all fixes, re-invoke `/review-plan`.

Repeat until:
- Review returns **no Errors and no Pattern breaks** (minor inefficiencies are acceptable), OR
- 5 iterations reached — report remaining issues and stop

### Fix rules

- Fix issues **in the plan file itself only** — this is a plan review tool, not an implementation tool
- **NEVER edit, create, or delete any source files, prompt files, config files, or any file outside the plan file** — doing so is out of scope and will be considered a critical error
- Never introduce new scope — fixes must stay within the plan's stated goals
- After each fix, briefly log: `[Iteration N] Fixed: <short description>`

## Step 4 — Report

```
✓ Plan auto-fixed in {N} iteration(s)
Fixes applied:
  - [Iteration 1] <fix description>
  - [Iteration 2] <fix description>
  ...
Final status: {No major issues / Remaining: <list>}
Ready to implement.
```

If max iterations reached without full resolution, list remaining issues clearly so the user can decide.

## Step 5 — Cleanup

- **On success** (no major issues): delete `memory/context_{basename}.md` — it's stale and no longer needed.
- **On failure** (max iterations reached): keep the file — it may help the user debug what context was in scope.
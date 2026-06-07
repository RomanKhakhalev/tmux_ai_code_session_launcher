---
name: kill-session
description: Safely close the current feature session — checks for unmerged commits, uncommitted changes, merge conflicts, and open Linear issues before tearing down the worktree and killing the tmux session. Triggers when user says "kill session", "close session", "close feature", "/kill-session".
user-invocable: true
allowed-tools: Bash, mcp__Linear__list_issues, mcp__Linear__save_issue, mcp__Linear__get_issue
context: fork
---

You are tearing down the current feature session. The user is done (or wants to abort). Your job is to verify safety, fix or escalate blockers, resolve Linear state, then cleanly remove the worktree and kill the tmux session.

## Thresholds and blocking rules

| Check | Threshold | Action if exceeded |
|---|---|---|
| Uncommitted changes | Any staged or unstaged changes | BLOCK — show files, ask to commit or stash |
| Unmerged commits | Any commits on branch not in main/develop | BLOCK — show log, ask to merge or confirm abandon |
| Merge conflicts | Any `UU`/`AA`/`DD` entries in `git status` | HARD BLOCK — must be resolved before proceeding |
| Open Linear issue | Issue in non-Done state | Ask to mark Done, or confirm leaving open |

All blocks require explicit user confirmation to override, except merge conflicts — those cannot be bypassed.

## Process

### Step 1 — Identify the session

```bash
BRANCH=$(git branch --show-current)
SESSION=$(tmux display-message -p '#S' 2>/dev/null || echo "")
REPO_ROOT=$(git rev-parse --show-toplevel)
WORKTREE_PATH=$(pwd)
MAIN_CHECKOUT=$(git worktree list | awk 'NR==1 {print $1}')
# Worktrees live at $MAIN_CHECKOUT/.worktrees/$BRANCH
```

Confirm this is a worktree (not the main checkout):
```bash
git worktree list
```
If `WORKTREE_PATH` == `MAIN_CHECKOUT`, abort: "This is the main checkout — kill-session only runs in a worktree."

### Step 2 — Merge conflict check (hard block)

```bash
git status --porcelain | grep -E '^(UU|AA|DD|AU|UA|DU|UD)'
```

If any conflicts found: output the conflicting files and stop. "Resolve merge conflicts before closing this session. Cannot proceed."

### Step 3 — Uncommitted changes check

```bash
git status --porcelain
```

If any output:
- Show the file list
- Ask: "You have uncommitted changes. Commit, stash, or abandon them before closing. What would you like to do?"
- Wait for instruction. Do not proceed until clean or user explicitly says "abandon".

### Step 4 — Unmerged commits check

```bash
git log main..HEAD --oneline 2>/dev/null || git log develop..HEAD --oneline 2>/dev/null
```

If any commits are listed:
- Show them
- Ask: "Branch `$BRANCH` has N unmerged commits. Merge to main/develop first, or confirm you want to abandon this work?"
- If user says merge: remind them to do it manually (this skill doesn't push/merge — too destructive to automate).
- If user confirms abandon: proceed.
- If user wants to keep the branch open: abort kill-session.

### Step 5 — Linear issue check

Search for an open issue associated with this branch:
1. Run `cat .linear-issue 2>/dev/null` to get the issue ID.
2. If found, call `mcp__Linear__get_issue` to check its state.
3. If state is not Done/Cancelled:
   - Ask: "Linear issue [ID] — [Title] is still open. Mark it Done, or leave it open?"
   - If "Done": call `mcp__Linear__save_issue` with `id` and `state: "Done"`.
   - If "leave open": note it and continue.

If `.linear-issue` is missing or MCP call stalls, skip silently.

### Step 6 — Confirm merge and worktree deletion

Before removing anything, explicitly confirm with the user:

1. "Have you merged or pushed all the work from `$BRANCH` that you want to keep? This cannot be undone."
   - Wait for explicit "yes" / "confirmed" / "done". Any ambiguous answer = do not proceed.
2. "About to delete worktree at `$WORKTREE_PATH` and branch `$BRANCH`. Confirm?"
   - Wait for explicit confirmation before Step 7.

### Step 6b — cd out of the worktree

The worktree cannot be removed while CWD is inside it. Switch to the main checkout in the tmux console window (if available), then proceed from there:

```bash
cd "$MAIN_CHECKOUT"
```

### Step 7 — Remove the worktree and branch

```bash
git -C "$MAIN_CHECKOUT" worktree remove "$WORKTREE_PATH" --force
git -C "$MAIN_CHECKOUT" branch -d "$BRANCH" 2>/dev/null || git -C "$MAIN_CHECKOUT" branch -D "$BRANCH"
```

If `worktree remove` fails because CWD is still inside it, instruct the user to run `cd $MAIN_CHECKOUT` in their console window first, then re-run `/kill-session`.

### Step 8 — Kill the tmux session

This is the last step. Output a final status message first, then fire the delayed kill:

```
Session '$SESSION' closing in 2 seconds...
```

```bash
(sleep 2 && tmux kill-session -t "$SESSION") &
```

If `SESSION` is empty (not running inside tmux), skip the kill and just confirm the worktree was removed.

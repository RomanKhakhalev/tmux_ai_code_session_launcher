---
name: kill-session
description: Safely close the current feature session by checking for merge conflicts, uncommitted changes, unmerged commits, and related Linear issue state, then requiring explicit user confirmation of the exact worktree to delete, confirmation that the work has been merged or intentionally abandoned, and confirmation that the linked Linear issue is closed before removing the worktree and killing the tmux session. Use when the user says "kill session", "close session", "close feature", "/kill-session", or otherwise wants to tear down the current feature worktree without losing work accidentally.
---

Safely tear down the active feature worktree. Prevent accidental data loss first, then clean up git, Linear, and tmux in that order.

Stay within shell commands plus Linear issue reads and updates. If `.linear-issue` exists, use Linear issue reads and updates to resolve the linked issue state.

## Safety Rules

Apply these checks in order:

| Check | Threshold | Action |
| --- | --- | --- |
| Session target | Main checkout instead of a linked worktree | Hard block. Stop. |
| Merge conflicts | Any `UU`, `AA`, `DD`, `AU`, `UA`, `DU`, `UD` entry | Hard block. Stop. Do not bypass. |
| Uncommitted changes | Any staged or unstaged change | Block. Show files and wait for the user to commit, stash, or explicitly abandon. |
| Unmerged commits | Any commit on the current branch not in `roman` | Block. Show commits and ask whether to abandon or keep the branch open. If there are no unmerged commits, do not ask a merge/abandon question. |
| Worktree target | Before any destructive action | Block until the user explicitly confirms the exact worktree and branch to delete. |
| Merge/abandon state | Before any destructive action | Block until the user explicitly confirms the work has been merged elsewhere or should be abandoned. |
| Open Linear issue | Linked issue not in `Done` or `Cancelled` | Block until the issue is closed or the user explicitly confirms there is nothing to close. |

Do not bypass merge conflicts. All other blocks require explicit user confirmation before destructive cleanup.

## Workflow

### 1. Identify the session

Run:

```bash
BRANCH=$(git branch --show-current)
TMUX_ERROR_FILE=$(mktemp)
SESSION=$(tmux display-message -p '#S' 2>"$TMUX_ERROR_FILE")
TMUX_STATUS=$?
TMUX_ERROR=$(cat "$TMUX_ERROR_FILE")
rm -f "$TMUX_ERROR_FILE"

if [ "$TMUX_STATUS" -ne 0 ]; then
  if [ -n "${TMUX:-}" ]; then
    echo "tmux session lookup failed while TMUX is set:"
    echo "$TMUX_ERROR"
    echo "Request elevated tmux socket access and rerun: tmux display-message -p '#S'"
    exit 1
  fi

  SESSION=""
fi
REPO_ROOT=$(git rev-parse --show-toplevel)
WORKTREE_PATH=$(pwd)
MAIN_CHECKOUT=$(git worktree list | awk 'NR==1 {print $1}')
git worktree list
```

If `tmux display-message` fails while `$TMUX` is set, do not treat this as no tmux session. Stop, show the tmux error, and request elevated permission to read the tmux socket. Only leave `SESSION` empty when `$TMUX` is unset or tmux reports no server/session.

Treat the session as invalid if `WORKTREE_PATH` equals `MAIN_CHECKOUT`. In that case, stop and say: `This is the main checkout; kill-session only runs in a worktree.`

After confirming it is a worktree, show the exact target:
- Branch: `$BRANCH`
- Worktree: `$WORKTREE_PATH`
- Main checkout: `$MAIN_CHECKOUT`
- Tmux session: `$SESSION` if present

### 2. Check for merge conflicts

Run:

```bash
git status --porcelain | grep -E '^(UU|AA|DD|AU|UA|DU|UD)'
```

If any conflict exists:
- Print the conflicting files.
- Stop with: `Resolve merge conflicts before closing this session. Cannot proceed.`

### 3. Check for uncommitted changes

Run:

```bash
git status --porcelain
```

If any output exists:
- Show the changed files.
- Ask: `You have uncommitted changes. Commit, stash, or abandon them before closing. What would you like to do?`
- Wait. Do not continue until the worktree is clean or the user explicitly says to abandon the changes.

If the user chooses to abandon changes, restate that this discards local modifications, then proceed only after explicit confirmation.

### 4. Check for unmerged commits

Run:

```bash
if git show-ref --verify --quiet refs/heads/roman; then
  BASE_BRANCH=roman
else
  BASE_BRANCH=
fi

git log "${BASE_BRANCH}..HEAD" --oneline 2>/dev/null
```

If any commits are listed:
- Show the commits.
- Ask: `Branch \`$BRANCH\` has unmerged commits relative to \`$BASE_BRANCH\`. Merge first, or confirm you want to abandon this work?`
- If the user wants to merge, stop and tell them to do the merge manually; do not automate pushing or merging.
- If the user wants to keep the branch, stop.
- If the user explicitly confirms abandon, continue.

If no commits are listed, proceed without asking a merge/abandon confirmation. A clean branch with no commits ahead of `roman` has no unique branch content left to protect.

If commits are listed and the user still wants teardown, ask for the explicit final confirmation before proceeding: `Confirm the content from this session should be abandoned.`

Do not continue until the user explicitly confirms the merge-or-abandon state.

### 5. Confirm the worktree target

After the safety checks above pass, repeat the exact target:
- Branch: `$BRANCH`
- Worktree: `$WORKTREE_PATH`
- Main checkout: `$MAIN_CHECKOUT`
- Tmux session: `$SESSION` if present

Then ask: `Confirm you want to delete worktree \`$WORKTREE_PATH\` for branch \`$BRANCH\`.`

Do not continue until the user explicitly confirms.

### 6. Check the linked Linear issue

Run:

```bash
cat .linear-issue 2>/dev/null
```

If the file is missing, empty, or Linear reads fail, skip this step silently.

If an issue ID is present:
- Read the issue.
- If its state is `Done` or `Cancelled`, state that the linked Linear issue is already closed and continue.
- Otherwise ask: `Linear issue [ID] - [Title] is still open. Mark it Done now?`
- If the user says `Done` or otherwise approves closure, update the issue state to `Done` and continue. Do not ask for a second confirmation after the issue has been closed.
- If the user refuses to close the issue, stop. Do not continue with teardown while the linked issue remains open.

If there is no `.linear-issue` file, state that no linked Linear issue was found and continue.

### 7. Move out of the worktree

Before removing the worktree, switch context to the main checkout:

```bash
cd "$MAIN_CHECKOUT"
```

If cleanup fails because the shell is still inside the worktree, stop and instruct the user to `cd` to the main checkout in their console window, then rerun the skill.

### 8. Remove the worktree and branch

Run:

```bash
git -C "$MAIN_CHECKOUT" worktree remove "$WORKTREE_PATH"
git -C "$MAIN_CHECKOUT" branch -d "$BRANCH"
```

Do not use `--force` for worktree removal or branch deletion. If either command fails, stop and show the error rather than bypassing Git safeguards.

### 9. Kill the tmux session last

Print the final status message before killing tmux:

```text
Session '$SESSION' closing in 2 seconds...
```

Then run:

```bash
tmux run-shell -b "sleep 2; tmux kill-session -t '$SESSION'"
```

If `SESSION` is empty but `$TMUX` is set, stop instead of skipping tmux shutdown. This means session detection failed.

If `SESSION` is empty and `$TMUX` is unset, skip tmux shutdown and report only that the worktree was removed.

## Response Style

Keep responses short and operational:
- Show blockers with the exact files or commits involved.
- Ask for one explicit decision at a time when user confirmation is required.
- Repeat the exact worktree path, branch, and Linear issue ID in confirmation prompts.
- State clearly when the skill is stopping versus proceeding.
- Do not perform extra cleanup beyond the workflow above.

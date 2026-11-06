---
name: kill-session
description: Safely close the current feature session by checking git state and ensuring its linked Linear issue has a Product Domain label, an attached project, and a closed state before requiring confirmation to remove the worktree and tmux session. Use when the user says "kill session", "close session", "close feature", "/kill-session", or otherwise wants to tear down the current feature worktree without losing work accidentally.
---

Safely tear down the active feature worktree. Prevent accidental data loss first, then clean up git, Linear, and tmux in that order.

Stay within shell commands plus Linear issue reads and updates. Use `.linear-issue` to resolve the linked issue state when present; otherwise, derive a Linear-style issue identifier from the tmux session name when possible.

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
| Product Domain label | Linked issue has no label in the `Product Domain` group | Add the appropriate child label before teardown. If the domain is not clear, ask the user to choose it. |
| Linear project | Linked issue is not attached to a project | Attach it to a clearly relevant existing project. If none exists, request explicit permission before creating one. |
| Open Linear issue | Linked issue not in `Done` or `Cancelled` | Block until the issue is closed or the user explicitly confirms there is nothing to close. |

Do not bypass merge conflicts. All remaining destructive-cleanup blocks require explicit user confirmation; Linear label and project updates follow the authorization rules below.

## Workflow

### 1. Identify the session

Run:

```bash
BRANCH=$(git branch --show-current)
TMUX_ERROR_FILE=$(mktemp)
SESSION=$(tmux display-message -p '#S' 2>"$TMUX_ERROR_FILE")
TMUX_STATUS=$?
TMUX_ERROR=$(sed -n '1,20p' "$TMUX_ERROR_FILE")
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

# `display-message` needs an attached tmux client. Agents often have no TMUX
# environment variable even though the server and feature session still exist.
# In that case, identify one unambiguous server-side session from the branch.
if [ -z "$SESSION" ]; then
  BRANCH_SESSION=$(printf '%s' "$BRANCH" | tr '-' '_')
  SESSION_MATCHES=$(tmux list-sessions -F '#S' 2>/dev/null | awk -v branch="$BRANCH" -v normalized="$BRANCH_SESSION" '
    $0 == branch || $0 == normalized ||
    index($0, branch "_") == 1 || index($0, branch "-") == 1 ||
    index($0, normalized "_") == 1 || index($0, normalized "-") == 1
  ')
  SESSION_MATCH_COUNT=$(printf '%s\n' "$SESSION_MATCHES" | sed '/^$/d' | wc -l | tr -d ' ')
  if [ "$SESSION_MATCH_COUNT" -eq 1 ]; then
    SESSION=$(printf '%s\n' "$SESSION_MATCHES" | sed -n '1p')
    TMUX_SESSION_SOURCE=branch-match
  else
    TMUX_SESSION_SOURCE=unresolved
  fi
fi
REPO_ROOT=$(git rev-parse --show-toplevel)
WORKTREE_PATH=$(pwd)
MAIN_CHECKOUT=$(git worktree list | awk 'NR==1 {print $1}')
git worktree list
```

If `tmux display-message` fails while `$TMUX` is set, do not treat this as no tmux session. Stop, show the tmux error, and request elevated permission to read the tmux socket. When `$TMUX` is unset, always probe the tmux server with `tmux list-sessions`: use a session only when exactly one name equals the branch (normalizing `-` to `_`) or begins with that branch followed by `_` or `-`. Do not choose among multiple matches. Record `TMUX_SESSION_SOURCE=branch-match` when this fallback succeeds; otherwise leave `SESSION` empty for the final shutdown fallback in step 9.

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

Resolve the issue identifier in this order:

```bash
LINEAR_ISSUE=$(sed -n '1p' .linear-issue 2>/dev/null | tr -d '[:space:]')
LINEAR_ISSUE_SOURCE=.linear-issue
if [ -z "$LINEAR_ISSUE" ] && [ -n "$SESSION" ]; then
  LINEAR_ISSUE=$(printf '%s' "$SESSION" | sed -nE 's/^([[:alpha:]]+)[_-]([0-9]+)([_-].*)?$/\1-\2/p')
  if [ -n "$LINEAR_ISSUE" ]; then
    LINEAR_ISSUE_SOURCE=tmux-session-ticket
  else
    LINEAR_ISSUE="$SESSION"
    LINEAR_ISSUE_SOURCE=tmux-session
  fi
fi
```

The `.linear-issue` value is authoritative when present. When it is missing or empty, first derive a Linear identifier from tmux session names such as `TEL_575_md` (`TEL-575`); otherwise, use `$SESSION` itself as a fallback. If `LINEAR_ISSUE` is empty, state that no linked Linear issue was found and continue.

If `LINEAR_ISSUE` is present:
- Read it as a Linear issue, including its labels and project.
- If it cannot be read and `LINEAR_ISSUE_SOURCE` is `.linear-issue`, stop: the required issue checks cannot be completed.
- If it cannot be read and `LINEAR_ISSUE_SOURCE` is `tmux-session-ticket` or `tmux-session`, state that no linked Linear issue was found and continue.

For a readable issue:
- List the workspace issue labels to identify children whose `parent` is `Product Domain`. Do not apply the `Product Domain` label group itself; apply a child domain label.
- If the issue has none of those labels:
  - Determine the appropriate domain from the issue title, description, linked branch/worktree, and current changes.
  - When one domain is clear, add that label to the issue and report the result.
  - When the appropriate domain is ambiguous, stop and ask the user which `Product Domain` label to use. Do not guess just to complete teardown.
- If the issue has no project:
  - Search non-archived existing projects using the issue title, description, domain label, team, and related/sibling issue context.
  - If one project is clearly relevant, attach the issue to it and report the result. Do not attach to an unrelated project solely to satisfy this check.
  - If multiple projects are plausible, stop and ask the user which existing project to use.
  - If no suitable project exists, stop and ask for explicit permission to create a new project. Include the proposed project name, team, and brief scope in that request. Do not create a project without that permission.
  - After the user explicitly approves creation, create the project, attach the issue, and report both results.
- Re-read the issue after any label or project update. Do not proceed until it has at least one `Product Domain` child label and an attached project.
- If its state is `Done` or `Cancelled`, state that the linked Linear issue is already closed and continue.
- Otherwise ask: `Linear issue [LINEAR_ISSUE] - [Title] is still open. Mark it Done now?`
- If the user says `Done` or otherwise approves closure, update the issue state to `Done` and continue. Do not ask for a second confirmation after the issue has been closed.
- If the user refuses to close the issue, stop. Do not continue with teardown while the linked issue remains open.

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

If `SESSION` is empty and `$TMUX` is unset, do **not** silently skip tmux shutdown. Make one final best-effort attempt to close the current tmux session:

```bash
TMUX_KILL_ERROR_FILE=$(mktemp)
tmux kill-session 2>"$TMUX_KILL_ERROR_FILE"
TMUX_KILL_STATUS=$?
TMUX_KILL_ERROR=$(sed -n '1,20p' "$TMUX_KILL_ERROR_FILE")
rm -f "$TMUX_KILL_ERROR_FILE"
```

If this succeeds, report that tmux was closed by the unscoped fallback. If it fails because there is no server or no current client/session, report that result explicitly and finish teardown. For any other failure, stop and show the error; do not claim tmux cleanup succeeded. Never replace the targeted `kill-session -t "$SESSION"` command when an identified session is available.

## Response Style

Keep responses short and operational:
- Show blockers with the exact files or commits involved.
- Ask for one explicit decision at a time when user confirmation is required.
- Repeat the exact worktree path, branch, and Linear issue ID in confirmation prompts.
- State clearly when the skill is stopping versus proceeding.
- Do not perform extra cleanup beyond the workflow above.

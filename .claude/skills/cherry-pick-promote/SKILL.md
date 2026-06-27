---
name: cherry-pick-promote
description: Cherry-pick a Salesforce ticket from dev to qa or main, following the Salesforce DevOps process
argument-hint: "[qa|main] [ENG-XXXX] (default: qa, ticket from branch)"
---

Promote a Salesforce ticket up the deployment pipeline by cherry-picking its squash commit. Uses a git worktree so the current branch and working tree are never touched.

## Pipeline

| Branch | Environment | Purpose |
|--------|-------------|---------|
| `dev` | Full | Dev team testing |
| `qa` | Full2 | UAT |
| `main` | Prod | Production |

**Merge conventions:** Feature → dev uses **squash and merge**. Promotions (dev → qa → main) use **default merge commit** to preserve per-ticket traceability.

## Step 1 — Parse target and ticket

Parse `$ARGUMENTS` (order-insensitive — detect by pattern):
- `qa` or no target keyword → target is `qa`, source is `dev`
- `main` or `prod` → target is `main`, source is `qa`. **Warn and confirm** before proceeding.
- A token matching `[A-Z]+-\d+` (e.g. `ENG-2071`) → explicit ticket ID.

If no ticket ID in arguments, extract from the current branch name. Patterns: `feature/ENG-XXXX`, `ENG-XXXX/desc`, `Name_ENG-XXXX_desc`. If still not found, ask.

## Step 2 — Find the squash commit

```bash
git fetch origin <source> <target>
git log --oneline origin/<source> --grep="ENG-XXXX" -i | head -5
```

If no results, ask the user for the commit hash directly.

Confirm the match:
> Found on `<source>`: `abc1234 ENG-XXXX: description` — correct?

## Step 3 — Cherry-pick in a worktree

Create a temporary worktree rooted at `origin/<target>`:

```bash
WORKTREE="/tmp/promote-ENG-XXXX"
BRANCH="cherry-pick/ENG-XXXX"
# If branch already exists remotely, append -2, -3, etc.
git worktree add -b "$BRANCH" "$WORKTREE" "origin/<target>"
```

Run the cherry-pick inside the worktree:

```bash
git -C "$WORKTREE" cherry-pick <commit-hash>
```

On conflicts: show conflicting files, read them in the worktree, propose resolutions, confirm with user, then `git -C "$WORKTREE" add . && git -C "$WORKTREE" cherry-pick --continue`.

## Step 4 — Push, create PR, and clean up

```bash
gh pr list --state merged --search "ENG-XXXX" --base <source> --limit 1 --json number,url
git -C "$WORKTREE" push -u origin "$BRANCH"
gh pr create --repo <owner/repo> --head "$BRANCH" --base <target> \
  --title "cherry-pick ENG-XXXX to <target>" --body "$(cat <<'EOF'
## Summary
Cherry-pick of ENG-XXXX from `<source>` to `<target>`.

Source commit: `<hash>` — <message>
Source PR: <link if found>

## Promotion
- [ ] Verified in <source environment> before promoting
- [ ] No unresolved cherry-pick conflicts
EOF
)"
```

Display the PR URL, then clean up:

```bash
git worktree remove "$WORKTREE"
```

The user remains on their original branch with their working tree untouched.

## Rules

- **Never force push** or push directly to `dev`, `qa`, or `main`.
- **Always confirm** the commit hash before cherry-picking.
- **Always confirm** before promoting to `main`.
- Promotions use **merge commits**, not squash.
- **Always clean up** the worktree when done (including on errors/abort).

$ARGUMENTS

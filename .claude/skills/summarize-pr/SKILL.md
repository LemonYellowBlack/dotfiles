---
name: summarize-pr
description: Summarize a PR with diff analysis and linked ClickUp context, or list all open PRs
argument-hint: "[PR number | --list]"
disable-model-invocation: true
allowed-tools: Bash(gh pr:*), Bash(gh api:*), mcp__claude_ai_ClickUp__clickup_search, mcp__claude_ai_ClickUp__clickup_get_task
---

Summarize a pull request from the current repo, or list open PRs if none is specified.

Parse the argument: `$ARGUMENTS`

- If a PR number is provided (e.g., `63`), go to **Step 2**.
- If empty or `--list`, go to **Step 1**.

---

**Step 1 — List open PRs**

Run:
```bash
gh pr list --limit 30 --json number,title,author,createdAt,additions,deletions,changedFiles,headRefName,baseRefName,reviewRequests,isDraft
```

Present as a table:

| # | Title | Author | Base | +/- | Files | Draft | Created |
|---|-------|--------|------|-----|-------|-------|---------|
| 63 | ENG-1960: Rewrite asset screening... | csc-obieq | dev | +500/-200 | 12 | | 2026-03-10 |

Truncate titles to 50 chars. Format `createdAt` as `YYYY-MM-DD`. Show draft status as `draft` or blank.

Ask: "Which PR do you want to summarize?" Wait for the user to pick one, then continue to Step 2.

---

**Step 2 — Fetch PR details**

Run these in parallel:

1. PR metadata:
```bash
gh pr view <number> --json number,title,author,body,headRefName,baseRefName,additions,deletions,changedFiles,labels,reviewRequests,commits,createdAt,isDraft,state
```

2. Full diff:
```bash
gh pr diff <number>
```

3. PR review comments (if any):
```bash
gh api repos/{owner}/{repo}/pulls/<number>/comments --jq '.[] | {path: .path, body: .body, user: .user.login}' 2>/dev/null
```

---

**Step 3 — Linked ClickUp ticket (optional)**

Extract any `ENG-\d+` pattern from the PR title or branch name. If found:

1. Use `ToolSearch` with query `+ClickUp` to load ClickUp tool schemas.
2. Use `mcp__claude_ai_ClickUp__clickup_search` with the ticket ID (e.g., search for "ENG-1960") to find the task.
3. Use `mcp__claude_ai_ClickUp__clickup_get_task` to get the full ticket description and checklist.

If no ticket ID is found, skip this step.

---

**Step 4 — Analyze and present**

Read the changed files in the diff carefully. Produce this summary:

```markdown
## PR #<number>: <title>
**Author:** <login> | **Branch:** <head> → <base> | **Created:** <date>
**Size:** +<additions> / -<deletions> across <changedFiles> files

### What this PR does
[2-3 sentence plain-English summary of the change based on the actual diff, not just the PR description]

### Key changes
[Bulleted list of the significant modifications, grouped by area/domain. Reference specific files.]

### Linked ticket
[If a ClickUp ticket was found: ticket ID, title, description summary, and any checklist items. Note if the PR appears to fully or partially address the ticket. If no ticket found, omit this section.]

### Review comments
[If existing review comments were found, summarize them briefly. If none, omit this section.]

### Things to watch
[Flag any potential concerns spotted in the diff: large files, TODOs, hardcoded values, missing tests, schema changes, security-sensitive code, breaking changes, etc. If nothing notable, say "Nothing flagged."]
```

---

**Rules:**
- Base the summary on the **actual diff**, not just the PR title/description
- If the diff is very large (>2000 lines), focus on the most significant files and note which files were skimmed
- Do not editorialize — flag concerns neutrally, don't pass judgment on code quality
- If ClickUp tools fail to load or the search returns nothing, skip the ticket section silently

$ARGUMENTS

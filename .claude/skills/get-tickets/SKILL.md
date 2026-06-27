---
name: get-tickets
description: List ClickUp tickets assigned to me, filtered by project context, and present for selection
argument-hint: "[tag-filter | --all]"
disable-model-invocation: true
allowed-tools: mcp__claude_ai_ClickUp__clickup_search, mcp__claude_ai_ClickUp__clickup_get_task, WebFetch, Read, Glob, Grep
---

Query ClickUp for tickets assigned to me (user ID 87342837) and present them for selection.

**Step 0 — Load ClickUp tools**

The ClickUp MCP tools are deferred and must be fetched before use. Use the `ToolSearch` tool with query `+ClickUp` to load all ClickUp tool schemas. This MUST complete before proceeding to Step 1.

**Step 1 — Fetch and filter tickets**

Use `mcp__claude_ai_ClickUp__clickup_search` to find tasks assigned to user 87342837 with `task_statuses: ["unstarted", "active"]`, sorted by `updated_at` descending, count 30.

Then check the current working directory against the domain-to-tag map:

| Directory contains | ClickUp tag |
|--------------------|-------------|
| `sf-mcp` | `mcp` |
| `docgen` | `docgen` |
| `asset-screening` | `asset-screening` |
| `sf-data-to-blob-storage` | `databridge` |
| `agentic-sdlc` | `agentic-sdlc` |

If the cwd matches a domain, filter results to tickets with the matching tag. If no match (e.g., repo root or unrecognized directory), show all tickets.

**Step 2 — Present for selection**

Display results in this exact markdown table format:

| # | ID | Name | Status | Sprint |
|---|------|------|--------|--------|
| 1 | ENG-{number} | {task name} | {status} | {list name from hierarchy.subcategory.name} |

If filtered, include a note: `Showing tickets tagged "{tag}". Pass --all to see everything.`

If `$ARGUMENTS` contains `--all`, skip tag filtering and show all tickets.

Ask: "Which ticket do you want to work on?" Wait for the user to pick one.

**Step 3 — Load ticket details and attachments**

Use `mcp__claude_ai_ClickUp__clickup_get_task` with the selected task ID and `detail_level='detailed'` to get the full description, checklist items, linked tasks, and attachments.

Process attachments by type:
- `.md` files: use `WebFetch` to download and read fully (likely handoff documents or implementation plans)
- `.txt`, `.json`, `.xml`, `.csv` files: fetch and read
- Images (`.png`, `.jpg`, `.gif`): fetch and examine visually for error messages, UI state, or annotations
- `.pdf`, `.xlsx`: note filename and URL, mention to user

Also check `~/research-findings/` for related research files.

Present:
- Ticket name, status, description summary
- Key details from attachments (especially handoff docs)
- Any related research context found

**Step 4 — Create worktree**

After presenting the ticket, create an isolated worktree for this ticket:

1. Check `git worktree list` — if a worktree for this ticket already exists, tell the user: "Worktree already exists at `<path>`. Start a session there: `claude <path>`" and stop.
2. If no existing worktree, call `EnterWorktree` with name `ENG-XXXX` (the ticket's custom ID).
3. Once in the worktree, suggest next step: `/investigate-ticket ENG-XXXX` to research or `/implement-ticket ENG-XXXX` to build.

**Rules:**
- This skill is selection and worktree setup only — never create branches, modify code, or stage changes
- Always wait for the user to pick a ticket before loading details
- If the ticket has no description, note that and suggest `/investigate-ticket` to understand the scope
- Always create a worktree — never work directly in the main repo

$ARGUMENTS

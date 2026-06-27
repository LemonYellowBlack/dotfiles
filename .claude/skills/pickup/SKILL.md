---
name: pickup
description: Load context from a ClickUp ticket or local handoff to continue work from a previous session
disable-model-invocation: true
---

Pick up work from a previous session. Accepts a ClickUp ticket ID, a local handoff filename, or shows a menu.

## Arguments

The user's input: $ARGUMENTS

- If it looks like a ClickUp ID (e.g., `ENG-2071` or a raw task ID): load the ticket and its attachments
- If it's a keyword or topic: search ClickUp first, fall back to `~/handoffs/` only if no ClickUp match
- If empty: search ClickUp for recent assigned tickets (see Step 1)

## Steps

**Step 0 — Load ClickUp tools (if needed)**

If the input looks like a ClickUp ID, load the tools first: `ToolSearch` with query `+ClickUp` to get `clickup_get_task` and `clickup_search`. This MUST complete before Step 1.

**Step 1 — Locate the context source**

**If `$ARGUMENTS` is a ClickUp ID:**
- First, check `git worktree list` for an existing worktree matching this ticket ID (e.g., path contains `ENG-XXXX`).
  - If found and we're already in it: proceed to Step 2.
  - If found but we're NOT in it: tell the user: "Worktree exists at `<path>`. Start a session there: `claude <path>`" and stop.
  - If not found: call `EnterWorktree` with name `ENG-XXXX` to create a fresh worktree for resuming work.
- Use `mcp__claude_ai_ClickUp__clickup_get_task` with `detail_level='detailed'` to load the ticket
- Proceed to Step 2

**If `$ARGUMENTS` is a keyword/topic:**
- Search ClickUp first: `mcp__claude_ai_ClickUp__clickup_search` with the keyword, filtered to tasks assigned to user 87342837
- If multiple results, show them and ask the user to pick
- If no ClickUp match, check `~/handoffs/` for matching local files (these exist only for work without a ClickUp ticket)

**If `$ARGUMENTS` is empty:**
- Search ClickUp for recent tasks assigned to user 87342837 with `task_statuses: ["active"]`, sorted by `updated_at` descending
- Present the top results and ask: "Which ticket do you want to pick up?"
- If the user has local-only work (no ticket), they can specify a path in `~/handoffs/`

**Step 2 — Read ticket details (ClickUp path)**

From the `clickup_get_task` response, extract and note:
- Task name, status, custom ID, URL
- Description / markdown description (business context)
- Assignees, tags, priority
- **Attachments** — the response includes an `attachments` array with `url`, `title`, and `extension` fields

**Step 3 — Read all attachments (ClickUp path)**

For each attachment on the task, process by type:
1. `.md` files: use `WebFetch` to download and read fully (likely handoff documents or implementation plans). If multiple `.md` attachments exist, sort by filename date prefix (YYYY-MM-DD) and load the most recent first. Mention older attachments: "There are N older handoffs attached — want to see them?"
2. `.txt`, `.json`, `.xml`, `.csv` files: fetch and read these too.
3. Images (`.png`, `.jpg`, `.gif`): fetch and examine visually — screenshots often show error messages, UI state, or annotations that clarify the task.
4. `.pdf`, `.xlsx`: note the name and URL, mention to user.

**Step 4 — Read referenced local files**

From the handoff document (ClickUp attachment or local file):
1. Read any referenced `~/research-findings/` files — these are the authoritative source for research context
2. Read the key files listed in the handoff to understand current codebase state
3. Check the git branch mentioned in the handoff:
   - Does it exist locally? (`git branch --list <name>`)
   - Is the user currently on it? If not, note they may need to switch.
4. If any referenced files have changed since the handoff was created, flag that to the user

**Step 5 — Present summary**

Present a brief summary:
- What the goal is
- Where things left off (completed vs remaining items from the Progress section)
- What the next steps are
- What attachments/research were loaded and what they contained
- Any discrepancies between the handoff and current codebase state (changed files, missing branches, missing research)

Ask: "Ready to continue? Or do you want to adjust the approach?"

## Rules

- Do NOT start making changes until the user confirms
- **ClickUp is the source of truth for handoffs.** `~/handoffs/` is only for work that has no ClickUp ticket.
- Do NOT check `~/handoffs/` when a ClickUp ticket is involved — all handoffs for ticketed work live as ClickUp attachments
- Research findings are always local (`~/research-findings/`). If a handoff references them and they're missing, flag it clearly.
- If the ClickUp task has no attachments, tell the user and suggest `/investigate-ticket` or `/handoff` to create context
- If ClickUp tools fail (auth, network), fall back gracefully to local `~/handoffs/` files and inform the user
- If the handoff references research that doesn't exist, note what's missing

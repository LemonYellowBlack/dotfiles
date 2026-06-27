---
name: handoff
description: Create a handoff document and attach to ClickUp by default, falling back to local ~/handoffs/ only when no ticket applies
disable-model-invocation: true
allowed-tools: mcp__claude_ai_ClickUp__clickup_get_task, mcp__claude_ai_ClickUp__clickup_search, mcp__claude_ai_ClickUp__clickup_attach_task_file, mcp__claude_ai_ClickUp__clickup_update_task, WebFetch, Read, Write, Glob, Grep, Bash(base64:*)
---

Create a handoff document for session continuity. **ClickUp is the primary destination.** Only save locally if no relevant ClickUp ticket exists.

## Arguments

The user's input: $ARGUMENTS

- If it looks like a ClickUp ID (e.g., `ENG-2071`): use that ticket directly — skip all prompts
- If it's a topic/description: use it to name the handoff and to search ClickUp for a matching ticket
- If empty: proceed normally (Step 1 will identify the ticket)

## Steps

**Step 1 — Determine the ClickUp ticket**

Load ClickUp tools first: `ToolSearch` with query `+ClickUp` to get `clickup_get_task`, `clickup_search`, and `clickup_attach_task_file`.

- **If `$ARGUMENTS` is a ClickUp ID:** verify with `clickup_get_task` (`detail_level='summary'`). Proceed to Step 2.
- **If `$ARGUMENTS` is a topic or empty:** infer the ticket from session context (task names, branch names like `ENG-XXXX`, ticket IDs mentioned in conversation). If a likely ticket is found, confirm with the user: **"Attach to [ID] — [ticket name]?"**
- **If no ticket is obvious:** search ClickUp with `clickup_search` using relevant keywords from the session. Present matches and ask the user to pick one, or choose "local only".
- **If no relevant ticket exists AND the user doesn't want one created:** fall back to local-only mode (`~/handoffs/`, no ClickUp attachment). This is the only scenario where local storage is used.

**Step 2 — Gather context from this session**

1. What was the original goal or task?
2. What research was done? (Reference any files in `~/research-findings/` by path)
3. What was explored in the codebase? (Key files, current implementation details)
4. What decisions were made? (Include reasoning, not just outcomes)
5. What was the proposed approach or plan?
6. What's been done so far vs. what remains?
7. Any gotchas, blockers, or open questions discovered?

**Step 3 — Write the handoff document**

Write the handoff to a temp file first (for ClickUp upload). Use this structure:

```markdown
# Handoff: [descriptive title]
_Created: [date]_
_Source session working directory: [pwd]_
_ClickUp: [custom ID — ticket name, or "local only"]_
_Branch: [current git branch, if applicable]_
_Worktree: [worktree path if in one, from `git worktree list`]_

## Goal
[What we're trying to accomplish]

## Research
[Summary of findings, with paths to full research files]
- See: `~/research-findings/[relevant-file].md`

## Current State
[What exists today — key files, current behavior, relevant code paths]

## Decisions Made
[What was decided and why — include alternatives that were rejected]

## Proposed Approach
[The plan going forward — implementation steps, architecture choices]

## Progress
- [x] Completed items
- [ ] Remaining items

## Gotchas & Open Questions
[Anything the next session needs to watch out for]

## Key Files
[List of files that will need to be read/modified]
```

**Step 4 — Ask the user for review**

Present the handoff and ask if they want to add or correct anything.

**Step 5 — Deliver the handoff**

**ClickUp path (default):**
1. Base64-encode the handoff file: `base64 -w 0 <filepath>`
2. Attach via `mcp__claude_ai_ClickUp__clickup_attach_task_file` with the base64 content and filename `YYYY-MM-DD-[short-topic-slug].md`
3. Confirm success and show the ticket URL
4. Do NOT save a local copy — ClickUp is the source of truth

**Local-only path (fallback):**
1. Save to `~/handoffs/` with filename format: `YYYY-MM-DD-[short-topic-slug].md`
2. Confirm the file path

**Step 6 — Offer status update (ClickUp path only)**

Ask the user: "Update ticket status? (e.g., paused, blocked, or leave as-is)"

Only call `mcp__claude_ai_ClickUp__clickup_update_task` if they choose a status. If they say "leave as-is" or similar, skip.

## Rules

- Do NOT call `ExitWorktree` — let the user decide whether to keep or remove the worktree when the session ends
- Be thorough — the next session has zero context from this one
- Reference actual file paths, not vague descriptions
- Include code snippets for anything non-obvious
- Research findings are referenced by path (`~/research-findings/...`), NOT duplicated into the handoff or attached to the ticket — the pickup skill reads them locally
- **ClickUp is the default destination** — only save locally when no ticket applies
- If ClickUp tools fail (auth, network), fall back gracefully to local `~/handoffs/` and inform the user
- `~/handoffs/` is only used when no ClickUp ticket exists and the user does not want one created — never as a parallel copy alongside ClickUp
- If research findings are critical to the handoff, mention them prominently in the Research section so the pickup skill knows to load them

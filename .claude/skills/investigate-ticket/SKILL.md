---
name: investigate-ticket
description: Investigate a ClickUp ticket — map affected code, query prod data, analyze edge cases, present findings
argument-hint: "<ENG-XXXX>"
disable-model-invocation: true
allowed-tools: mcp__claude_ai_ClickUp__clickup_get_task, Bash(git:*), Bash(sf data query:*), Bash(sf apex run:*), Agent, Read, Glob, Grep, WebFetch
---

Deep investigation of a ClickUp ticket before any code changes. The goal is to understand the root cause, map the affected code, and surface data edge cases that could cause regressions.

## Arguments

The user's input: $ARGUMENTS

Interpret as a ClickUp task custom ID (e.g., `ENG-2056`). If blank, ask the user which ticket to investigate.

**Step 0 — Ensure worktree isolation**

Check if the current session is already in a worktree (`git worktree list` and compare with cwd). If not:
1. Call `EnterWorktree` with name `ENG-XXXX` (the ticket's custom ID).
2. If a worktree already exists for this ticket (check `git worktree list`), tell the user: "Worktree already exists at `<path>`. Start a session there: `claude <path>`" and stop.

Once in the worktree, pull the latest production code: `git checkout dev && git pull origin dev`. Investigations must run against current prod state, not a stale local copy.

Then load ClickUp tools: use `ToolSearch` with query `+ClickUp` to load schemas. This MUST complete before Step 1.

**Step 1 — Load ticket details**

Use `mcp__claude_ai_ClickUp__clickup_get_task` with the task ID to get the full description, checklist items, linked tasks, tags, and attachments.

If the task has attachments, review them using `WebFetch` to download by URL:
- **Images** (screenshots, annotations) — examine for error messages, UI state, or highlighted fields that clarify the report.
- **Documents / PDFs** — summarize relevant details (specs, requirements, referenced data).
- **Other files** (CSV, logs, etc.) — note what they contain based on filename and content.

Call out any details found in attachments that aren't mentioned in the description — these often contain the most important clues.

Also check `~/research-findings/` for related research from previous sessions.

Present a brief summary of the ticket: what's reported, who reported it, any record IDs mentioned, key findings from attachments, and any prior research context found.

**Step 2 — Map affected code**

Based on the ticket description and the current codebase:

1. Identify which classes, components, or services are involved. Use `manifest/` XML files, CLAUDE.md architecture notes, and code search to find the relevant code paths.
2. Read the implementation files (not tests) to understand the current behavior.
3. If the ticket spans multiple systems (e.g., Salesforce + an external service), investigate both sides. Use Agent tool with subagent_type=Explore to parallelize exploration of different codebases when possible.

Present: "Here's the code involved" with file paths, relevant line numbers, and a brief explanation of the current logic.

**Step 3 — Query affected records**

Using record IDs from the ticket description, query Salesforce prod (`--target-org prod`) to see the actual data that triggered the issue.

Present the data and your initial hypothesis for the root cause.

**Step 4 — Broader data sampling (critical)**

This is the most important step. Do NOT skip it.

Query a broader sample of the same object/field combinations — at minimum 100 records, ideally the full population if under 2000 — to discover data shape variations the ticket doesn't mention.

Analyze the data programmatically (use Python via Bash when helpful):
- **Categorize** records into patterns (e.g., standard, legacy, edge case)
- **Count** each category
- **Show examples** of non-standard patterns
- **Check for nulls** — what percentage of records have the relevant fields blank?

If the investigation involves a formula or string-building operation, verify that the fix approach works for EVERY category, not just the ones in the ticket.

Present a data shape summary table:

| Pattern | Count | % | Example | Impact on fix |
|---------|-------|---|---------|---------------|

**Step 5 — Root cause summary**

Present findings:

1. **Root cause** — what's wrong and where in the code
2. **Data patterns** — the full variation discovered, with counts
3. **Risk areas** — edge cases or data shapes that a naive fix could break
4. **Recommended approach** — high-level fix direction with rationale
5. **Open questions** — anything that needs the user's judgment

Do NOT make any code changes. Do NOT create branches. This skill is investigation only.

**Rules:**
- Never modify code or create branches
- Always query prod for real data — don't rely solely on ticket descriptions
- Always sample beyond the ticket's named records
- Present findings and wait for the user to decide next steps
- If the ticket references external systems, investigate both sides
- Use parallel agents when exploring multiple codebases

$ARGUMENTS

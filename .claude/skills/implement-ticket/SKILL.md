---
name: implement-ticket
description: Implement a ticket — create branch, make changes, deploy to dev, evaluate test coverage, stage
argument-hint: "<ENG-XXXX>"
disable-model-invocation: true
allowed-tools: mcp__claude_ai_ClickUp__clickup_get_task, mcp__claude_ai_ClickUp__clickup_update_task, Bash(git:*), Bash(sf:*), Bash(npm:*), Read, Write, Edit, Glob, Grep, Agent, WebFetch
---

Implement a ticket that has already been investigated. Assumes the user has context on root cause and has agreed on an approach.

## Arguments

The user's input: $ARGUMENTS

Interpret as a ClickUp task custom ID (e.g., `ENG-2056`). If blank, ask the user which ticket to implement.

**Step 0 — Load ClickUp tools**

The ClickUp MCP tools are deferred. Use `ToolSearch` with query `+ClickUp` to load schemas. This MUST complete before Step 1.

**Step 1 — Ensure worktree isolation**

Check if the current session is already in a worktree (`git worktree list` and compare with cwd). If not:
1. Call `EnterWorktree` with name `ENG-XXXX` (the ticket's custom ID).
2. If a worktree already exists for this ticket (check `git worktree list`), tell the user: "Worktree already exists at `<path>`. Start a session there: `claude <path>`" and stop.

Once in a worktree, use `mcp__claude_ai_ClickUp__clickup_get_task` to refresh the ticket details.

Check if there's an existing branch for this ticket (pattern: `ENG-{number}/*`). If so, switch to it. If not, proceed to Step 2.

Briefly note the ticket details, then proceed to load prior context.

**Step 1.5 — Load prior context**

Check for investigation and handoff context before proposing an approach:

1. **Ticket attachments** (ClickUp is the source of truth for handoffs): process by type:
   - `.md` files: use `WebFetch` to download and read fully (likely handoff documents with decisions and approach)
   - `.txt`, `.json`, `.xml`, `.csv` files: fetch and read
   - Images (`.png`, `.jpg`, `.gif`): fetch and examine visually
   - `.pdf`, `.xlsx`: note filename and URL, mention to user
   - If multiple `.md` attachments exist, sort by filename date prefix (YYYY-MM-DD) and load the most recent first
2. **Research findings**: check `~/research-findings/` for files referenced in any handoff, or matching the ticket topic

Present what was found: investigation findings, decisions made, agreed approach, and any open questions from prior sessions.

Then state your understanding of the fix, incorporating context from handoffs and investigation. Ask: "Is this the right approach, or has anything changed since investigation?" Wait for confirmation.

**Step 2 — Create branch**

Create a git branch from `dev` using the naming convention:

`ENG-{number}/{ticket-name-kebab-cased}`

Run `git checkout dev && git pull && git checkout -b <branch-name>`.

Ask the user: "Move [ENG-XXXX] to 'in progress'?" Only call `mcp__claude_ai_ClickUp__clickup_update_task` if they confirm.

**Step 3 — Implement**

Make the code changes. Follow these principles:

- **Minimal diff** — only change what's needed for the fix
- **No unrelated cleanup** — don't refactor surrounding code
- **Match existing patterns** — follow the conventions already in the file

**Step 4 — Create deployment manifest**

If working in the Salesforce project, create a scoped manifest XML in `manifest/` for this ticket. Include only the changed classes/components and their test classes. Add a comment block with the deploy + test command:

```xml
<!--
sf project deploy start --manifest manifest/{name}.xml --target-org partial --test-level RunSpecifiedTests --tests {TestClass1} {TestClass2}
-->
```

**Step 5 — Deploy to dev**

Deploy to the dev org (`--target-org partial`) using the manifest with specified tests. If tests fail, fix and redeploy.

For non-Salesforce projects, run the appropriate test suite instead.

**Step 6 — Evaluate test coverage**

After deployment succeeds, critically evaluate whether the existing tests actually verify the changed behavior:

- Do tests **assert on the specific output** affected by this change? (Not just "doesn't throw")
- Are there **edge cases from the investigation** that should be covered?
- Does the test data **reflect real data patterns** (including non-standard formats)?
- Is the **integration path** tested? (e.g., does the context service correctly pass the value through?)

Present an honest assessment: "Tests are sufficient" or "Tests have gaps" with specifics. Do NOT write new tests unless asked — the user invokes `/build-apex-tests` when ready.

**Step 7 — Stage**

Stage the changed files with `git add` (specific files, not `-A`).

Present a summary:
- Files changed and what each change does (one line each)
- Deploy status and test results
- Test coverage assessment
- Any caveats or follow-up items

Do NOT commit — the user handles that.

**Rules:**
- Always wait for user confirmation before creating a branch (Step 2) and before implementing (Step 3)
- Never commit — only stage
- Never push
- Never write tests without being asked
- If the ticket description is empty, ask the user to describe the intended fix before proceeding
- Deploy to `partial` (dev), never to `prod`

$ARGUMENTS

---
name: review
description: Multi-perspective code review with agent synthesis and actionable planning
argument-hint: "[path | --diff | --staged | --branch]"
disable-model-invocation: true
allowed-tools: Bash(mkdir:*), Bash(date:*)
---

You are orchestrating a three-phase code review pipeline. Each phase runs in a separate agent with its own context window: the scanner plans, the coordinator dispatches reviewers and collects results to disk, and the synthesizer reads results from disk, verifies findings, and presents the final output.

## Arguments

The user's input: $ARGUMENTS

Interpret as one of:
- **path** — File or directory to review.
- **--diff** — Review uncommitted working tree changes.
- **--staged** — Review staged (git add) changes only.
- **--branch** — Review all commits on the current branch that aren't on the main branch.

If no argument is provided, default to `--diff`.

## Setup

Generate a unique session directory for this review's temp files. This isolates concurrent review sessions from each other.

```bash
SESSION_DIR="/tmp/review-$(date +%s)-$$"
mkdir -p "$SESSION_DIR/results"
```

All downstream agents receive `$SESSION_DIR` and scope their reads/writes under it. No global cleanup is needed — each session is self-contained.

## Phase 1: Scan

Use the Agent tool to dispatch the **review-scanner** agent. Pass it the user's argument exactly as received:

> "Scan the following for review planning: {$ARGUMENTS or --diff}"

Wait for the scanner to return its JSON dispatch plan.

**Validate the plan**: ensure it has `project_root`, `scale`, `sections` with at least one entry, and each section has `files` and `reviewers`. If the plan is malformed, report the error and stop.

**Write the plan to disk** using the Write tool: `{SESSION_DIR}/plan.json`. This keeps the plan out of downstream agents' prompt context — they read it from disk instead.

## Phase 2: Coordinate

Use the Agent tool to dispatch the **review-coordinator** agent. Pass it the session directory path only:

> "Execute the review dispatch plan at `{SESSION_DIR}/plan.json`. Write all results under `{SESSION_DIR}/results/`."

Wait for the coordinator to confirm results are written to `{SESSION_DIR}/results/manifest.json`.

## Phase 3: Synthesize

Use the Agent tool to dispatch the **review-synthesizer** agent:

> "Read the review results manifest at `{SESSION_DIR}/results/manifest.json`, synthesize findings, verify them, and present the final report. Write all temp files under `{SESSION_DIR}/`."

Wait for the synthesizer to return the final output.

## Phase 4: Present

Output the synthesizer's results directly to the user. Do not reformat or summarize — the synthesizer's output is already in the final presentation format.

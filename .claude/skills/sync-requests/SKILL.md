---
name: sync-requests
description: Find Salesforce Request records assigned to me that are missing from ClickUp, then create ClickUp tickets and link them back to SF.
argument-hint: "[all]"
disable-model-invocation: true
allowed-tools: Bash(python3 *parse-sf-requests*), Bash(sf data *), mcp__claude_ai_ClickUp__clickup_create_task, mcp__claude_ai_ClickUp__clickup_search
---

Sync open Salesforce Request__c records (assigned to me) into ClickUp.

For all IDs, field mappings, SOQL queries, and ClickUp configuration see [field-mappings.md](field-mappings.md).

## Pre-fetched data

**My open SF Requests (prod):**
!`python3 ${CLAUDE_SKILL_DIR}/scripts/parse-sf-requests.py`

---

## Workflow

### Step 1: Present findings

Show the pre-fetched data above in a clean table. Separate requests **missing** from ClickUp vs **already linked**. If all are linked, say so and stop.

### Step 2: Ask for approval

Ask which missing requests to create tickets for: **all**, **pick** (by number), or **none**. Wait for explicit approval.

### Step 3: Create ClickUp tickets

Use `mcp__claude_ai_ClickUp__clickup_create_task` per the mappings in [field-mappings.md](field-mappings.md):

- Populate **custom_fields** (SF Request Record Id, SF Request Type, SF Request URL, etc.) — do NOT put SF metadata in the description body.
- Strip HTML from `Request_Details__c` and convert to markdown for `markdown_description`.
- Map `Priority__c` and `Request_Type__c` using the option IDs in field-mappings.md.

### Step 4: Link back to Salesforce

Update each SF Request with the ClickUp ticket URL and ID using the update command in [field-mappings.md](field-mappings.md).

### Step 5: Summary

Show a final table of what was created:

| SF Request | ClickUp Ticket | URL |
|---|---|---|

# Field Mappings & IDs

## Salesforce

- **Object:** `Request__c`
- **Target org:** `prod` (alias)
- **Owner filter:** `Owner.Name = 'Robbie Szymczak'`
- **Excluded statuses:** `Complete`, `Cancelled`, `Closed`

### SOQL query

```sql
SELECT Id, Name, Status__c, Priority__c, Request_Type__c,
       CreatedDate, Due_Date__c, Requester_s__c,
       ClickUp_Ticket_URL__c, ClickUp_Ticket_ID__c,
       Request_Details__c, Outcome_Statement__c, Next_Step__c,
       Page_URL__c, Impacted_Account__c
FROM Request__c
WHERE Owner.Name = 'Robbie Szymczak'
  AND Status__c NOT IN ('Complete', 'Cancelled', 'Closed')
ORDER BY CreatedDate DESC
```

### SF update command (after ClickUp task creation)

```bash
sf data update record \
  --sobject Request__c \
  --record-id <SF_ID> \
  --values "ClickUp_Ticket_URL__c='https://app.clickup.com/t/<CLICKUP_ID>' ClickUp_Ticket_ID__c='<CLICKUP_ID>'" \
  --target-org prod
```

## ClickUp

- **List:** SF Requests — `901112030390`
- **Assignee:** Robbie Szymczak — `87342837`

### Priority mapping (SF → ClickUp)

| SF Priority__c | ClickUp priority param |
|---|---|
| Urgent | urgent |
| High | high |
| Normal | normal |
| Low | low |

### Custom fields to populate on task creation

Use the `custom_fields` array in `mcp__claude_ai_ClickUp__clickup_create_task`.

| ClickUp Field | Field ID | Type | SF Source | Value Format | Notes |
|---|---|---|---|---|---|
| Salesforce Request Record Id | `e8aa21f8-2b14-453d-b6a9-e699871c4b35` | `short_text` | `Id` | `"value": "a4wPD000002HlNxYAK"` | Plain string |
| Salesforce Request Type | `40c686a4-ea7c-4e60-97c1-91e8b78ad9f5` | `drop_down` | `Request_Type__c` | `"value": "<option-uuid>"` | Use option UUID from table below |
| Salesforce Request URL | `48c83573-5b71-40d4-a5d1-b7b2194659dd` | `url` | — | `"value": "https://cscleasing.my.salesforce.com/<Id>"` | Plain URL string |
| Salesforce Request Outcome Statement | `b07b149b-e4f8-4d2e-bab8-269c61bee722` | `text` | `Outcome_Statement__c` | `"value": "plain string"` | Only if non-null |
| Salesforce Request Next Step | `99e1c03c-af2f-4415-a6ec-2a872646057f` | `short_text` | `Next_Step__c` | `"value": "plain string"` | Only if non-null |
| Salesforce Impacted Account | `74611fc9-b847-482d-b163-c54344a72e71` | `url` | `Impacted_Account__c` | `"value": "https://cscleasing.my.salesforce.com/<AcctId>"` | Only if non-null |
| Salesforce Impacted Page URL | `0c98f6c8-532e-487b-9bd1-f664d03afbbc` | `url` | `Page_URL__c` | `"value": "plain URL string"` | Only if non-null |

#### Value format reference (by field type)

These are the confirmed value formats for the ClickUp MCP tool `custom_fields` array:

| ClickUp Field Type | JSON Value | Example |
|---|---|---|
| `short_text` | `"value": "string"` | `{"id": "...", "value": "a4wPE000000jyjBYAQ"}` |
| `text` | `"value": "string"` | `{"id": "...", "value": "Some long text"}` |
| `url` | `"value": "string"` | `{"id": "...", "value": "https://example.com"}` |
| `drop_down` | `"value": "<option-uuid>"` | `{"id": "...", "value": "ba1e4c94-d22a-4a84-a6e5-7f583dec7723"}` |
| `labels` | `"value": ["<uuid>", ...]` | `{"id": "...", "value": ["uuid1", "uuid2"]}` |

### Request Type dropdown option IDs

| SF Request_Type__c | ClickUp option ID |
|---|---|
| Enhancement | `f43c2e70-3037-4965-bd8e-4439dcaa49e1` |
| Defect | `ce0a7d50-84c1-496b-8636-fa8ee30cb35d` |
| Task | `ba1e4c94-d22a-4a84-a6e5-7f583dec7723` |
| User Setup | `7c6afb13-221d-4a3e-8e30-afe322e178a7` |
| International Travel | `7b3e277c-b5b8-4eb3-ad88-e4adb84e3cee` |

### Description template

The `markdown_description` should contain only the request details (stripped HTML → markdown). SF metadata goes in custom fields, not the description body.

> **IMPORTANT:** Use real newline characters in the `markdown_description` parameter value. Do NOT use escaped `\n` sequences — the MCP tool passes them literally, resulting in visible `\n` text instead of line breaks.

```markdown
**Requester(s):** <Requester_s__c>
**SF Created:** <CreatedDate (date only)>

## Request Details

<Request_Details__c — HTML stripped, lists converted to markdown>
```

### Post-creation verification

After creating a ClickUp task, call `clickup_get_task` with `detail_level: "summary"` to confirm custom fields were populated. If any are missing, update them with `clickup_update_task`.

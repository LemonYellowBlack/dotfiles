---
name: dd-logs
description: Search Datadog logs for DocGen and CSC Leasing services. Use when checking service health, debugging errors, or reviewing recent activity.
argument-hint: "[service] [environment] [timeframe]"
disable-model-invocation: true
allowed-tools: Bash(curl *), Bash(source *)
---

Query Datadog logs for DocGen and other CSC Leasing services.

## Arguments: $ARGUMENTS

Free-form query. Examples:
- `doc-gen-ingestor dev 30m` — ingestor logs from dev, last 30 minutes
- `doc-gen-processor error 1h` — processor error logs, last hour
- `service:asset-screening status:error 15m` — raw Datadog query

## Instructions

1. Parse the arguments to build a Datadog log search query.
2. Source `~/.bashrc.d/datadog.sh` to load `$DD_API_KEY` and `$DD_APP_KEY`.
3. Call the Datadog Logs Search API:

```bash
source ~/.bashrc.d/datadog.sh && curl -s "https://api.datadoghq.com/api/v2/logs/events/search" \
  -H "DD-API-KEY: ${DD_API_KEY}" \
  -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "filter": {
      "query": "<datadog-query>",
      "from": "now-<timeframe>",
      "to": "now"
    },
    "sort": "-timestamp",
    "page": {"limit": 25}
  }'
```

4. Parse the JSON response and present logs in a readable format showing:
   - Timestamp
   - Service name
   - Log level/status
   - Message
5. If the user provides a raw Datadog query (contains `service:` or `status:` etc.), use it directly.
6. Otherwise, build the query intelligently:
   - A service name like `doc-gen-ingestor` becomes `service:doc-gen-ingestor-api`
   - A service name like `doc-gen-processor` becomes `service:doc-gen-processor-bg`
   - Adding `error` adds `status:error` to the query
   - An environment like `dev` or `qa` adds `env:<environment>`
   - Default timeframe is `15m` if not specified

## Environment mapping

| Common name | Datadog service name | Datadog env tag |
|-------------|---------------------|-----------------|
| doc-gen-ingestor / ingestor | doc-gen-ingestor-api | dev, qa, prod |
| doc-gen-processor / processor | doc-gen-processor-bg | dev, qa, prod |

## Pagination

If the user asks for more logs or the result indicates there are more pages, use the `page.cursor` from the response `meta.page.after` field to fetch the next page.

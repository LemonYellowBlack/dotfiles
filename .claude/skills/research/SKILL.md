---
name: research
description: Quick web research on a topic, saving structured findings to ~/research-findings/
context: fork
agent: researcher
allowed-tools: WebFetch, WebSearch, mcp__tavily__tavily_search, mcp__tavily__tavily_extract
---

Research $ARGUMENTS:

1. **Search** — run 3-5 tavily-search queries with varied keywords. Use search_depth "basic" for speed.
2. **Supplement** — use WebSearch for additional angles if tavily results are thin.
3. **Write findings** to `~/research-findings/` using this format:

```markdown
# Research: [topic]
_Generated: [date]_

## Summary
[2-3 paragraph overview]

## Key Findings
[Numbered list with source URLs]

## Code Examples
[Relevant code snippets or configuration patterns]

## Source Links
[All URLs consulted with one-line descriptions]
```

4. Give a brief verbal summary of what you found after writing the file.

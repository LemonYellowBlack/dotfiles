---
name: deep-research
description: Thorough web research with full page extraction, saving comprehensive findings to ~/research-findings/
context: fork
agent: researcher
allowed-tools: WebFetch, WebSearch, mcp__tavily__tavily_search, mcp__tavily__tavily_extract, mcp__tavily__tavily_crawl
---

Conduct thorough, multi-angle research on $ARGUMENTS:

## Phase 1: Broad Discovery
- Run 5-8 tavily-search queries with search_depth "advanced" using different keyword angles
- Also run WebSearch queries for additional coverage
- Collect all promising URLs

## Phase 2: Deep Reading
- Use tavily-extract on the 5-10 most relevant URLs to get full structured content
- If a source is an official documentation site, consider using tavily-crawl to explore related pages
- Use WebFetch for any URLs that tavily-extract doesn't handle well

## Phase 3: Cross-Reference
- Search for contradicting information, known issues, or alternative approaches
- Look for GitHub issues, forum discussions, or blog posts that discuss gotchas
- Check for version-specific differences or recent changes

## Phase 4: Write Findings
Write to `~/research-findings/` using this format:

```markdown
# Deep Research: [topic]
_Generated: [date]_
_Search queries used: [list each query]_

## Executive Summary
[3-5 paragraph comprehensive overview]

## Detailed Findings

### [Subtopic 1]
[Detailed explanation with source attribution]

### [Subtopic 2]
[Detailed explanation with source attribution]

## Implementation Patterns
[Code examples, configuration snippets, architecture patterns]

## Gotchas & Known Issues
[Problems, limitations, version-specific issues, common mistakes]

## Alternative Approaches
[Different ways to solve the problem if multiple approaches exist]

## Open Questions
[Things that remain unclear or need further investigation]

## Sources
[All URLs with one-line description and relevance rating: HIGH/MEDIUM/LOW]
```

## Rules
- Be thorough. Prefer more searches over fewer.
- Always extract full content from the most important sources.
- After writing the file, give a verbal summary of key findings and flag any open questions.

ultrathink

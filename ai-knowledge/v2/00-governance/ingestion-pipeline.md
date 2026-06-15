# Knowledge Ingestion Pipeline

Last Updated: 2026-04-24

## Objective
Continuously keep ai-knowledge accurate and actionable for coding agents.

## Pipeline Stages
1. Collect
   - Pull links from official docs, release notes, mirror updates, project docs.
2. Normalize
   - Convert to concise markdown notes with stable headings.
3. Classify
   - Place notes under one v2 domain folder.
4. Validate
   - Verify API names and signatures against official reference.
5. Publish
   - Update domain index and changelog.
6. Gate
   - Run quality checklist before marking ready.

## Entry Template
- Title
- Last verified date
- Source links
- Scope
- Key rules
- Common pitfalls
- Example snippets
- Open questions

## Update Cadence
- Weekly baseline refresh.
- Immediate patch for breaking/critical API changes.

## Acceptance Criteria
- At least one authoritative source per rule.
- No unresolved conflicts.
- Clear migration guidance when behavior changed.
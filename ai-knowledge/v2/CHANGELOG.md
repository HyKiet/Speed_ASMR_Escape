# Changelog (ai-knowledge v2)

## 2026-04-24
- Added AI operating manual as repository-level AI contract.
- Introduced ai-knowledge/v2 canonical architecture.
- Added governance documents:
  - source-of-truth policy
  - ingestion pipeline
- Added technical indices:
  - Roblox engine reference index
  - Luau reference index
  - Lua 5.1 compatibility delta guide
- Added intelligence and process layers:
  - creator-docs usage notes
  - DevForum evidence policy
  - BrainrotRNG project overrides
  - task routing playbook
  - quality gates checklist
- Marked v2 as active while preserving legacy folders for compatibility.

## 2026-04-24 (Upgrade 9.5)
- Added source auto-sync tooling:
  - `tools/sync_sources.py`
  - `tools/sources.json`
  - generated outputs under `data/snapshots` and `data/sync-report.json`
- Added semantic indexing tooling:
  - `tools/build_semantic_index.py`
  - `tools/query_semantic_index.py`
  - generated index under `data/index/semantic-index.json`
- Added verification harness tooling:
  - `tools/run_verification_harness.py`
  - `08-quality-gates/task-profiles.json`
  - reports under `data/verification/last-report.json`
- Added baseline regression mode for harness:
  - baselines stored in `data/verification/baselines/*.json`
  - fails only on new findings after baseline initialization.
- Added VS Code tasks automation in `.vscode/tasks.json`.
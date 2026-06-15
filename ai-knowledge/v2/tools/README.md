# v2 Tools Quickstart

## 1) Source Auto-Sync
- Command:
  - `python ai-knowledge/v2/tools/sync_sources.py`
- Outputs:
  - `ai-knowledge/v2/data/snapshots/*.json`
  - `ai-knowledge/v2/data/sync-report.json`
  - `ai-knowledge/v2/data/sync-state.json`

## 2) Semantic Index Build
- Command:
  - `python ai-knowledge/v2/tools/build_semantic_index.py`
- Output:
  - `ai-knowledge/v2/data/index/semantic-index.json`

## 3) Semantic Query
- Command:
  - `python ai-knowledge/v2/tools/query_semantic_index.py "server validation remoteevent" --top 8`

## 4) Verification Harness
- Command:
  - `python ai-knowledge/v2/tools/run_verification_harness.py --profile ability`
  - `python ai-knowledge/v2/tools/run_verification_harness.py --profile networking --files src/server/Services/PlayerService.luau`
  - `python ai-knowledge/v2/tools/run_verification_harness.py --profile ability --update-baseline`
- Output:
  - `ai-knowledge/v2/data/verification/last-report.json`
  - `ai-knowledge/v2/data/verification/baselines/<profile>.json`

## Baseline Regression Mode
- First run with `--update-baseline` to capture known legacy findings.
- Subsequent runs fail only on new findings not present in baseline.
- This keeps quality gates strict for regressions without blocking existing technical debt.

## Recommended Order
1. Sync sources
2. Build semantic index
3. Run task profile verification

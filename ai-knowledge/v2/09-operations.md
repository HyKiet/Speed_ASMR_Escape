# v2 Operations Runbook

Last Updated: 2026-04-24

## Daily (active development)
1. Run source sync.
2. Rebuild semantic index.
3. Run verification profile for active task type.
4. If this is first rollout for a profile, initialize baseline once.

## Weekly
1. Run full refresh.
2. Review sync report for changed sources.
3. Update playbooks and quality gates if API deltas are relevant.
4. Re-baseline verification profiles only when intentional large refactors are accepted.

## Incident Response (API change or breakage)
1. Capture failing behavior in project notes.
2. Re-check official docs first.
3. Apply migration patch to relevant v2 domain file.
4. Add regression check in verification profile where possible.

## Storage Locations
- Snapshots: `ai-knowledge/v2/data/snapshots`
- Sync report: `ai-knowledge/v2/data/sync-report.json`
- Semantic index: `ai-knowledge/v2/data/index/semantic-index.json`
- Verification report: `ai-knowledge/v2/data/verification/last-report.json`
- Verification baselines: `ai-knowledge/v2/data/verification/baselines`

# AI Quality Gates Checklist

Last Updated: 2026-04-24

## A) Correctness
- API names and signatures verified against official docs.
- No deprecated API usage unless justified.
- Logic paths handle nil and edge states.

## B) Security
- Remote payload validation present on server.
- Client-only values are never trusted for economy/combat state.
- Rate limiting/cooldown enforcement exists for abuse-prone actions.

## C) Performance
- No runaway loops in hot paths.
- Connections/instances are cleaned up.
- Expensive queries are scoped and throttled.

## D) Architecture Fit
- Controller/service/shared boundaries are respected.
- New code aligns with current module patterns.
- Public APIs are clear and typed where feasible.

## E) Testability
- Includes manual test steps.
- Includes failure-mode checks.
- Includes rollback-safe change surface.

## F) Documentation
- If new behavior was learned, add/update v2 knowledge notes.
- Add source links and last-verified date.
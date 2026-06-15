# BrainrotRNG Coding Contract (AI Overrides)

Last Updated: 2026-04-24
Derived from:
- docs/BrainrotRNG_AI_Context.md
- .agent/workflows/roblox-dev-workflow.md
- .agent/workflows/meme-skill-architect.md

## Architecture Rules
- Client: controllers, input, presentation.
- Server: authority for state, rewards, economy, anti-exploit checks.
- Shared: constants, network schemas, reusable utility modules.

## Ability Design Rules
- Abilities must have gameplay readability and measurable impact.
- Prefer synchronized animation markers for timed VFX windows.
- For heavy movement/forces, prefer modern mover APIs and safe cleanup.

## Security Rules
- Validate all remote payloads server-side.
- Never trust client damage, rarity, currency, or cooldown claims.
- Enforce cooldown and state transitions on server.

## UI Rules
- Follow project design system conventions.
- Keep behavior responsive and avoid hardcoded anti-patterns where project standards define alternatives.

## Performance Rules
- Avoid unbounded loops in render/update paths.
- Use lifecycle cleanup helpers for connections and temporary instances.
- Keep expensive world queries scoped and rate-limited.
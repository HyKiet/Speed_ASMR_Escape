# Luau Coverage Checklist

Last Updated: 2026-04-24

## Language Core
- Variables, scope, control flow, functions
- Tables and metatables
- Operators and precedence

## Type System
- Type annotations and inference
- Strict mode usage strategy
- Public API type boundaries

## Runtime Patterns In Roblox
- Module architecture
- Scheduling and async patterns
- Error handling strategy

## Quality Rules For AI
- Avoid wide any usage in core gameplay logic.
- Prefer explicit return types for non-trivial module APIs.
- Minimize side effects in shared utility modules.
- Keep data transformations deterministic where possible.

## Validation Steps
1. Confirm syntax/type assumptions against Luau docs.
2. Confirm engine-facing APIs against Creator Hub.
3. Add small reproducible test snippet when behavior is non-obvious.
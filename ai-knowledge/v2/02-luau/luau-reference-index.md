# Luau Reference Index

Last Updated: 2026-04-24
Primary: https://create.roblox.com/docs/luau
Upstream language docs: https://luau.org/

## Key Sections
- Syntax and expressions
- Type checking and strict mode
- Data types and tables
- Functions, scope, and control flow
- Operators and coercion behavior
- Metatables and advanced structures
- Performance guidance

## Project-Oriented Rules
- Prefer strict typing in new modules.
- Prefer explicit types for public module APIs.
- Keep function contracts narrow and deterministic.
- Avoid implicit coercion in critical gameplay/economy code.

## AI Coding Defaults
- Use task scheduler APIs over legacy waiting patterns.
- Use clear nil guards for runtime safety.
- Avoid broad any typing unless bridging dynamic data.

## Verification Pattern
For each Luau-specific claim, verify against one of:
- create.roblox.com/docs/luau
- luau.org syntax/types/library/performance pages.
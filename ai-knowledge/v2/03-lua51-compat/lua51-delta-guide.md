# Lua 5.1 vs Luau Delta Guide

Last Updated: 2026-04-24
Lua baseline: https://www.lua.org/manual/5.1/manual.html
Luau docs: https://create.roblox.com/docs/luau

## Why This Matters
Many snippets online are Lua 5.1 oriented. BrainrotRNG code must follow Luau and Roblox runtime constraints.

## Practical Delta Categories
1. Type system
   - Lua 5.1: dynamic only.
   - Luau: gradual typing and strict checking.
2. Tooling
   - Luau in Studio provides script analysis and type diagnostics.
3. Runtime ecosystem
   - Roblox adds engine classes, events, datatypes, scheduler model.
4. Patterns
   - Lua 5.1 metatable idioms still useful, but should be adapted to Luau type safety.

## Safe Porting Rules
- Port algorithmic logic, not direct style assumptions.
- Re-check every standard-library call for Roblox/Luau relevance.
- Replace global-heavy patterns with module-local explicit exports.
- Add type annotations at module boundaries first.

## Anti-Pattern List
- Copying old Lua snippets with implicit globals.
- Assuming all Lua 5.1 debug/library behavior is appropriate in production Roblox gameplay code.
- Using generic Lua I/O patterns in gameplay scripts.
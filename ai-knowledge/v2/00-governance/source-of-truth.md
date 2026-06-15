# Source Of Truth Policy

Last Updated: 2026-04-24

## Authoritative Sources
- Engine API: https://create.roblox.com/docs/en-us/reference/engine
- Luau docs: https://create.roblox.com/docs/luau
- Roblox docs source repository: https://github.com/Roblox/creator-docs/tree/main

## Supporting Sources
- API mirror and update diffs: https://robloxapi.github.io/ref/index.html
- Lua baseline semantics: https://www.lua.org/manual/5.1/manual.html

## Non-Authoritative Research Source
- DevForum threads: https://devforum.roblox.com/

## Conflict Resolution
1. Prefer official Roblox docs over all others.
2. Use creator-docs repo to verify structure/examples.
3. Use mirror for change discovery, not final authority.
4. Use DevForum only to discover hypotheses and edge cases.

## Citation Rule For AI Notes
Each technical claim should include one of:
- exact class/member path,
- exact docs page,
- exact release/update entry,
- exact forum link (if community-only finding).

## Red Flags
- Deprecated API in examples.
- Forum-only fixes without official confirmation.
- Lua 5.1 behavior copied directly where Luau diverges.
# Roblox Lua Style Guide & Best Practices
> Source: roblox.github.io/lua-style-guide/ (Official Roblox Style Guide)
> Source: github.com/Roblox/creator-docs (Official Creator Documentation)

## 1. Guiding Principles
1. **Consistency over preference** — follow the standard, avoid formatting debates
2. **Optimize for reading, not writing** — code is written once, read many times
3. **Clean diffs** — consider how changes will look in version control
4. **Avoid magic** — avoid surprising Lua features; use metatables carefully
5. **Be idiomatic** — follow Luau conventions, not other language patterns

## 2. File Structure (Strict Order)
```lua
-- 1. Optional block comment (why this file exists, NOT author/date)

-- 2. Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 3. Module imports
local MyModule = require(ReplicatedStorage.Modules.MyModule)

-- 4. Module-level constants
local MAX_HEALTH = 100
local REGEN_RATE = 5

-- 5. Module-level variables and functions
local currentHealth = MAX_HEALTH

local function heal(amount: number)
    currentHealth = math.min(currentHealth + amount, MAX_HEALTH)
end

-- 6. The object the module returns (for ModuleScripts)
local Module = {}

-- 7. Return statement
return Module
```

## 3. Naming Conventions

| Type | Convention | Example |
|---|---|---|
| Local variables | camelCase | `local myVariable` |
| Local functions | camelCase | `local function doSomething()` |
| Global/Module functions | PascalCase | `function Module.GetData()` |
| Constants | UPPER_SNAKE_CASE | `local MAX_SPEED = 50` |
| Classes | PascalCase | `local MyClass = {}` |
| Private members | `__` prefix | `self.__internalState` |
| Enum-like tables | PascalCase keys | `{ Running = "Running" }` |
| Unused variables | `_` prefix | `for _, v in items do` |
| Services | PascalCase (match API) | `local Players = game:GetService("Players")` |
| Modules | PascalCase | `local DataManager = require(...)` |
| Type aliases | PascalCase | `type PlayerData = { ... }` |

## 4. Require Patterns

### Order of requires:
1. Common ancestor definition
2. Imported packages
3. Definitions derived from packages
4. Modules from same project

### Library Pattern:
```lua
-- Library internals: require directly
local MyLibrary = script.Parent
local MyModule = require(MyLibrary.MyModule)

-- Library consumers: require API, then access members  
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MyLibrary = require(ReplicatedStorage.MyLibrary)
local MyModule = MyLibrary.MyModule
```

### Rules:
- All `require` calls at TOP of file (static dependencies)
- Sort alphabetically by module name
- Group into logical blocks with blank lines

## 5. Prototype-Based Classes (Official Pattern)

```lua
local MyClass = {}
MyClass.__index = MyClass

-- Export type for external use
export type ClassType = typeof(setmetatable(
    {} :: {
        health: number,
        name: string,
    },
    MyClass
))

function MyClass.new(name: string, health: number): ClassType
    local self = {
        health = health,
        name = name,
    }
    setmetatable(self, MyClass)
    return self
end

-- Use dot notation with explicit self type for type checking
function MyClass.takeDamage(self: ClassType, amount: number)
    self.health = math.max(0, self.health - amount)
end

-- Optional: string representation
function MyClass.__tostring(self: ClassType): string
    return `{self.name} (HP: {self.health})`
end

-- Optional: type guard
function MyClass.isMyClass(instance: any): boolean
    return getmetatable(instance).__index == MyClass
end

return MyClass
```

### Usage:
```lua
local instance = MyClass.new("Player1", 100)
instance:takeDamage(20) -- colon syntax still works!
print(tostring(instance)) -- "Player1 (HP: 80)"
```

## 6. Enum-Like Tables (With Typo Protection)

```lua
local GameState = {
    Menu = "Menu",
    Playing = "Playing", 
    GameOver = "GameOver",
}

setmetatable(GameState, {
    __index = function(_self, key)
        error(`"{tostring(key)}" is not a valid GameState`, 2)
    end,
})

table.freeze(GameState) -- Prevent modifications
```

## 7. Formatting Rules

### Punctuation:
- ❌ No semicolons
- ✅ Trailing commas in multi-line tables

### Whitespace:
- Indent with **tabs**
- Lines under **100 columns** (4-col tabs)
- Comments under **80 columns**
- No trailing whitespace
- Newline at end of file
- ❌ No vertical alignment

### Operators:
```lua
-- ✅ Good: spaces around operators
print(5 + 5 * 6^2)

-- ❌ Bad
print(5+5* 6 ^2)

-- ✅ Good: space after commas
local friends = {"bob", "amy", "joe"}
foo(5, 6, 7)
```

### Blocks:
```lua
-- ✅ Good: inline opening syntax
local foo = {
    bar = 2,
}

if condition then
    doSomething()
end

-- ❌ Bad: braces on own line
local foo =
{
    bar = 2,
}
```

### If Statements (Always multi-line):
```lua
-- ✅ Good
if valueIsInvalid then
    return
end

-- ❌ Bad
if valueIsInvalid then return end
```

### Long Conditions:
```lua
-- ✅ Good: condition indented, `then` on own line
if
    someReallyLongCondition
    and someOtherCondition
    and yetAnother
then
    doSomething()
end
```

### Multi-line Operators:
```lua
-- ✅ Operator at BEGINNING of new line
local result = firstValue
    + secondValue
    + thirdValue
```

## 8. Tables

### Short tables on one line:
```lua
local foo = { type = "foo" }
```

### Dictionary tables with 3+ keys on multiple lines:
```lua
local bar = {
    type = "bar",
    phrase = "hooray",
    count = 42,
}
```

### Arrays can vary:
```lua
local short = { "a", "b", "c" }

local long = {
    "roact",
    "rodux",
    "testez",
    "cryo",
}
```

## 9. Error Handling

```lua
-- Use pcall/xpcall for protected calls
local success, result = pcall(function()
    return riskyOperation()
end)

if not success then
    warn(`Operation failed: {result}`)
end

-- Use xpcall with error handler
local success, result = xpcall(riskyFunction, function(err)
    warn(`Error: {err}\n{debug.traceback()}`)
    return err
end)
```

## 10. Roblox-Specific Best Practices

### Client-Server Security:
- **NEVER trust the client** — always validate on server
- Use `RemoteEvent`/`RemoteFunction` for communication
- Sanity check all parameters on server side
- Don't store sensitive data in `ReplicatedStorage`

### Modern API Usage:
```lua
-- ✅ Modern (use these)
task.wait(1)
task.spawn(func)
task.defer(func)
task.delay(1, func)
task.cancel(thread)

-- ❌ Deprecated (never use these)
wait(1)        -- uses legacy scheduler
spawn(func)    -- has frame delay + throttling
delay(1, func) -- unreliable timing
```

### Instance Management:
```lua
-- Always Disconnect events
local connection = part.Touched:Connect(handler)
-- Later...
connection:Disconnect()

-- Always Destroy unused instances
local part = Instance.new("Part")
-- When done...
part:Destroy()

-- Use Maid/Janitor pattern for cleanup management
```

### UI Design:
- Use `Scale` (not `Offset`) for responsive layouts
- Always set `AnchorPoint` for proper positioning
- Support Mobile, Tablet, and PC

### Performance:
- Cache frequent `game:GetService()` calls at module level
- Use `CollectionService` tags over maintaining manual lists
- Avoid `Instance:FindFirstChild()` in loops — cache the result
- Use `workspace:BulkMoveTo()` for batch part movements

## 11. Common Anti-Patterns to AVOID

```lua
-- ❌ Don't use `a and b or c` for ternary (breaks when b is false/nil)
local val = condition and false or "default" -- ALWAYS returns "default"!
-- ✅ Use if-then-else expression
local val = if condition then false else "default"

-- ❌ Don't shadow built-in globals
local table = {} -- Breaks table library!
-- ✅ Use descriptive names
local dataTable = {}

-- ❌ Don't use getfenv/setfenv
setfenv(1, {}) -- Breaks optimizations, incompatible with strict mode
-- ✅ Use require and proper module system

-- ❌ Don't use string concatenation in loops
local s = ""
for i = 1, 1000 do s = s .. tostring(i) end -- O(n²)!
-- ✅ Use table.concat or buffer
local parts = table.create(1000)
for i = 1, 1000 do parts[i] = tostring(i) end
local s = table.concat(parts)

-- ❌ Don't index missing keys without nil checks
local value = someTable.missingKey.property -- ERROR!
-- ✅ Guard against nil
local value = someTable.missingKey and someTable.missingKey.property
```

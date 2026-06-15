# Luau Language Complete Reference
> Sources: luau.org, github.com/luau-lang/luau (v0.714, MIT License)

## 1. Luau Overview
- Luau (lowercase u, /ˈlu.aʊ/) — fast, small, safe, gradually typed scripting language derived from Lua 5.1
- Used by: Roblox, Alan Wake 2, Farming Simulator 2025, Second Life, Warframe
- Runtime: heavily modified Lua 5.1 VM with rewritten interpreter
- Single number type: 64-bit IEEE754 double (integers up to 2^53 exact)

## 2. Syntax Extensions (Beyond Lua 5.1)

### String Literals
- `\xAB` — hex character
- `\u{ABC}` — UTF-8 encoded Unicode character (braces mandatory)
- `\z` — ignore following whitespace/newlines in string literals

### Number Literals
- Hex: `0xABC` or `0XABC`
- Binary: `0b01010101` or `0B01010101`
- Separators: `1_048_576`, `0xFFFF_FFFF`, `0b_0101_0101`

### Continue Statement
- `continue` works like `break` — must be last statement in block
- NOT a keyword (for backwards compat) — context-dependent
- Cannot skip local variable declarations in `repeat..until` if used in condition

### Compound Assignments
- Supported: `+=`, `-=`, `*=`, `/=`, `//=`, `%=`, `^=`, `..=`
- Single value only on left and right side
- Respects metamethods (`__add`, `__index`, `__newindex`)

### If-Then-Else Expressions
```lua
local maxValue = if a > b then a else b
local sign = if x > 0 then 1 elseif x < 0 then -1 else 0
```
- `else` is **mandatory**
- **PREFER THIS** over `a and b or c` pattern (which breaks when `b` is false/nil)

### Generalized Iteration
```lua
for k, v in someTable do -- No need for pairs() or ipairs()
    print(k, v)
end
```
- Custom iteration via `__iter` metamethod
- Default order: consecutive for 1..#t, then unordered

### String Interpolation
```lua
local name = "World"
print(`Hello, {name}!`) -- backtick strings
print(`2 + 2 = {2 + 2}`)
```
- Use `\`` to escape backtick, `\{` to escape brace
- `{{` is a parse error (prevents confusion from other languages)
- Cannot use in type annotations
- Must wrap in parentheses for function calls: `print(`hello`)`  -- ERROR

### Floor Division
- `a // b` equals `math.floor(a / b)`
- Compound: `//=`
- Metamethod: `__idiv`
- `0 // 0` = NaN, `n // 0` = ±inf

## 3. Type System

### Modes (set at top of file)
- `--!nocheck` — disables type inference entirely
- `--!nonstrict` (DEFAULT) — forgiving, unknown types become `any`
- `--!strict` — full type inference, catches more errors

### Basic Types
`any`, `nil`, `boolean`, `number`, `string`, `thread`, `buffer`, `never`, `unknown`

### Type Annotations
```lua
local x: number = 5
local name: string = "hello"
function add(a: number, b: number): number
    return a + b
end
```

### Function Types
```lua
type Callback = (number, string) -> boolean
type MultiReturn = (number) -> (string, boolean)
type NoReturn = (number) -> ()
```

### Table Types
```lua
type Person = { name: string, age: number }
type NumberArray = { number }  -- shorthand for array
type StringMap = { [string]: number }
```

### Union & Intersection Types
```lua
type StringOrNumber = string | number
type Optional = number?  -- shorthand for number | nil
type Overloaded = ((number) -> string) & ((boolean) -> string)
```

### Type Aliases & Export
```lua
type MyType = { x: number, y: number }
export type PublicType = { name: string }  -- usable via require
```

### Type Casts
```lua
local x = myValue :: number  -- cast to number
```

### Structural Type System
- Luau is structurally typed (checks shape, not name)
- Two tables with same fields are considered compatible

## 4. Standard Library (Luau-specific additions)

### Global Functions
| Function | Signature | Notes |
|---|---|---|
| `assert` | `assert<T>(value: T, msg?: string): T` | Raises error if falsy |
| `error` | `error(obj: any, level?: number)` | `level` attributes error to caller |
| `gcinfo` | `gcinfo(): number` | Heap size in KB |
| `type` | `type(obj): string` | Returns basic type string |
| `typeof` | `typeof(obj): string` | Returns Roblox class name for userdata |
| `pcall` | `pcall(f, ...): (bool, ...any)` | Protected call, f can yield |
| `xpcall` | `xpcall(f, e, ...): (bool, ...any)` | Protected call with error handler |
| `select` | `select('#', ...): number` or `select(i, ...): ...` | |
| `rawequal/rawget/rawset/rawlen` | | Bypass metamethods |
| `tonumber/tostring` | | Standard conversions |

### table Library (Luau additions)
- `table.create(n, value?)` — pre-allocate array
- `table.find(t, value, init?)` — linear search
- `table.clear(t)` — remove all entries
- `table.clone(t)` — shallow copy
- `table.move(src, a, b, t, dst?)` — bulk copy
- `table.freeze(t)` — make read-only (deep check needed separately)
- `table.isfrozen(t)` — check if frozen
- `table.pack(...)` / `table.unpack(t)` — from Lua 5.2+

### string Library
- Standard Lua 5.1 patterns (not regex!)
- `string.split(s, sep)` — Roblox addition
- `string.format` with `%*` format specifiers

### math Library
- `math.clamp(x, min, max)` — Luau addition
- `math.sign(x)` — returns -1, 0, or 1
- `math.round(x)` — round to nearest integer
- `math.noise(x, y?, z?)` — Perlin noise (Roblox)
- Standard: `math.floor`, `math.ceil`, `math.abs`, `math.sqrt`, `math.random`, etc.

### buffer Library (Luau-specific)
- Binary data manipulation without string overhead
- `buffer.create(size)`, `buffer.readi8/readu8/readf32/readf64`, etc.

### vector Library (Luau-specific, when native vectors enabled)
- `vector.create(x, y, z)`
- `vector.magnitude(v)`, `vector.normalize(v)`

## 5. Linter Rules (28 rules)

### Critical Rules to Never Violate:
| # | Name | Description |
|---|---|---|
| 1 | UnknownGlobal | Typos in global variable names |
| 2 | DeprecatedGlobal | Using deprecated globals (e.g., `wait()`, `spawn()`) |
| 3 | GlobalUsedAsLocal | Global that should be `local` |
| 10 | BuiltinGlobalWrite | Overwriting built-in globals like `table` |
| 12 | UnreachableCode | Dead code after return/break |
| 22 | DeprecatedApi | Using deprecated Roblox APIs |
| 25 | MisleadingAndOr | `a and b or c` where `b` could be false/nil |

### Best Practice Rules:
| # | Name | Description |
|---|---|---|
| 4 | LocalShadow | Shadowing variables in same function |
| 7 | LocalUnused | Unused local variables (prefix with `_` to silence) |
| 8 | FunctionUnused | Unused local functions |
| 9 | ImportUnused | Unused `require` results |
| 15 | UnbalancedAssignment | Mismatched left/right side counts |
| 16 | ImplicitReturn | Function sometimes returns, sometimes doesn't |
| 23 | TableOperations | Incorrect use of table library functions |

### Control Directives:
```lua
--!strict          -- Enable strict type checking
--!nonstrict       -- Default mode
--!nocheck         -- Disable type checking
--!nolint          -- Disable ALL lint warnings
--!nolint NAME     -- Disable specific lint warning
```

## 6. Compatibility with Lua

### Based on Lua 5.1 with these REMOVED (sandboxing):
- `io`, `os` (partial), `package`, `debug` (partial) libraries
- `loadfile`, `dofile`, `loadstring`, `string.dump`

### Adopted from Lua 5.2+:
- ✔️ `\z` escape, `__len` for tables, `table.move`, `xpcall` with args
- ✔️ `continue` (not in any Lua), generalized iteration via `__iter`
- ✔️ `bit32` library (kept even though Lua 5.3 removed it)
- ✔️ `utf8` library, `coroutine.isyieldable`
- ✔️ `string.gmatch` optional init, `coroutine.close`
- ❌ `__gc` metamethod (use specific cleanup patterns instead)
- ❌ Integer type / bitwise operators (single number type is better for Luau)
- ❌ Tail call optimization (for better stack traces and security)
- ❌ `<close>` variables

### Key Differences from Standard Lua:
1. **No tail calls** — better debugging/stack traces
2. **Table literal order** follows program order (not array-first)
3. **`__eq`** called even for rawequal objects
4. **`os.time`** returns UTC when called with table
5. **Function closures** may be reused if upvalues match

### Implementation Limits:
- 200 local variables per function
- 200 upvalues per function
- 255 registers per function
- 2^23 constants per function
- 2^23 instructions per function
- 20,000 Lua call stack depth
- 200 C call nesting (pcall/coroutine.resume)

## 7. Performance Best Practices (from luau.org/performance)

### DO:
- Use `local` for frequently accessed globals: `local insert = table.insert`
- Use `table.create(n)` to pre-allocate arrays
- Use `buffer` for binary data instead of string concatenation
- Prefer `table.find()` over manual loops for linear search
- Use `table.freeze()` for constant tables (enables optimizations)
- Let the native code generator handle hot loops

### DON'T:
- Don't use `getfenv`/`setfenv` — breaks optimizations
- Don't store mixed types in arrays — hurts performance
- Don't use `table.insert(t, 1, v)` for prepending — O(n) operation
- Don't create unnecessary closures in hot paths
- Don't use `string.format` in tight loops — use interpolation or buffer

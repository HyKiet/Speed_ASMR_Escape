--!nocheck
-- Shim tối thiểu để nạp ModuleScript của dự án bằng Lune, ngoài Roblox.
--
-- Chỉ giả lập đúng phần các module thuần cần: `script.Parent...` và `require()`
-- đi theo cây thư mục src/, cộng vài datatype Roblox mà file Config có dùng.
-- Bất cứ thứ gì cần engine thật (Instance, service, task) đều KHÔNG nằm trong
-- phạm vi test này — nếu một module cần chúng thì nó không phải hàm thuần và
-- phải test trong Studio.
--
-- Lưu ý kỹ thuật: fs của Lune là hàm async, gọi bên trong __index sẽ nổ
-- "attempt to yield across metamethod/C-call boundary". Vì vậy toàn bộ cây thư
-- mục được quét MỘT LẦN lúc nạp shim, sau đó metamethod chỉ tra bảng.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local ROOT = "src"

local Shim = {}

local dirSet: { [string]: boolean } = {}
local fileSet: { [string]: boolean } = {}

local function scan(path: string)
	dirSet[path] = true
	for _, entry in fs.readDir(path) do
		local childPath = `{path}/{entry}`
		if fs.isDir(childPath) then
			scan(childPath)
		else
			fileSet[childPath] = true
		end
	end
end

scan(ROOT)

local moduleCache: { [string]: any } = {}
local nodeCache: { [string]: any } = {}

-- Color3 giả: giữ đủ r/g/b để so sánh, không cần gì hơn.
local function fromRGB(r: number, g: number, b: number)
	return { R = r / 255, G = g / 255, B = b / 255 }
end

local Color3Stub = {
	fromRGB = fromRGB,
	new = function(r, g, b)
		return { R = r or 0, G = g or 0, B = b or 0 }
	end,
	fromHex = function()
		return { R = 0, G = 0, B = 0 }
	end,
}

local makeNode

-- Tìm con tên `name` bên trong thư mục `dirPath` (chỉ tra bảng, không chạm đĩa).
local function resolveChild(dirPath: string, name: string)
	local asModule = `{dirPath}/{name}.luau`
	if fileSet[asModule] then
		return makeNode(asModule, name)
	end

	local asDir = `{dirPath}/{name}`
	if dirSet[asDir] then
		return makeNode(asDir, name)
	end

	error(`[shim] Không tìm thấy '{name}' trong '{dirPath}'`)
end

-- node đại diện cho một ModuleScript (path là file .luau) hoặc một Folder
-- (path là thư mục). Với thư mục có init.luau, Rojo coi chính nó là module.
function makeNode(path: string, name: string)
	if nodeCache[path] then
		return nodeCache[path]
	end

	local isDirectory = dirSet[path] == true
	local dirForChildren = if isDirectory then path else path:match("^(.*)/[^/]+%.luau$")
	local parentDir = if isDirectory then path:match("^(.*)/[^/]+$") else dirForChildren

	local node = setmetatable({}, {
		__index = function(_, key)
			if key == "Name" then
				return name
			end
			if key == "Parent" then
				if not parentDir or parentDir == "" then
					return nil
				end
				return makeNode(parentDir, parentDir:match("([^/]+)$") or parentDir)
			end
			return resolveChild(dirForChildren, key)
		end,
		__tostring = function()
			return path
		end,
	})

	nodeCache[path] = node
	return node
end

local requireNode

-- Đường nạp thật: đọc file, chạy trong sandbox có `script` và `require` riêng.
local function loadFile(filePath: string, node: any)
	if moduleCache[filePath] then
		return moduleCache[filePath]
	end

	local source = fs.readFile(filePath)
	local chunk = luau.load(source, {
		debugName = filePath,
		environment = {
			script = node,
			require = requireNode,
			Color3 = Color3Stub,
		},
	})

	local result = chunk()
	moduleCache[filePath] = result
	return result
end

function requireNode(target: any)
	local path = tostring(target)

	if dirSet[path] then
		local initPath = `{path}/init.luau`
		if not fileSet[initPath] then
			error(`[shim] '{path}' là thư mục nhưng không có init.luau`)
		end
		return loadFile(initPath, target)
	end

	if not fileSet[path] then
		error(`[shim] Không có file '{path}'`)
	end

	return loadFile(path, target)
end

-- API dùng trong test: Shim.Require("src/shared/Config/Formulas.luau")
function Shim.Require(filePath: string)
	local name = filePath:match("([^/]+)%.luau$") or filePath
	return requireNode(makeNode(filePath, name))
end

Shim.Color3 = Color3Stub

return Shim

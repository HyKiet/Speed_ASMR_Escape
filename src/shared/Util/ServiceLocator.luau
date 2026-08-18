--!strict
-- ServiceLocator: nơi đăng ký tập trung mọi Service/Controller sau khi bootstrapper nạp.
-- Cho phép module ở thư mục con (Core/Gameplay/Zones) gọi nhau mà không cần biết đường dẫn cụ thể.

local ServiceLocator = {}

local registry: { [string]: any } = {}
local waiters: { [string]: { thread } } = {}

function ServiceLocator.Register(name: string, instance: any)
	registry[name] = instance

	local pending = waiters[name]
	if pending then
		waiters[name] = nil
		for _, thread in pending do
			task.spawn(thread, instance)
		end
	end
end

function ServiceLocator.Get(name: string): any
	local instance = registry[name]
	if not instance then
		error(
			`[ServiceLocator] '{name}' chưa được đăng ký. Hãy kiểm tra thứ tự Init hoặc đặt tên file.`,
			2
		)
	end
	return instance
end

function ServiceLocator.Find(name: string): any?
	return registry[name]
end

function ServiceLocator.WaitFor(name: string, timeout: number?): any?
	local existing = registry[name]
	if existing then
		return existing
	end

	local list = waiters[name]
	if not list then
		list = {}
		waiters[name] = list
	end

	local current = coroutine.running()
	table.insert(list, current)

	if timeout then
		task.delay(timeout, function()
			if coroutine.status(current) == "suspended" then
				task.spawn(current, nil)
			end
		end)
	end

	return coroutine.yield()
end

function ServiceLocator.All(): { [string]: any }
	local snapshot = {}
	for key, value in registry do
		snapshot[key] = value
	end
	return snapshot
end

return ServiceLocator

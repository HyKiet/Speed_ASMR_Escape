--!strict
-- ServiceLocator: nơi đăng ký tập trung mọi Service/Controller sau khi bootstrapper nạp.
-- Server và Client có registry riêng; module lấy dependency sau pha đăng ký của bootstrapper.

local ServiceLocator = {}

local registry: { [string]: any } = {}
type Waiter = { thread: thread, timeout: thread? }
local waiters: { [string]: { Waiter } } = {}

function ServiceLocator.Register(name: string, instance: any)
	registry[name] = instance

	local pending = waiters[name]
	if pending then
		waiters[name] = nil
		for _, waiter in pending do
			if waiter.timeout then
				task.cancel(waiter.timeout)
			end
			if coroutine.status(waiter.thread) == "suspended" then
				task.spawn(waiter.thread, instance)
			end
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
	local waiter: Waiter = { thread = current, timeout = nil }
	table.insert(list, waiter)

	if timeout then
		waiter.timeout = task.delay(timeout, function()
			-- Hết hạn phải rời hàng chờ: coroutine có thể đang yield cho việc khác
			-- khi Register tới muộn, nên chỉ kiểm tra trạng thái suspended là chưa đủ.
			local index = table.find(list, waiter)
			if not index then
				return
			end
			table.remove(list, index)
			if #list == 0 then
				waiters[name] = nil
			end
			if coroutine.status(current) == "suspended" then
				task.spawn(current, nil)
			end
		end)
	end

	return coroutine.yield()
end

function ServiceLocator.All(): { [string]: any }
	return table.clone(registry)
end

return ServiceLocator

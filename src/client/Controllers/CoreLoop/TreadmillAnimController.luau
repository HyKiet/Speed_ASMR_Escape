--!strict
--[[
	TreadmillAnimController.luau — Phát hoạt ảnh chạy cho MỌI player đang farm treadmill.

	Server (ProgressionService.SetTreadmillState) đặt attribute "TreadmillFarming" trên
	Player SAU KHI đã validate — attribute replicate tới mọi client, nên mỗi client tự
	phát/tắt animation cục bộ cho tất cả nhân vật đang farm (kể cả chính mình).

	Vì sao không dựa vào auto-replication của AnimationTrack (cách cũ trong HUDController):
	track phát từ LocalScript trên character không replicate ổn định sang máy khác,
	gây lỗi "người khác không thấy anim chạy". Attribute-driven đảm bảo 25 player đồng bộ.

	Chống mọi race (thiết kế tự-hồi-phục):
	  • AttributeChanged/CharacterAdded là tín hiệu chính (event-driven).
	  • VÒNG POLL 1s làm lưới an toàn: attribute=true mà track không chạy (lỡ signal,
	    Animator chưa replicate lúc đó, track bị hệ khác stop, LoadAnimation fail...)
	    → tự thử lại. Attribute=false mà track còn chạy → tự tắt.
	  • LoadAnimation fail với anim custom của avatar → retry bằng anim fallback.
	Chi phí: O(số player) mỗi giây — 25 player không đáng kể.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Roblox R15 Run mặc định — dùng khi character không có Animate.run hoặc anim custom lỗi.
local FALLBACK_RUN_ANIM = "rbxassetid://180426354"
local POLL_INTERVAL = 1.0
local DEBUG = RunService:IsStudio()

local TreadmillAnimController = {}

type Entry = {
	track: AnimationTrack?,
	connections: { RBXScriptConnection },
}

local entries: { [Player]: Entry } = {}
local emoteSuppressed: { [Player]: boolean } = {}

-- Anim chạy THẬT của avatar từng player (từ HumanoidDescription, 1 web call/player, cache).
-- Cần thiết vì `Animate.run` do script Animate tạo LÚC RUNTIME trên máy chính chủ —
-- KHÔNG replicate sang client khác → máy khác sẽ chỉ thấy fallback nếu không có cache này.
local runAnimByUserId: { [number]: string } = {}

local function prefetchRunAnim(player: Player)
	local userId = player.UserId
	if userId < 1 or runAnimByUserId[userId] then
		return
	end
	task.spawn(function()
		local ok, description = pcall(function()
			return Players:GetHumanoidDescriptionFromUserIdAsync(userId)
		end)
		if ok and description then
			-- API có yield; người chơi có thể đã rời server trong lúc chờ.
			if entries[player] and description.RunAnimation > 0 then
				runAnimByUserId[userId] = `rbxassetid://{description.RunAnimation}`
			end
			description:Destroy()
		end
	end)
end

local function stopTrack(player: Player, entry: Entry)
	local track = entry.track
	entry.track = nil
	if track then
		track:Stop(0.15)
		track:Destroy()
		if DEBUG then
			Log.Boot(`[TreadmillAnim] stop {player.Name}`)
		end
	end
end

-- Ưu tiên animation chạy của chính avatar. Thứ tự:
-- 1) Animate.run (runtime — chỉ tồn tại trên máy chính chủ, chính xác nhất)
-- 2) cache HumanoidDescription (máy khác nhìn player này — vẫn đúng anim avatar họ)
-- 3) template tĩnh Animate.R15.run (replicate từ StarterCharacterScripts)
-- 4) fallback R15 Run mặc định
local function getRunAnimId(player: Player, character: Model): string
	local animate = character:FindFirstChild("Animate")
	local runFolder = animate and animate:FindFirstChild("run")
	local runAnim = runFolder and runFolder:FindFirstChildOfClass("Animation")
	if runAnim and runAnim.AnimationId ~= "" then
		return runAnim.AnimationId
	end

	local cached = runAnimByUserId[player.UserId]
	if cached then
		return cached
	end

	local r15 = animate and animate:FindFirstChild("R15")
	local r15run = r15 and r15:FindFirstChild("run")
	local r15anim = r15run and r15run:FindFirstChildOfClass("Animation")
	if r15anim and (r15anim :: Animation).AnimationId ~= "" then
		return (r15anim :: Animation).AnimationId
	end

	return FALLBACK_RUN_ANIM
end

local function loadTrack(animator: Animator, animId: string): AnimationTrack?
	local animation = Instance.new("Animation")
	animation.AnimationId = animId
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	animation:Destroy()
	if ok and track then
		return track
	end
	return nil
end

local function refresh(player: Player)
	local entry = entries[player]
	if not entry then
		return
	end

	local farming = player:GetAttribute("TreadmillFarming") == true and emoteSuppressed[player] ~= true
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")

	if not (farming and character and humanoid and humanoid.Health > 0 and animator) then
		stopTrack(player, entry)
		return
	end

	if entry.track and entry.track.IsPlaying then
		return
	end
	stopTrack(player, entry)

	local track = loadTrack(animator :: Animator, getRunAnimId(player, character :: Model))
	if not track then
		-- Anim custom của avatar lỗi/không quyền → fallback anim Roblox mặc định.
		track = loadTrack(animator :: Animator, FALLBACK_RUN_ANIM)
	end
	if not track then
		if DEBUG then
			Log.Warn(`[TreadmillAnim] LoadAnimation FAILED for {player.Name} — poll will retry`)
		end
		return
	end

	track.Looped = true
	-- Action đè idle/walk mặc định (kể cả anim idle replicate từ máy chính chủ).
	track.Priority = Enum.AnimationPriority.Action
	track:Play(0.15)
	entry.track = track
	if DEBUG then
		Log.Boot(
			`[TreadmillAnim] play {player.Name} ({track.Animation and (track.Animation :: Animation).AnimationId})`
		)
	end
end

local function watchPlayer(player: Player)
	if entries[player] then
		return
	end
	local entry: Entry = { track = nil, connections = {} }
	entries[player] = entry
	prefetchRunAnim(player)

	table.insert(
		entry.connections,
		player:GetAttributeChangedSignal("TreadmillFarming"):Connect(function()
			refresh(player)
		end)
	)
	table.insert(
		entry.connections,
		player.CharacterAdded:Connect(function(character)
			-- Humanoid/Animator replicate SAU character — phải đợi thật sự rồi mới refresh.
			task.spawn(function()
				local humanoid = character:WaitForChild("Humanoid", 10)
				if humanoid then
					humanoid:WaitForChild("Animator", 5)
				end
				if entries[player] and player.Character == character then
					refresh(player)
				end
			end)
		end)
	)
	table.insert(
		entry.connections,
		player.CharacterRemoving:Connect(function()
			stopTrack(player, entry)
		end)
	)

	refresh(player)
end

function TreadmillAnimController.Start()
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player)
		runAnimByUserId[player.UserId] = nil
		local entry = entries[player]
		entries[player] = nil
		emoteSuppressed[player] = nil
		if entry then
			stopTrack(player, entry)
			for _, connection in entry.connections do
				connection:Disconnect()
			end
		end
	end)

	-- Lưới an toàn: tự hồi phục mọi trạng thái lệch (lỡ signal, Animator vào muộn,
	-- track bị stop bởi hệ khác, LoadAnimation fail tạm thời...).
	task.spawn(function()
		while true do
			task.wait(POLL_INTERVAL)
			for player, entry in entries do
				local farming = player:GetAttribute("TreadmillFarming") == true and emoteSuppressed[player] ~= true
				local playing = entry.track ~= nil and (entry.track :: AnimationTrack).IsPlaying
				if farming ~= playing then
					refresh(player)
				end
			end
		end
	end)

	if DEBUG then
		Log.Boot("[TreadmillAnim] ready — attribute-driven + 1s self-healing poll")
	end
end

-- Emote đang chạy thì vòng tự hồi phục không được khởi động lại animation treadmill.
function TreadmillAnimController.SetEmoteSuppressed(player: Player, suppressed: boolean)
	if suppressed then
		emoteSuppressed[player] = true
	else
		emoteSuppressed[player] = nil
	end
	refresh(player)
end

return TreadmillAnimController

--!strict
--[[
	EmoteController — PHẦN CHẠY ĐỘNG TÁC, không còn phần vẽ.

	Bảng chọn emote đã chuyển sang `HUD/Modals/EmoteModal` để nó dùng chung khuôn (và chung
	`ScreenGui`) với 12 modal còn lại — lý do đầy đủ nằm ở đầu file đó. Ở đây chỉ còn ba việc:

	    • nạp / dừng `AnimationTrack` cho mọi người chơi trong tầm nhìn;
	    • nghe `emoteBroadcast` (ai đang nhảy gì) và `emoteState` (mình sở hữu những gì);
	    • phím G mở/đóng bảng.

	Danh sách đã mở khoá đổ vào `State.emoteUnlocked` thay vì một `Value` cấp module ở đây, để
	`EmoteModal` đọc thẳng từ `State` như mọi modal khác (xem khối lý do ở `HUD/State`).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Emotes = require(ReplicatedStorage.Shared.Config.Economy.Emotes)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local State = require(script.Parent.Parent.HUD.State)
local Manager = require(script.Parent.Parent.HUD.Modals.Manager)
local TreadmillAnimController = require(script.Parent.Parent.CoreLoop.TreadmillAnimController)

local EmoteController = {}
local localPlayer = Players.LocalPlayer

type ActiveVisual = {
	track: AnimationTrack,
	animateScript: LocalScript?,
	animateWasDisabled: boolean,
	connections: { RBXScriptConnection },
}

local visuals: { [number]: ActiveVisual } = {}
local warnedAssets: { [string]: boolean } = {}
local sweeper = Janitor.new()

local function findConfig(id: string): any
	for _, config in Emotes.CATALOG do
		if config.id == id then
			return config
		end
	end
	return nil
end

local function stopTrack(userId: number)
	local visual = visuals[userId]
	if visual then
		-- Xóa ownership trước vì Track.Stopped có thể chạy đồng bộ từ Stop().
		visuals[userId] = nil
		for _, connection in visual.connections do
			connection:Disconnect()
		end
		visual.track:Stop(0.12)
		visual.track:Destroy()
		if visual.animateScript and visual.animateScript.Parent then
			visual.animateScript.Disabled = visual.animateWasDisabled
		end
		local player = Players:GetPlayerByUserId(userId)
		if player then
			TreadmillAnimController.SetEmoteSuppressed(player, false)
		end
	end
end

local function playTrack(userId: number, emoteId: string)
	stopTrack(userId)
	local config = findConfig(emoteId)
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not config or not humanoid then
		return
	end

	local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	local remoteRoot = character and character:FindFirstChild("HumanoidRootPart")
	if
		userId ~= localPlayer.UserId
		and localRoot
		and localRoot:IsA("BasePart")
		and remoteRoot
		and remoteRoot:IsA("BasePart")
		and (localRoot.Position - remoteRoot.Position).Magnitude > 180
	then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- Emote là animation owner duy nhất trong lúc chạy.
	TreadmillAnimController.SetEmoteSuppressed(player :: Player, true)
	local animate = character and character:FindFirstChild("Animate")
	local animateScript = if animate and animate:IsA("LocalScript") then animate else nil
	local animateWasDisabled = if animateScript then animateScript.Disabled else false
	if animateScript then
		animateScript.Disabled = true
	end
	for _, playingTrack in animator:GetPlayingAnimationTracks() do
		if playingTrack.Priority.Value <= Enum.AnimationPriority.Movement.Value then
			playingTrack:Stop(0.1)
		end
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = `rbxassetid://{config.assetId}`
	local ok, result = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	animation:Destroy()
	if not ok then
		if animateScript and animateScript.Parent then
			animateScript.Disabled = animateWasDisabled
		end
		TreadmillAnimController.SetEmoteSuppressed(player :: Player, false)
		if not warnedAssets[emoteId] then
			warnedAssets[emoteId] = true
			warn(`[EmoteController] Không tải được {emoteId}: {result}`)
		end
		return
	end

	local track = result :: AnimationTrack
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	local visual: ActiveVisual = {
		track = track,
		animateScript = animateScript,
		animateWasDisabled = animateWasDisabled,
		connections = {},
	}
	visuals[userId] = visual
	table.insert(
		visual.connections,
		animator.AnimationPlayed:Connect(function(otherTrack: AnimationTrack)
			if visuals[userId] == visual and otherTrack ~= track then
				otherTrack:Stop(0)
			end
		end)
	)
	table.insert(
		visual.connections,
		track.Stopped:Connect(function()
			if visuals[userId] == visual then
				stopTrack(userId)
			end
		end)
	)
	table.insert(
		visual.connections,
		(player :: Player).CharacterRemoving:Connect(function(removingCharacter: Model)
			if removingCharacter == character then
				stopTrack(userId)
			end
		end)
	)
	table.insert(
		visual.connections,
		humanoid.Died:Connect(function()
			stopTrack(userId)
		end)
	)
	track:Play(0.12)
	for _, playingTrack in animator:GetPlayingAnimationTracks() do
		if playingTrack ~= track then
			playingTrack:Stop(0.1)
		end
	end
end

function EmoteController.Init() end

function EmoteController.Start()
	sweeper:Add(UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == Enum.KeyCode.G then
			Manager.ToggleEmote()
		end
	end))

	local stateListener = GamePackets.emoteState.listen(function(payload)
		State.emoteUnlocked:set(payload.unlocked)
	end)
	local broadcastListener = GamePackets.emoteBroadcast.listen(function(payload)
		if payload.action == "play" then
			playTrack(payload.userId, payload.emoteId)
		else
			stopTrack(payload.userId)
		end
	end)
	sweeper:Add(function()
		GamePackets.emoteState.disconnect(stateListener)
		GamePackets.emoteBroadcast.disconnect(broadcastListener)
		for userId in visuals do
			stopTrack(userId)
		end
	end)
	GamePackets.requestEmoteAction.send({ action = "state", emoteId = "" })
end

return EmoteController

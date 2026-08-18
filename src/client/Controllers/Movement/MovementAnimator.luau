--!strict
--[[
	MovementAnimator.luau — animation cho hệ di chuyển.

	Chỉ còn animation ACTION (Slide). Locomotion (đi/chạy/nhảy) để nguyên cho script
	"Animate" mặc định của Roblox xử lý — bản cũ có cơ chế tráo AnimationId sang "Walk F"/
	"Sprint F" nhưng đã bị tắt từ lâu, chỉ còn lại code chết nên bỏ hẳn.

	WARM-UP: PreloadAsync chỉ tải BYTE của asset; track và pose vẫn nạp lười ở lần phát
	đầu tiên nên vẫn khựng một nhịp. Cách triệt để là LoadAnimation + Play ở WEIGHT 0
	(vô hình) để engine dựng sẵn track, rồi dừng. Warm CẢ anim mặc định trong script
	Animate, nếu không thì 1-2 giây đầu sau khi spawn nhân vật đứng T-pose.
]]

local ContentProvider = game:GetService("ContentProvider")

local MovementConfig = require(script.Parent.MovementConfig)
local MovementTypes = require(script.Parent.MovementTypes)

type Session = MovementTypes.Session

local MovementAnimator = {}

local function fadeFor(name: string): number
	return MovementConfig.AnimFade[name] or MovementConfig.AnimFade.Default
end

local function collectAnimateAssetIds(character: Model): { string }
	local ids: { string } = {}
	local animate = character:FindFirstChild("Animate") or character:WaitForChild("Animate", 3)
	if animate then
		for _, descendant in animate:GetDescendants() do
			if descendant:IsA("Animation") and descendant.AnimationId ~= "" then
				table.insert(ids, descendant.AnimationId)
			end
		end
	end
	return ids
end

local function warmAnimations(session: Session)
	local assetIds: { string } = {}
	for _, assetId in MovementConfig.Animations do
		table.insert(assetIds, assetId)
	end
	for _, assetId in collectAnimateAssetIds(session.character) do
		table.insert(assetIds, assetId)
	end

	local anims: { Animation } = {}
	for _, assetId in assetIds do
		local anim = Instance.new("Animation")
		anim.AnimationId = assetId
		table.insert(anims, anim)
	end
	pcall(function()
		ContentProvider:PreloadAsync(anims)
	end)

	local warmed: { { track: AnimationTrack, anim: Animation } } = {}
	for _, anim in anims do
		local ok, track = pcall(function()
			return session.animator:LoadAnimation(anim)
		end)
		if ok and track then
			track.Priority = Enum.AnimationPriority.Core -- thấp nhất, không đè anim thật
			track:Play(0, 0, 1) -- fade 0, WEIGHT 0 → vô hình nhưng vẫn dựng track + pose
			table.insert(warmed, { track = track, anim = anim })
		else
			anim:Destroy()
		end
	end

	task.delay(0.5, function()
		for _, w in warmed do
			pcall(function()
				w.track:Stop(0)
				w.track:Destroy()
			end)
			w.anim:Destroy()
		end
	end)
end

function MovementAnimator.Setup(session: Session)
	session.tracks = {}

	for name, assetId in MovementConfig.Animations do
		local anim = Instance.new("Animation")
		anim.Name = "Movement_" .. name
		anim.AnimationId = assetId

		local track = session.animator:LoadAnimation(anim)
		track.Priority = Enum.AnimationPriority.Action -- đè anim chạy/nhảy mặc định
		-- BẮT BUỘC: asset slide bật Looped sẵn, mà slide kéo dài 0.55–1.6s nên anim
		-- chạy hết một vòng rồi phát lại → nhìn thành "2 nhịp". Track phải tự tắt.
		track.Looped = false
		session.tracks[name] = track

		session.sweeper:Add(track, "Destroy")
		session.sweeper:Add(anim, "Destroy")
	end

	-- Chạy nền: collectAnimateAssetIds có thể chờ script Animate replicate tới 3s,
	-- không được chặn việc dựng session.
	task.spawn(warmAnimations, session)
end

function MovementAnimator.PlayAction(session: Session, name: string)
	local fade = fadeFor(name)
	for trackName, track in session.tracks do
		if trackName ~= name and track.IsPlaying then
			track:Stop(fade)
		end
	end
	local track = session.tracks[name]
	if track and not track.IsPlaying then
		track:Play(fade)
	end
end

function MovementAnimator.StopAction(session: Session, name: string)
	local track = session.tracks[name]
	if track and track.IsPlaying then
		track:Stop(fadeFor(name))
	end
end

return MovementAnimator

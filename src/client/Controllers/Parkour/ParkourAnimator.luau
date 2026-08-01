--!strict
--[[
	ParkourAnimator.luau — Quản lý toàn bộ Animation cho Kinetic Parkour.

	2 loại animation:
	  1) Action animations (Slide / WallRun): nạp qua Animator:LoadAnimation, ưu tiên Action để đè
	     lên anim di chuyển mặc định. PHÁT với fadeTime (~0.15s) để hòa trộn mượt.
	  2) Locomotion (Walk / Sprint): KHÔNG nạp track riêng. Thay vào đó tráo AnimationId trong
	     script "Animate" của nhân vật:
	       • walk.WalkAnim  → luôn dùng "Walk F" (anim đi bộ mới).
	       • run.RunAnim    → tráo sang "Sprint F" khi WalkSpeed vượt ngưỡng, ngược lại trả về gốc.
	     Nhờ vậy tốc độ phát tự scale theo vận tốc, mượt và không xung đột.

	NOTE: anim nào KHÔNG được nạp thành track Action thì khai báo trong LOCOMOTION_ANIMS bên dưới.
]]

local ParkourConfig = require(script.Parent.ParkourConfig)
local ParkourTypes = require(script.Parent.ParkourTypes)

type Session = ParkourTypes.Session

-- Các anim xử lý qua script Animate (không nạp thành track Action).
local LOCOMOTION_ANIMS = { SprintF = true, WalkF = true }

local ParkourAnimator = {}

-- PRELOAD 1 LẦN khi client khởi động: nạp sẵn mọi Animation của game vào cache để
-- LẦN PHÁT ĐẦU TIÊN không bị "khựng nhẹ" (hitch do tải/replicate animation lần đầu).
local preloadStarted = false
local function preloadAnimationsOnce()
	if preloadStarted then
		return
	end
	preloadStarted = true
	task.spawn(function()
		local ContentProvider = game:GetService("ContentProvider")
		local anims: { Animation } = {}
		for _, assetId in ParkourConfig.Animations do
			local anim = Instance.new("Animation")
			anim.AnimationId = assetId
			table.insert(anims, anim)
		end
		pcall(function()
			ContentProvider:PreloadAsync(anims)
		end)
		for _, anim in anims do
			anim:Destroy()
		end
	end)
end
preloadAnimationsOnce()

local function fadeFor(name: string): number
	return ParkourConfig.AnimFade[name] or ParkourConfig.AnimFade.Default
end

-- Lấy reference tới các Animation con bên trong script "Animate".
local function getAnimateAnim(character: Model, folderName: string, animName: string): Animation?
	local animate = character:FindFirstChild("Animate")
	if not animate then
		return nil
	end
	local folder = animate:FindFirstChild(folderName)
	local anim = folder and folder:FindFirstChild(animName)
	if anim and anim:IsA("Animation") then
		return anim
	end
	return nil
end

-- Buộc script Animate đọc lại AnimationId vừa tráo (chỉ khi chạm đất, tránh quấy rối lúc bay).
local function refreshAnimate(session: Session)
	if session.humanoid.FloorMaterial ~= Enum.Material.Air then
		session.humanoid:ChangeState(Enum.HumanoidStateType.Running)
	end
end

-- WARM mọi animation NGAY trên Animator của nhân vật để khử "khựng nhẹ" lần đầu.
-- PreloadAsync chỉ tải BYTE asset; track + pose vẫn nạp lười lúc phát đầu (gây khựng).
-- Cách triệt để: LoadAnimation + Play ở WEIGHT 0 (vô hình) để engine tạo track & cache pose,
-- rồi dừng. Lần đầu Walk F / Sprint F / Slide / Wall Run phát sẽ mượt ngay.
--
-- FIX "vào game 1-2s đầu nhân vật không có animation": warm CẢ animation mặc định trong
-- script Animate (run/walk/jump/idle/fall...) — trước đây chỉ warm anim parkour nên các
-- anim locomotion mặc định vẫn nạp lười, gây T-pose/đứng đơ lúc mới spawn.
local function collectAnimateAssetIds(character: Model): { string }
	local ids: { string } = {}
	local animate = character:FindFirstChild("Animate")
		or character:WaitForChild("Animate", 3)
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
	for _, assetId in ParkourConfig.Animations do
		table.insert(assetIds, assetId)
	end
	for _, assetId in collectAnimateAssetIds(session.character) do
		table.insert(assetIds, assetId)
	end

	-- Tải byte asset trước (nhanh, chạy nền)...
	task.spawn(function()
		local ContentProvider = game:GetService("ContentProvider")
		local anims: { Animation } = {}
		for _, assetId in assetIds do
			local anim = Instance.new("Animation")
			anim.AnimationId = assetId
			table.insert(anims, anim)
		end
		pcall(function()
			ContentProvider:PreloadAsync(anims)
		end)
		for _, anim in anims do
			anim:Destroy()
		end
	end)

	-- ...rồi warm track + pose trên Animator.
	local warmed: { { track: AnimationTrack, anim: Animation } } = {}
	for _, assetId in assetIds do
		local anim = Instance.new("Animation")
		anim.AnimationId = assetId
		local ok, track = pcall(function()
			return session.animator:LoadAnimation(anim)
		end)
		if ok and track then
			track.Priority = Enum.AnimationPriority.Core -- thấp nhất, không đè anim thật
			track:Play(0, 0, 1) -- fade 0, WEIGHT 0 (không hiển thị), speed 1 → vẫn nạp data+track
			table.insert(warmed, { track = track, anim = anim })
		else
			anim:Destroy()
		end
	end
	-- Dừng + dọn sau khi đã warm xong (đủ 1 nhịp để engine nạp track).
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

-- Nạp các Action animation và lưu vào session.tracks.
function ParkourAnimator.Setup(session: Session)
	session.tracks = {}

	for name, assetId in ParkourConfig.Animations do
		if LOCOMOTION_ANIMS[name] then
			continue -- xử lý riêng qua Animate, không cần track
		end

		local anim = Instance.new("Animation")
		anim.Name = "Parkour_" .. name
		anim.AnimationId = assetId

		local track = session.animator:LoadAnimation(anim)
		-- Ưu tiên Action để đè anim chạy/nhảy mặc định khi đang thực hiện kỹ năng.
		track.Priority = Enum.AnimationPriority.Action
		-- Mọi anim Wall Run (Right/Left/Idle) đều lặp cho tới khi rời tường.
		track.Looped = string.sub(name, 1, 7) == "WallRun"
		session.tracks[name] = track

		session.janitor:Add(track, "Destroy")
		session.janitor:Add(anim, "Destroy")
	end

	-- Thay anim đi bộ mặc định bằng "Walk F" ngay từ đầu. (ĐÃ TẮT để sử dụng mặc định của Roblox)
	-- local walkAnim = getAnimateAnim(session.character, "walk", "WalkAnim")
	-- if walkAnim then
	-- 	session.originalWalkAnimId = walkAnim.AnimationId
	-- 	walkAnim.AnimationId = ParkourConfig.Animations.WalkF
	-- 	refreshAnimate(session)
	-- end

	-- Warm mọi anim để lần phát đầu không khựng. Chạy nền: collectAnimateAssetIds
	-- có thể chờ script Animate replicate (tối đa 3s), không được chặn buildSession.
	task.spawn(warmAnimations, session)
end

-- Phát 1 Action animation, dừng các Action khác để tránh chồng tư thế. Dùng fadeTime để hòa trộn.
function ParkourAnimator.PlayAction(session: Session, name: string)
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

-- Dừng 1 Action animation cụ thể (có fade).
function ParkourAnimator.StopAction(session: Session, name: string)
	local track = session.tracks[name]
	if track and track.IsPlaying then
		track:Stop(fadeFor(name))
	end
end

-- Bật/tắt chế độ Sprint dựa trên WalkSpeed. Gọi mỗi frame.
-- Chỉ tráo RUN ↔ Sprint F; WALK luôn giữ Walk F (đã set ở Setup).
function ParkourAnimator.UpdateSprint(session: Session)
	-- Đã vô hiệu hóa: sử dụng hoạt ảnh chạy mặc định của Roblox.
end

return ParkourAnimator

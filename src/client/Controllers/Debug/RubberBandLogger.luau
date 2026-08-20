--!strict
--[[
	RubberBandLogger.luau — CHỈ CHẠY TRONG STUDIO. Bắt tận tay thứ đang kéo người chơi lùi lại.

	── VÌ SAO CÓ FILE NÀY ──────────────────────────────────────────────────────────────────
	User báo 2026-08-19: chạy ở WalkSpeed cao thì bị "tele về một đoạn vừa chạy". Phiên điều
	tra hôm đó loại trừ được nhiều nghi phạm bằng đo đạc (AntiCheat không nổ một dòng nào,
	`TerrainDrag` không script nào ghi, mọi teleport server đều đã báo AntiCheat, vạch Start
	không teleport) nhưng KHÔNG tái hiện được triệu chứng — cửa sổ Studio chạy qua MCP không
	có focus nên render bị bóp còn ~9–15 FPS, và nhân vật chỉ chạy quanh Zone 1.

	Nên đổi cách: thay vì đoán tiếp, ghi lại đúng khoảnh khắc nó xảy ra trên máy người tái
	hiện được. Logger này chạy trong phiên test bình thường, không cần thao tác gì.

	── ĐO CÁI GÌ ───────────────────────────────────────────────────────────────────────────
	1. GIẬT LÙI — chiếu vector dịch chuyển mỗi frame lên HƯỚNG ĐANG CHẠY, chỉ lấy phần ÂM.

	   ⚠️ Đây là điểm mấu chốt, và là chỗ phép đo đầu tiên đã sai: dùng ngưỡng "nhảy > N
	   studs" TUYỆT ĐỐI thì ở 250 studs/s với 15 FPS, mỗi frame đi 17 studs là bình thường —
	   ngưỡng tuyệt đối báo động giả hàng loạt và chôn mất tín hiệu thật. Chạy tới thì thành
	   phần lùi luôn ≈ 0 bất kể FPS, nên phép chiếu này sạch ở mọi tốc độ khung hình.

	2. ĐƠ — người chơi ĐANG giữ phím đi (`MoveDirection` khác 0) và WalkSpeed cao, mà nhân
	   vật gần như không nhúc nhích quá `FREEZE_SECONDS`. Đây là dấu hiệu của streaming
	   integrity (`PauseOutsideLoadedArea` đóng băng nhân vật chờ nạp địa hình), khác hẳn
	   giật lùi nên phải tách ra.

	── QUY THỦ PHẠM ────────────────────────────────────────────────────────────────────────
	Server đóng dấu mốc thời gian lên chính Player mỗi khi nó chủ động dời người chơi (xem
	`AntiCheatService`). Attribute nằm trên Instance nên client đọc được, và cả hai phía đều
	dùng `workspace:GetServerTimeNow()` — một đồng hồ chung, không lệch như `os.clock()`.

	    HỒI SINH        nhân vật vừa thay trong 1 giây qua
	    ANTICHEAT       `DbgBandAt` vừa đóng dấu → chính anti-cheat giật ngược
	    TELEPORT SERVER `DbgTeleportAt` vừa đóng dấu → teleport hợp lệ (pad/revive/stage)
	    STREAMING       không dấu nào, VÀ không có mặt đất dưới chân → vùng chưa stream về
	    KHÔNG RÕ        không dấu nào, mà đất vẫn còn → engine tự sửa vị trí

	Bốn nhánh đầu dẫn tới bốn hướng chữa HOÀN TOÀN KHÁC NHAU, nên phân biệt được là xong
	nửa việc.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Lùi bao nhiêu studs trong MỘT frame thì tính là giật ngược. Chạy tới bình thường cho phần
-- lùi ≈ 0 (đo thật: lùi lớn nhất 0.0 studs trong 131 frame), nên 8 là rất rộng rãi.
local BACKWARD_STUDS = 8
--[[
	Đứng im lâu hơn ngần này giây TRONG KHI đang giữ phím đi = đơ.

	0.5 chứ không phải 0.25: ở 0.25 thì HÚC VÀO TƯỜNG cũng kêu — đo thật trong Studio, bot
	test chạy thẳng vào vách Lobby là ra ngay một dòng. Đó là phát hiện ĐÚNG cơ chế nhưng
	SAI nguyên nhân, và nó làm loãng đúng thứ ta đang săn. Streaming pause thì đóng băng lâu
	hơn nhiều (phải chờ nạp cả một vùng), nên 0.5 vẫn bắt được mà bỏ qua phần lớn va chạm.
	Dòng log vẫn ghi rõ "đất còn — nghi va chạm" để phân biệt nốt.
]]
local FREEZE_SECONDS = 0.5
-- Đang giữ phím đi mà đi được ít hơn ngần này studs/giây thì coi như không nhúc nhích.
local FREEZE_SPEED = 4
-- Chỉ soi khi tốc độ đủ cao — ở WalkSpeed thấp thì hai triệu chứng này không tồn tại.
local MIN_WALK_SPEED = 60
-- Dấu của server còn "tươi" trong bao lâu thì được tính là nguyên nhân.
local STAMP_WINDOW = 1.0
-- Trần số dòng in ra, để một lỗi lặp lại không làm ngập Output.
local MAX_EVENTS = 40

local RubberBandLogger = {}

local player = Players.LocalPlayer

local function groundBelow(position: Vector3, character: Model?): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if character then { character } else {}
	return Workspace:Raycast(position, Vector3.new(0, -200, 0), params) ~= nil
end

function RubberBandLogger.Init() end

function RubberBandLogger.Start()
	-- ⚠️ Studio-only. Đây là công cụ chẩn đoán, không phải tính năng — đừng để nó chạy ở Live.
	if not RunService:IsStudio() then
		return
	end

	local events = 0
	local character: Model? = nil
	local humanoid: Humanoid? = nil
	local root: BasePart? = nil
	local spawnedAt = 0

	local lastPos: Vector3? = nil
	local heading: Vector3? = nil
	local stuckSince: number? = nil
	local frozenReported = false

	--[[
		⚠️ CHỈ ghi nhớ Model, KHÔNG tra Humanoid/HumanoidRootPart ở đây.

		`CharacterAdded` nổ ngay khi model được parent — con của nó replicate về client SAU
		đó vài khung hình. Bản đầu của file này gọi `FindFirstChild("HumanoidRootPart")` ngay
		trong `bind`, nhận `nil`, rồi giữ `nil` VĨNH VIỄN cho cả đời nhân vật đó ⇒ logger
		chết câm từ lần hồi sinh đầu tiên mà vẫn in dòng "đang chạy". Đã dính thật: phép đối
		chứng ép AntiCheat giật ngược 260 studs (đo được ở server) mà logger không ghi một
		dòng nào.

		Giờ tra LƯỜI ở trong vòng lặp, chỉ khi đang `nil`. `FindFirstChild` mỗi frame trong
		vài frame đầu là chi phí không đáng kể, và đây là công cụ Studio-only.
	]]
	local function bind(newCharacter: Model)
		character = newCharacter
		humanoid = nil
		root = nil
		spawnedAt = Workspace:GetServerTimeNow()
		lastPos, heading, stuckSince, frozenReported = nil, nil, nil, false
	end

	local function resolveParts(): (Humanoid?, BasePart?)
		local model = character
		if not model or not model.Parent then
			return nil, nil
		end
		if not humanoid then
			humanoid = model:FindFirstChildOfClass("Humanoid")
		end
		if not root then
			root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		end
		return humanoid, root
	end

	if player.Character then
		bind(player.Character)
	end
	player.CharacterAdded:Connect(bind)

	local function blame(now: number, position: Vector3): string
		if now - spawnedAt < STAMP_WINDOW then
			return "HỒI SINH (nhân vật vừa thay — bình thường)"
		end

		local bandAt = player:GetAttribute("DbgBandAt")
		if typeof(bandAt) == "number" and now - bandAt < STAMP_WINDOW then
			return `ANTICHEAT — {tostring(player:GetAttribute("DbgBandReason"))}`
		end

		local teleportAt = player:GetAttribute("DbgTeleportAt")
		if typeof(teleportAt) == "number" and now - teleportAt < STAMP_WINDOW then
			return "TELEPORT SERVER (pad / revive / stage / teleport modal)"
		end

		if not groundBelow(position, character) then
			return "STREAMING — không có mặt đất dưới chân, vùng chưa stream về"
		end

		return "KHÔNG RÕ — không dấu server nào, đất vẫn còn ⇒ nghi engine tự sửa vị trí"
	end

	local function report(kind: string, detail: string, position: Vector3)
		events += 1
		if events > MAX_EVENTS then
			return
		end
		local hum = humanoid
		warn(
			string.format(
				"[RubberBand] %s | %s | WS=%.0f | stage=%s | pos=(%.0f, %.0f, %.0f)%s",
				kind,
				detail,
				if hum then hum.WalkSpeed else -1,
				tostring(player:GetAttribute("ActiveStage")),
				position.X,
				position.Y,
				position.Z,
				if events == MAX_EVENTS then "  ← ĐỦ 40 DÒNG, NGỪNG GHI" else ""
			)
		)
	end

	RunService.RenderStepped:Connect(function(dt: number)
		local hum, rootPart = resolveParts()
		if not hum or not rootPart or not rootPart.Parent or hum.Health <= 0 then
			lastPos = nil
			return
		end
		if hum.WalkSpeed < MIN_WALK_SPEED then
			lastPos = nil
			return
		end

		local position = rootPart.Position
		local now = Workspace:GetServerTimeNow()

		local previous = lastPos
		lastPos = position
		if not previous then
			return
		end

		local delta = Vector3.new(position.X - previous.X, 0, position.Z - previous.Z)
		local travelled = delta.Magnitude

		-- ── GIẬT LÙI ──────────────────────────────────────────────────────────────────
		local currentHeading = heading
		if currentHeading then
			local backward = -delta:Dot(currentHeading)
			if backward > BACKWARD_STUDS then
				report(
					"GIẬT LÙI",
					string.format("%.0f studs ngược hướng chạy → %s", backward, blame(now, position)),
					position
				)
				heading = nil
				return
			end
		end
		-- Hướng chạy chỉ cập nhật khi thật sự đang tiến — đứng im hay xoay tại chỗ thì giữ
		-- hướng cũ, nếu không cú giật lùi sẽ tự nó định nghĩa lại "phía trước" và tàng hình.
		if travelled > dt * hum.WalkSpeed * 0.5 then
			heading = delta.Unit
		end

		-- ── ĐƠ ────────────────────────────────────────────────────────────────────────
		local wantsToMove = hum.MoveDirection.Magnitude > 0.05
		if wantsToMove and travelled < FREEZE_SPEED * dt then
			stuckSince = stuckSince or now
			if not frozenReported and now - (stuckSince :: number) >= FREEZE_SECONDS then
				frozenReported = true
				--[[
					⚠️ CÒN ĐẤT DƯỚI CHÂN THÌ IM LẶNG (chốt 2026-08-19 sau khi user chạy thật).

					Người chơi ghì phím vào một vật cản là chuyện BÌNH THƯỜNG, không phải sự cố.
					Zone 10 lấy đúng cái đó làm cơ chế: bệ trồi lên chặn đường, người chơi khựng
					lại vài phần giây. Bản trước báo cả trường hợp này nên chạy qua Zone 10 là
					Output kêu đều đặn — mà một cảnh báo luôn kêu ở chỗ không có lỗi thì chỉ dạy
					người đọc phớt lờ nó, rồi lần có lỗi thật cũng bị bỏ qua.

					Thứ ĐÁNG báo là đóng băng KHÔNG do va chạm: không có gì dưới chân mà nhân vật
					vẫn không nhúc nhích ⇒ streaming integrity đang giữ người chơi chờ nạp địa
					hình (`PauseOutsideLoadedArea`). Đó mới là sự cố, và nó tự phân biệt được.
				]]
				if not groundBelow(position, character) then
					report(
						"ĐƠ",
						string.format(
							"giữ phím đi %.2fs mà không nhúc nhích, KHÔNG có đất dưới chân → STREAMING pause",
							now - (stuckSince :: number)
						),
						position
					)
				end
			end
		else
			stuckSince = nil
			frozenReported = false
		end
	end)

	print(
		"[RubberBand] Logger đang chạy (chỉ Studio). Chạy tốc độ cao rồi soi dòng [RubberBand] trong Output."
	)
end

return RubberBandLogger

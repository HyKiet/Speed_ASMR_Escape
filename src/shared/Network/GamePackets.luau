--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ByteNet = require(ReplicatedStorage.Packages.ByteNet)

return ByteNet.defineNamespace("speedEscape", function()
	return {
		profileSnapshot = ByteNet.definePacket({
			value = ByteNet.struct({
				isLoaded = ByteNet.bool,
				speed = ByteNet.float64,
				totalWins = ByteNet.float64,
				currentRunWins = ByteNet.float64,
				streak = ByteNet.uint16,
				personalBestRunWins = ByteNet.float64,
				highestCompletedStage = ByteNet.uint16,
				level = ByteNet.uint16,
				xp = ByteNet.float64,
				requiredXP = ByteNet.float64,
				rebirths = ByteNet.uint16,
				-- Phí Wins của lần trùng sinh KẾ TIẾP (GDD 3.0 §3.4). float64 vì ở R20 phí đã
				-- là 32 tỉ — uint32 tràn từ R17.
				rebirthWinsCost = ByteNet.float64,
				maxWalkSpeed = ByteNet.float32,
				customSpeedLimit = ByteNet.float32,
				gainMultiplier = ByteNet.float32,
				treadmillMultiplier = ByteNet.float32,
				speedPassMultiplier = ByteNet.float32,
				vipMultiplier = ByteNet.float32,
				premiumMultiplier = ByteNet.float32,
				trailMultiplier = ByteNet.float32,
				auraMultiplier = ByteNet.float32,
				cosmeticMultiplier = ByteNet.float32,
				rebirthMultiplier = ByteNet.float32,
				friendsMultiplier = ByteNet.float32,
				serverMultiplier = ByteNet.float32,
				liveOpsMultiplier = ByteNet.float32,
				friendsInServer = ByteNet.uint8,
				isOnTreadmill = ByteNet.bool,
				canRebirth = ByteNet.bool,
				requiredRebirthLevel = ByteNet.uint16,
				-- Auto-Rebirth: `owns` do gamepass quyết định, `enabled` là công tắc người
				-- chơi tự bật/tắt (chỉ có tác dụng khi owns = true).
				ownsAutoRebirth = ByteNet.bool,
				autoRebirthEnabled = ByteNet.bool,
				activeTreadmillId = ByteNet.string,
				equippedTrail = ByteNet.string,
				equippedAura = ByteNet.string,
				unlockedTrails = ByteNet.map(ByteNet.string, ByteNet.bool),
				unlockedAuras = ByteNet.map(ByteNet.string, ByteNet.bool),
			}),
		}),
		requestSnapshot = ByteNet.definePacket({
			value = ByteNet.struct({}),
		}),
		requestRebirth = ByteNet.definePacket({
			value = ByteNet.struct({}),
		}),
		-- Bật/tắt Auto-Rebirth. Server tự bỏ qua nếu người chơi chưa có gamepass.
		requestAutoRebirthToggle = ByteNet.definePacket({
			value = ByteNet.struct({
				enabled = ByteNet.bool,
			}),
		}),
		requestCustomSpeed = ByteNet.definePacket({
			value = ByteNet.struct({
				walkSpeed = ByteNet.float32,
			}),
		}),
		requestCosmeticAction = ByteNet.definePacket({
			value = ByteNet.struct({
				category = ByteNet.string,
				itemId = ByteNet.string,
			}),
		}),
		requestTeleport = ByteNet.definePacket({
			value = ByteNet.struct({
				destinationId = ByteNet.string,
				paymentKind = ByteNet.string,
			}),
		}),
		reviveOffer = ByteNet.definePacket({
			value = ByteNet.struct({
				stage = ByteNet.uint8,
				durationSeconds = ByteNet.uint8,
				robuxProductId = ByteNet.float64,
				robuxPrice = ByteNet.uint16,
				adRewardProductId = ByteNet.float64,
				-- Gamepass Infinite Revives: hồi sinh MIỄN PHÍ, không giới hạn số lần.
				freeRevive = ByteNet.bool,
			}),
		}),
		requestRevive = ByteNet.definePacket({
			value = ByteNet.struct({
				method = ByteNet.string,
			}),
		}),
		-- Zone 13 — Cổng Thủy Tinh Cyber.
		-- Client báo "tôi vừa đâm vào tấm này"; server tự đọc WalkSpeed phía mình
		-- để duyệt (không tin con số nào do client gửi lên).
		requestGlassSmash = ByteNet.definePacket({
			value = ByteNet.struct({
				wallName = ByteNet.string,
			}),
		}),
		-- Server phát cho mọi client để dựng mảnh vỡ 3D + SFX tại chỗ.
		glassShattered = ByteNet.definePacket({
			value = ByteNet.struct({
				wallName = ByteNet.string,
				hitX = ByteNet.float32,
				hitY = ByteNet.float32,
				hitZ = ByteNet.float32,
				dirX = ByteNet.float32,
				dirZ = ByteNet.float32,
				speed = ByteNet.float32,
			}),
		}),
		reviveClosed = ByteNet.definePacket({
			value = ByteNet.struct({
				reason = ByteNet.string,
			}),
		}),
		requestRedeemCode = ByteNet.definePacket({
			value = ByteNet.struct({
				code = ByteNet.string,
			}),
		}),
		groupChestState = ByteNet.definePacket({
			value = ByteNet.struct({
				isGroupMember = ByteNet.bool,
				hasClaimed = ByteNet.bool,
			}),
		}),
		requestGroupChestState = ByteNet.definePacket({
			value = ByteNet.struct({}),
		}),
		requestGroupChestClaim = ByteNet.definePacket({
			value = ByteNet.struct({}),
		}),
		-- Client tự phát hiện đứng trên treadmill (AABB check cục bộ) rồi báo server.
		-- Server KHÔNG tin client: chỉ dùng làm trigger, tự validate khoảng cách tới hitbox.
		treadmillContact = ByteNet.definePacket({
			value = ByteNet.struct({
				isOn = ByteNet.bool,
			}),
		}),
		toast = ByteNet.definePacket({
			value = ByteNet.struct({
				kind = ByteNet.string,
				message = ByteNet.string,
				amount = ByteNet.float64,
			}),
		}),
		-- Tutorial người chơi mới. Server là nguồn sự thật DUY NHẤT về bước hiện tại: mọi
		-- bước đều gắn với một sự kiện gameplay server đã tự biết (nhận Speed lần đầu, lên
		-- Level 2, chốt Wins lần đầu), nên client không có gì để khai gian.
		tutorialState = ByteNet.definePacket({
			value = ByteNet.struct({
				step = ByteNet.uint8, -- số bước ĐÃ xong
				active = ByteNet.bool, -- false = đã xong/đã skip, ẩn toàn bộ UI tutorial
			}),
		}),
		tutorialComplete = ByteNet.definePacket({
			value = ByteNet.struct({
				wins = ByteNet.float64,
				spins = ByteNet.uint8,
				skipped = ByteNet.bool,
			}),
		}),
		requestTutorialSkip = ByteNet.definePacket({
			value = ByteNet.struct({}),
		}),
		nextStageBanner = ByteNet.definePacket({
			value = ByteNet.struct({
				stage = ByteNet.uint8,
				rewardWins = ByteNet.float64,
				requiredWalkSpeed = ByteNet.float32,
				missingWalkSpeed = ByteNet.float32,
			}),
		}),
		requestEmoteAction = ByteNet.definePacket({
			value = ByteNet.struct({
				action = ByteNet.string,
				emoteId = ByteNet.string,
			}),
		}),
		emoteState = ByteNet.definePacket({
			value = ByteNet.struct({
				unlocked = ByteNet.map(ByteNet.string, ByteNet.bool),
			}),
		}),
		emoteBroadcast = ByteNet.definePacket({
			value = ByteNet.struct({
				userId = ByteNet.float64,
				action = ByteNet.string,
				emoteId = ByteNet.string,
			}),
		}),
		questState = ByteNet.definePacket({
			value = ByteNet.struct({
				active = ByteNet.bool,
				index = ByteNet.uint8,
				title = ByteNet.string,
				progress = ByteNet.float64,
				target = ByteNet.float64,
				rewardText = ByteNet.string,
				rewardSpeed = ByteNet.float64,
				rewardSpins = ByteNet.uint8,
			}),
		}),
		dailyQuestState = ByteNet.definePacket({
			value = ByteNet.struct({
				active = ByteNet.bool,
				rewardText = ByteNet.string,
				rewardSpeed = ByteNet.float64,
				rewardWins = ByteNet.float64,
				quest1Title = ByteNet.string,
				quest1Progress = ByteNet.float64,
				quest1Target = ByteNet.float64,
				quest1Claimed = ByteNet.bool,
				quest2Title = ByteNet.string,
				quest2Progress = ByteNet.float64,
				quest2Target = ByteNet.float64,
				quest2Claimed = ByteNet.bool,
				quest3Title = ByteNet.string,
				quest3Progress = ByteNet.float64,
				quest3Target = ByteNet.float64,
				quest3Claimed = ByteNet.bool,
			}),
		}),
		requestDailyQuestClaim = ByteNet.definePacket({
			value = ByteNet.struct({ index = ByteNet.uint8 }),
		}),
		-- Chỉ phục vụ chẩn đoán 30 giây đầu; không cấp thưởng hay thay đổi gameplay.
		earlySessionState = ByteNet.definePacket({
			value = ByteNet.struct({
				assetsLoaded = ByteNet.bool,
				controlsTouched = ByteNet.bool,
			}),
		}),
		dailyState = ByteNet.definePacket({
			value = ByteNet.struct({
				streakDay = ByteNet.uint8,
				canClaim = ByteNet.bool,
				nextDay = ByteNet.uint8,
			}),
		}),
		requestDailyClaim = ByteNet.definePacket({
			value = ByteNet.struct({}),
		}),
		--[[
			Starter Pack "Rookie Rocket". `secondsLeft` là SỐ GIÂY CÒN LẠI chứ không phải mốc
			hết hạn: client tự đếm lùi, khỏi phụ thuộc đồng hồ máy nó (lệch múi giờ / chỉnh tay).
			`configured` = false khi chưa điền Product ID ⇒ client ẩn sạch, không hiện nút chết.
		]]
		starterPackState = ByteNet.definePacket({
			value = ByteNet.struct({
				secondsLeft = ByteNet.float64,
				bought = ByteNet.bool,
				configured = ByteNet.bool,
			}),
		}),
		requestStarterPackPurchase = ByteNet.definePacket({
			value = ByteNet.struct({}),
		}),
		-- Server Boosts: server đồng bộ số giây còn lại; client tự đếm ngược cục bộ.
		boostState = ByteNet.definePacket({
			value = ByteNet.struct({
				serverSpeedSecondsLeft = ByteNet.float64,
				serverWinsSecondsLeft = ByteNet.float64,
				personalSpeedSecondsLeft = ByteNet.float64,
				personalWinsSecondsLeft = ByteNet.float64,
			}),
		}),
		-- Bùng nổ chúc mừng toàn server khi có người mua Boost.
		-- userId để client tìm đúng character người mua (BoostGloryController tôn vinh 3D).
		boostCelebration = ByteNet.definePacket({
			value = ByteNet.struct({
				playerName = ByteNet.string,
				boostName = ByteNet.string,
				kind = ByteNet.string,
				userId = ByteNet.float64,
			}),
		}),
		-- Event thời vụ đang chạy (Roblox Configs → RemoteConfigService).
		-- Gửi RIÊNG chứ không nhồi vào profileSnapshot: snapshot bắn liên tục theo tick,
		-- kèm thêm một chuỗi tên event vào đó là trả phí băng thông mãi mãi cho một giá trị
		-- vài ngày mới đổi một lần. Packet này chỉ gửi lúc join và lúc event đổi.
		-- name = "" ⇒ không có event nào đang chạy.
		eventState = ByteNet.definePacket({
			value = ByteNet.struct({
				name = ByteNet.string,
				speedMultiplier = ByteNet.float64,
				winsMultiplier = ByteNet.float64,
			}),
		}),
		-- Speed Roulette
		rouletteState = ByteNet.definePacket({
			value = ByteNet.struct({
				tickets = ByteNet.uint8,
				nextFreeTicketSeconds = ByteNet.float64,
			}),
		}),
		requestRouletteState = ByteNet.definePacket({
			value = ByteNet.struct({}),
		}),
		requestSpin = ByteNet.definePacket({
			value = ByteNet.struct({}),
		}),
		--[[
			Treadmill Offline — số Speed đang CHỜ NHẬN (xem `OfflineEarningsService`).

			`speed = 0` là tín hiệu ĐÓNG modal: server gửi nó ngay sau khi đã phát thưởng, nên
			client không cần đoán khi nào nên tự đóng.

			`seconds` chỉ để hiện dòng "bạn đã vắng 2h 40m" — server đã kẹp nó vào trần
			`OfflineEarnings.MAX_SECONDS` trước khi gửi.
		]]
		offlineEarnings = ByteNet.definePacket({
			value = ByteNet.struct({
				speed = ByteNet.float64,
				seconds = ByteNet.float64,
			}),
		}),
		--[[
			Bấm "Claim". KHÔNG mang theo con số nào: số tiền nằm ở `PendingOfflineSpeed` trong
			profile, client chỉ được quyền nói "tôi bấm rồi". Gửi kèm số là mời gọi hack.
		]]
		requestOfflineClaim = ByteNet.definePacket({
			value = ByteNet.struct({}),
		}),
		--[[
			Người chơi đã mở tab Auras ⇒ tắt chấm đỏ "vừa trúng aura Legendary".

			Trạng thái chấm đỏ đi XUỐNG client bằng attribute `UnseenAuraUnlock` trên Player (tự
			replicate, không tốn packet). Chỉ chiều TẮT mới cần gói tin, vì client không ghi được
			attribute do server đặt.
		]]
		requestClearAuraDot = ByteNet.definePacket({
			value = ByteNet.struct({}),
		}),
		-- Chúc mừng CÁ NHÂN (banner + confetti): mua gamepass/treadmill, rebirth thành công...
		purchaseCelebration = ByteNet.definePacket({
			value = ByteNet.struct({
				itemName = ByteNet.string,
				subtitle = ByteNet.string,
			}),
		}),
		-- Kết quả quay: slotIndex 1..8 (tra vào RouletteConfig.SLOTS).
		spinResult = ByteNet.definePacket({
			value = ByteNet.struct({
				slotIndex = ByteNet.uint8,
				rewardText = ByteNet.string,
				tickets = ByteNet.uint8,
			}),
		}),
		-- Server vừa teleport/hồi sinh player quay mặt về hướng (lookX, 0, lookZ).
		-- Camera là CỦA CLIENT — server xoay character thôi chưa đủ, client phải tự
		-- snap camera ra sau lưng theo hướng này (CameraFaceController).
		snapCamera = ByteNet.definePacket({
			value = ByteNet.struct({
				lookX = ByteNet.float32,
				lookZ = ByteNet.float32,
			}),
		}),

		--[[
			Server → Client: "tải trước địa hình quanh điểm này".

			`RequestStreamAroundAsync` là hàm của `Player` và CHỈ gọi được từ client, nên khi
			server biết trước người chơi sắp xuất hiện ở đâu (hồi sinh về Lobby, revive, teleport)
			nó phải NHỜ client tải hộ. Không có gói này thì người chơi chết ở Zone 15 phải đứng
			chờ cả vùng Lobby tải về SAU khi nhân vật đã spawn — đúng lỗi "lâu lâu về Lobby rất
			lâu" user báo 2026-08-21.

			Bên nhận: `CoreLoop/StreamPrefetchController`.
		]]
		prefetchAround = ByteNet.definePacket({
			value = ByteNet.struct({
				x = ByteNet.float32,
				y = ByteNet.float32,
				z = ByteNet.float32,
			}),
		}),
	}
end)

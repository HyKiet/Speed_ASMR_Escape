--!strict
--[[
	Danh sách điểm Teleport.

	── GIÁ WINS: BỊ KẸP GIỮA HAI RÀNG BUỘC (chốt 2026-08-09) ───────────────────────────────

	Giá teleport tới stage N phải nằm HẲN trong khoảng
	        STAGE_WINS[N-1]  <  priceWins(N)  <  STAGE_WINS[N]

	• Cận DƯỚI — chống farm vô hạn. Bộ 3 pad thưởng của zone N-1 nằm TRÊN bệ Transition
	  (N-1)→N, đúng chỗ teleport thả người chơi xuống, và `isFinishSequenceValid` cố tình
	  chấp nhận cả `ActiveStage == N` để pad dưới chân không câm (xem
	  `StageCheckpointService.isFinishSequenceValid`). Nghĩa là mua teleport tới stage N là
	  ăn được Wins của stage N-1 mà KHÔNG phải chạy. Giá rẻ hơn khoản đó ⇒ vòng lặp
	  teleport → ăn pad → teleport sinh Wins vô hạn.
	• Cận TRÊN — yêu cầu của user: giá phải nhỏ hơn thưởng Wins của chính zone đích, để
	  người chơi vượt được stage đó là LÃI ngay trong lần clear đầu tiên. Teleport vì vậy
	  là "mua đường tắt", không phải thuế.

	Số hiện tại lấy xấp xỉ điểm giữa của khoảng, làm tròn đẹp. Thưởng Wins tra ở
	`Config/Stages.luau` (STAGE_WINS) — GDD.md §3.B. ⚠️ Đổi STAGE_WINS thì PHẢI soát lại
	bảng này, hai cận trên/dưới đều bám thẳng vào nó.

	    Đích      | cận dưới (STAGE_WINS[N-1]) | giá  | cận trên (STAGE_WINS[N])
	    Stage 2   |             1              |    2 |        3
	    Stage 3   |             3              |    6 |       10
	    Stage 4   |            10              |   15 |       20
	    Stage 5   |            20              |   35 |       50
	    Stage 6   |            50              |   75 |      100
	    Stage 7   |           100              |  125 |      150
	    Stage 8   |           150              |  225 |      300
	    Stage 9   |           300              |  400 |      500
	    Stage 10  |           500              |  750 |    1,000
	    Stage 11  |         1,000              | 1750 |    2,500
	    Stage 12  |         2,500              | 6000 |   10,000
	    Stage 13  |        10,000              |17500 |   25,000
	    Stage 14  |        25,000              |37500 |   50,000
	    Stage 15  |        50,000              |100000|  150,000

	MIỄN PHÍ: chỉ còn Lobby — điểm ĐIỀU HƯỚNG, không có pad thưởng nào để ăn khi đáp xuống.
	(Stage 1 và Training đã gỡ hẳn khỏi danh sách, xem ghi chú ngay trên mục Stage 2.)

	`priceRobux`/`productId` vẫn để 0: UI đã gỡ hẳn nút mua bằng Robux (xem TeleportModal),
	teleport giờ CHỈ bán bằng Wins.
]]

export type TeleportDestinationConfig = {
	id: string,
	name: string,
	description: string,
	targetPath: string,
	accentColor: Color3,
	sortOrder: number,
	priceWins: number,
	priceRobux: number,
	productId: number,
}

local Teleport: { TeleportDestinationConfig } = {
	{
		id = "lobby",
		name = "Lobby",
		description = "Spawn hub",
		-- SpawnLocation nằm NGOÀI Lobby (Workspace.Spawn), không phải Workspace.Lobby.Spawn —
		-- đường dẫn cũ sai khiến nút Lobby trong TeleportModal câm lặng (bug 2026-08-07).
		targetPath = "Workspace.Spawn.SpawnLocation",
		accentColor = Color3.fromRGB(59, 189, 255),
		sortOrder = 1,
		priceWins = 0,
		priceRobux = 0,
		productId = 0,
	},
	-- ĐÃ GỠ 2026-08-09 (user chốt): "Stage 1" và "Training".
	--   • Stage 1 nằm ngay sau Lobby, chạy bộ tới còn nhanh hơn mở bảng teleport.
	--   • Training (Treadmill_x1) cũng đứng trong Lobby, cách Spawn vài chục studs.
	-- Cả hai đều FREE nên không mất doanh thu, chỉ là hai dòng rác đẩy các stage thật
	-- xuống dưới. Cũng vì thế `sortOrder` bắt đầu nhảy từ 1 sang 3 — số chỉ dùng để sắp
	-- xếp tương đối nên không cần đánh lại.
	{
		id = "stage_2",
		name = "Stage 2",
		description = "Laser Grid",
		targetPath = "Workspace.Zones.Zone1.Ground.Transition1To2",
		accentColor = Color3.fromRGB(255, 201, 71),
		sortOrder = 3,
		priceWins = 2,
		priceRobux = 0,
		productId = 0,
	},
	{
		id = "stage_3",
		name = "Stage 3",
		description = "Clashing Crushers",
		targetPath = "Workspace.Zones.Zone2.Ground.Transition2To3",
		accentColor = Color3.fromRGB(255, 112, 81),
		sortOrder = 4,
		priceWins = 6,
		priceRobux = 0,
		productId = 0,
	},
	{
		id = "stage_4",
		name = "Stage 4",
		description = "Boss Chase",
		targetPath = "Workspace.Zones.Zone3.Ground.Transition3To4",
		accentColor = Color3.fromRGB(193, 111, 255),
		sortOrder = 5,
		priceWins = 15,
		priceRobux = 0,
		productId = 0,
	},
	{
		id = "stage_5",
		name = "Stage 5",
		description = "Conveyor Chaos",
		targetPath = "Workspace.Zones.Zone4.Ground.Transition4To5",
		accentColor = Color3.fromRGB(255, 93, 155),
		sortOrder = 6,
		priceWins = 35,
		priceRobux = 0,
		productId = 0,
	},
	{
		id = "stage_6",
		name = "Stage 6",
		description = "Shrinking Platform",
		targetPath = "Workspace.Zones.Zone5.Ground.Transition5To6",
		accentColor = Color3.fromRGB(79, 218, 202),
		sortOrder = 7,
		priceWins = 75,
		priceRobux = 0,
		productId = 0,
	},
	{
		id = "stage_7",
		name = "Stage 7",
		description = "Crumbling Path",
		targetPath = "Workspace.Zones.Zone6.Ground.Transition6To7",
		accentColor = Color3.fromRGB(111, 153, 255),
		sortOrder = 8,
		priceWins = 125,
		priceRobux = 0,
		productId = 0,
	},
	{
		id = "stage_8",
		name = "Stage 8",
		description = "Spinning Sweeper",
		targetPath = "Workspace.Zones.Zone7.Ground.Transition7To8",
		accentColor = Color3.fromRGB(255, 82, 92),
		sortOrder = 9,
		priceWins = 225,
		priceRobux = 0,
		productId = 0,
	},
	{
		id = "stage_9",
		name = "Stage 9",
		description = "Tsunami Sprint",
		targetPath = "Workspace.Zones.Zone9.Ground.Transition8To9",
		accentColor = Color3.fromRGB(76, 221, 255),
		sortOrder = 10,
		priceWins = 400,
		priceRobux = 0,
		productId = 0,
	},
	{
		id = "stage_10",
		name = "Stage 10",
		description = "Slime Avalanche",
		targetPath = "Workspace.Zones.Zone10.Ground.Transition9To10",
		accentColor = Color3.fromRGB(90, 238, 96),
		sortOrder = 11,
		priceWins = 750,
		priceRobux = 0,
		productId = 0,
	},
	{
		id = "stage_11",
		name = "Stage 11",
		description = "Highway Mayhem",
		targetPath = "Workspace.Zones.Zone11.Ground.Transition10To11",
		accentColor = Color3.fromRGB(255, 199, 66),
		sortOrder = 12,
		priceWins = 1750,
		priceRobux = 0,
		productId = 0,
	},
	{
		id = "stage_12",
		name = "Stage 12",
		description = "Wind Tunnel",
		targetPath = "Workspace.Zones.Zone12.Ground.Transition11To12",
		accentColor = Color3.fromRGB(103, 169, 255),
		sortOrder = 13,
		priceWins = 6000,
		priceRobux = 0,
		productId = 0,
	},
	{
		id = "stage_13",
		name = "Stage 13",
		description = "Momentum Pinball",
		targetPath = "Workspace.Zones.Zone13.Ground.Transition12To13",
		accentColor = Color3.fromRGB(255, 112, 214),
		sortOrder = 14,
		priceWins = 17500,
		priceRobux = 0,
		productId = 0,
	},
	{
		id = "stage_14",
		name = "Stage 14",
		description = "Slime Squish",
		targetPath = "Workspace.Zones.Zone14.Ground.Transition13To14",
		accentColor = Color3.fromRGB(255, 92, 82),
		sortOrder = 15,
		priceWins = 37500,
		priceRobux = 0,
		productId = 0,
	},
	{
		id = "stage_15",
		name = "Stage 15",
		description = "Momentum Jumps",
		targetPath = "Workspace.Zones.Zone15.Ground.Transition14To15",
		accentColor = Color3.fromRGB(255, 218, 67),
		sortOrder = 16,
		priceWins = 100000,
		priceRobux = 0,
		productId = 0,
	},
}

return Teleport

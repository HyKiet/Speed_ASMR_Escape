--!strict
--[[
	ParkourTypes.luau — Kiểu dữ liệu dùng chung cho hệ Kinetic Parkour (bản tối giản).

	"Session" = trạng thái + đối tượng vật lý gắn với MỘT nhân vật hiện tại.
	Mỗi lần respawn, orchestrator tạo Session mới và dọn Session cũ qua Sweeper.
]]

export type Session = {
	-- ── Tham chiếu nhân vật ──
	player: Player,
	character: Model,
	humanoid: Humanoid,
	root: BasePart, -- HumanoidRootPart
	animator: Animator,
	janitor: any, -- Sweeper instance

	-- ── State machine ──
	state: string, -- xem ParkourConfig.States

	-- ── Đối tượng vật lý (tạo 1 lần, bật/tắt theo cơ chế) ──
	attachment: Attachment, -- attachment gốc cho mọi constraint
	slideVelocity: LinearVelocity,
	brakeVelocity: LinearVelocity, -- Active Braking: ghìm vận tốc ngang về 0 khi thả phím
	wallVelocity: LinearVelocity,
	wallForce: VectorForce,
	wallAlign: AlignOrientation,
	slideParticles: ParticleEmitter,

	-- ── Animation tracks (Action) ──
	tracks: { [string]: AnimationTrack },

	-- ── Sprint / Walk ──
	sprinting: boolean,
	originalRunAnimId: string?,
	originalWalkAnimId: string?,

	-- ── Slide runtime ──
	slideSpeed: number,
	slideInitialSpeed: number,
	slideDir: Vector3,
	slideStartClock: number,
	slideEndClock: number,
	lastSlideClock: number,
	originalHipHeight: number,

	-- ── Anti-fling tông tường ──
	wallGuardUntil: number, -- os.clock() hạn chót cửa sổ khóa nảy sau khi dò thấy tường



	-- ── Wall run runtime ──
	wallNormal: Vector3,
	wallSide: number, -- -1 = tường trái, 1 = tường phải
	wallRunActiveTime: number, -- thời gian CHẠY tích lũy (chỉ tăng khi di chuyển)
	wallRunClingTime: number, -- thời gian ĐỨNG/bám liên tục (chỉ tăng khi không di chuyển)
	wallRunStartClock: number,
	lastWallSide: number,
	lastWallDetachClock: number,
	originalAutoRotate: boolean,
}

return {}

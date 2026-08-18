--!strict
--[[
	MovementTypes.luau — kiểu dữ liệu dùng chung cho hệ di chuyển.

	"Session" = toàn bộ trạng thái + đối tượng vật lý gắn với MỘT nhân vật. Mỗi lần
	respawn, orchestrator dọn session cũ bằng Sweeper rồi dựng session mới, nên không
	còn tham chiếu mồ côi tới nhân vật đã chết.
]]

export type Session = {
	-- ── Tham chiếu nhân vật ──
	player: Player,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	animator: Animator,
	sweeper: any,

	-- ── State machine ──
	state: string, -- xem MovementConfig.States

	-- ── Vật lý ──
	attachment: Attachment,
	slideVelocity: LinearVelocity,
	slideParticles: ParticleEmitter,

	-- RaycastParams dùng lại giữa các frame. Bản cũ tạo mới mỗi lần quét (2 lần/frame,
	-- 60Hz) — đó là rác GC thuần tuý. Chỉ dựng lại khi danh sách người chơi đổi.
	rayParams: RaycastParams,
	rayParamsDirty: boolean,

	-- ── Animation ──
	tracks: { [string]: AnimationTrack },

	-- ── Slide runtime ──
	slideSpeed: number,
	slideInitialSpeed: number,
	slideDir: Vector3,
	slideStartClock: number,
	slideEndClock: number,
	lastSlideClock: number,
	originalHipHeight: number,

	-- ── Giảm nhẹ cú văng ──
	-- Vận tốc ở khung hình trước; so với khung hiện tại để nhận biết XUNG va chạm.
	lastVelocity: Vector3,
	-- Lần cuối `Humanoid.Jumping` bắn. Cú nhảy cũng là một xung ĐI LÊN rất mạnh — phải
	-- miễn trừ nó khỏi phép kẹp "bật cóc khi đang bám đất", nếu không nhảy sẽ bị cụt.
	lastJumpClock: number,
}

return {}

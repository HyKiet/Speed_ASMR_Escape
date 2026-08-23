--!strict
--[[
	PreloadManifest — DANH SÁCH ASSET NẶNG NHẤT CỦA MAP, để tải trước.

	══ VÌ SAO ═════════════════════════════════════════════════════════════════════════════════

	Đo 2026-08-21, cùng một PC, cùng viewport 1919×1080:
	    Studio play : 60 fps chắc tay, khung trung vị 16,3–16,8 ms, GIẬT 0/60
	    Game publish: đứng yên thì cũng 60 fps — nhưng **LIA CAMERA là tụt còn 48–56**

	Chênh lệch chỉ xuất hiện khi có hình ảnh MỚI lọt vào khung nhìn. Studio không bị vì phiên
	Edit đã nạp sẵn toàn bộ mesh/texture của map vào RAM và VRAM — bay quanh map trong editor
	chính là một cú "làm nóng" khổng lồ. Client thật thì bắt đầu từ con số 0: mỗi mesh/texture
	lần đầu xuất hiện đều phải tải → giải mã → đẩy lên GPU, và bước cuối làm NGHẼN luồng render
	vài ms. Đó đúng là cái "khựng khựng khi lia màn hình".

	Bằng chứng phụ: mem của client thật bò từ 1838 → 1886 MB trong lúc đo, còn Studio phẳng lì
	ở 3,38 GB. Studio giữ nhiều hơn gần gấp đôi vì nó đã có sẵn tất cả.

	⇒ Nên hai bên KHÔNG BAO GIỜ "đồng bộ" được, và Studio luôn là bản LẠC QUAN. Đo hiệu năng
	  phải đo trên client thật.

	══ VÌ SAO CHỈ 20 ASSET, KHÔNG PHẢI CẢ 107 ═════════════════════════════════════════════════

	Quét toàn bộ Workspace (MeshPart · SpecialMesh · Decal · Texture · ParticleEmitter · Beam ·
	Trail) ra đúng **107 asset duy nhất** — cả map. Nhưng phân bố cực kỳ lệch: 20 cái đầu chiếm
	**~98,8%** tổng số instance dùng chúng (10.448 / ~10.578).

	Cái đuôi 87 asset còn lại mỗi cái chỉ dùng 1–9 lần. Ép chúng thường trú là bắt MỌI người
	chơi — kể cả máy 2 GB RAM như Redmi A2+ — trả tiền bộ nhớ cho những thứ họ có thể không bao
	giờ nhìn thấy. Đổi lại gần như không được gì. Vì vậy cố ý BỎ.

	⚠️ Cái đuôi đó còn chứa mấy Decal bầu trời đêm bắt buộc phải giữ dạng URL
	`http://www.roblox.com/asset/?id=…` (đổi sang `rbxassetid://` là trời đen kịt — xem
	`ClientSettingsController`). Không đụng tới chúng ở đây cũng là tránh luôn cái bẫy đó.

	══ CẬP NHẬT KHI MAP ĐỔI ═══════════════════════════════════════════════════════════════════

	Danh sách này DUMP TỪ MAP, không phải gõ tay. Map không nằm trong git nên nó sẽ cũ dần.
	Chạy lại trong Studio (Edit) khi thêm nhiều mesh mới:

	    local seen, order = {}, {}
	    local function add(id)
	        if typeof(id) ~= "string" or id == "" then return end
	        if not seen[id] then seen[id] = 0; table.insert(order, id) end
	        seen[id] += 1
	    end
	    for _, d in workspace:GetDescendants() do
	        if d:IsA("MeshPart") then add(d.MeshId); add(d.TextureID)
	        elseif d:IsA("SpecialMesh") then add(d.MeshId); add(d.TextureId)
	        elseif d:IsA("Decal") or d:IsA("Texture") then add(d.Texture)
	        elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then add(d.Texture) end
	    end
	    table.sort(order, function(a, b) return seen[a] > seen[b] end)

	Danh sách cũ KHÔNG gây lỗi — asset không còn dùng thì chỉ tải thừa một lần rồi thôi.
]]

local PreloadManifest = {}

-- Số lần asset được dùng trong map ghi ở cuối dòng (dump 2026-08-21).
PreloadManifest.Hot = {
	"rbxassetid://8837613273", -- 6514
	"rbxassetid://94735520903444", -- 1339
	"rbxassetid://6905003203", -- 758
	"rbxassetid://119645107654187", -- 682
	"rbxassetid://101862116072539", -- 441
	"rbxassetid://5860278558", -- 346
	"rbxassetid://10023784358", -- 78
	"rbxassetid://6372755229", -- 39
	"rbxassetid://10023635072", -- 30
	"rbxassetid://9470888178", -- 29
	"rbxassetid://14066311352", -- 29
	"rbxassetid://96421816143941", -- 27
	"rbxassetid://109251800546833", -- 27
	"rbxassetid://4733841640", -- 19
	"rbxassetid://71361577926659", -- 16
	"rbxassetid://138209242993782", -- 16
	"rbxassetid://91804963265247", -- 16
	"rbxassetid://16010698693", -- 15
	"rbxassetid://16867567145", -- 15
	"rbxassetid://10024514185", -- 12
}

return PreloadManifest

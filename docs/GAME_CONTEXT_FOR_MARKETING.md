  # CONTEXT PACK — "+1 Speed Escape" (Roblox)
### Dùng để brief cho AI: brainstorm chiến dịch marketing & viết kịch bản sáng tạo

> **Cách dùng:** Dán TOÀN BỘ file này vào đầu hội thoại với model (Claude / GPT / Gemini),
> rồi thêm 1 dòng yêu cầu ở cuối, ví dụ:
> *"Dựa trên context trên, đề xuất 10 concept video TikTok 15–30s cho tuần ra mắt."*
> Mọi con số trong file đều lấy trực tiếp từ source code của game (không phải ước lượng).

---

## 0. TÓM TẮT MỘT ĐOẠN (elevator pitch)

**+1 Speed Escape** là game Roblox lai giữa **Speed Simulator** và **Obby**, nhưng điểm khác biệt
lớn nhất so với hàng trăm game "+1 Speed" trên nền tảng là: **toàn bộ 15 màn obby đều là sàn ASMR
có âm thanh phản hồi theo từng bước chân** — chạy trên sàn phím cơ, bọc bóng khí (bubble wrap),
slime, cát động (kinetic sand), hạt orbeez, xà phòng, vịt kêu, và một màn mà cả sàn là **một thang
âm 10 nốt** — chạy đúng nhịp thì bước chân của bạn chơi thành một giai điệu.

Nói ngắn: **"Speed simulator mà bạn NGHE được."**

---

## 1. THÔNG TIN CƠ BẢN

| Mục | Nội dung |
| --- | --- |
| Tên game | **+1 Speed Escape** |
| Nền tảng | Roblox (PC / Mobile / Console) |
| Thể loại | Speed Simulator × Obby Hybrid × ASMR |
| Đối tượng | Roblox core demographic (chủ yếu 9–16 tuổi), + nhánh khán giả ASMR/satisfying (rộng hơn, cả 16–25) |
| Quy mô kỹ thuật | ~215 file Luau, ~38.000 dòng code; Fusion (UI), ByteNet (network), ProfileStore (save) |
| Trạng thái | Đã hoàn thiện World 1 (15 stage), có QA pipeline + CI, chuẩn bị publish |
| Vòng đời | World 1: Level 1–120. World 2 (Level 121–220) đang trong roadmap |

---

## 2. VÒNG LẶP CỐT LÕI (dùng để viết kịch bản gameplay)

```
[1. FARM] ──► [2. CHẠY OBBY] ──► [3. ĐIỂM DỪNG CHÂN: CHỌN] ──► [4. NÂNG CẤP] ──► [5. REBIRTH]
   Treadmill      Vượt 15 stage        A) Chốt Wins về Lobby        Mua Trail/Aura      Reset để
   & Multi Pad    ASMR khác nhau       B) Trả 49R$ ăn x2 Wins       /mở Pad mạnh hơn    nhân vĩnh viễn
                                       C) LIỀU: chạy tiếp stage sau
                                          (thưởng cao hơn NHIỀU lần)
```

**Cơ chế cảm xúc mạnh nhất để kể chuyện — "Rest Stop Decision":**
Vạch đích **không** tự trao thưởng. Vượt xong một stage, người chơi đứng trước một quyết định:
bấm pad vàng chốt số Wins đang có và về nhà an toàn, **hay** bước qua cổng chạy tiếp stage sau
với phần thưởng cao gấp bội — nhưng chết là mất trắng lượt đó.
→ Đây là "greed mechanic" kiểu *Wipeout / Deal or No Deal*, cực hợp cho nội dung short-form
(khoảnh khắc do dự, khoảnh khắc tham lam rồi chết ở mét cuối).

**Bậc thang tham lam (số Wins thật trong code):**
Stage 1 = 1 Win · S5 = 50 · S8 = 300 · S10 = 1.000 · S12 = 10.000 · S14 = 50.000 ·
**Stage 15 = 150.000 Wins** (+ bonus 50.000 cho lần clear đầu tiên).
Chênh lệch S14→S15 là 3×: đây là cú "all-in" tự nhiên của mọi video.

**Nghịch lý thiết kế đáng để kể (USP thật sự):**
Chỉ số **Speed** có thể lên hàng triệu/tỷ để flex — nhưng **tốc độ chạy thật bị chặn cứng**:
`WalkSpeed = min(250, 12 + (Level−1)×2)`. Nghĩa là **không ai mua đứt được game bằng tiền**;
whale vẫn phải tự tay vượt obby. Đây là điểm chống lại định kiến "pay-to-win" của thể loại,
và là một góc PR/community rất mạnh.

---

## 3. USP LỚN NHẤT: 15 STAGE = 15 TRẢI NGHIỆM ASMR

Đây là tài sản marketing quý nhất của game. Mỗi stage có một loại sàn riêng, phát âm thanh
theo từng bước chân (engine âm thanh riêng, pool giọng cố định để không bị trễ).

**Các loại sàn ASMR đã dựng trong game (16 loại):**

| Sàn | Cảm giác / âm thanh |
| --- | --- |
| **Keyboard** | 4.650 phím cơ — chạy = gõ phím; mỗi hàng phím là một nốt |
| **MelodyRun** | Cả zone là MỘT thang 10 nốt đi lên — chạy đúng nhịp thành giai điệu |
| **BubbleWrap** | Bọc bóng khí nổ lốp bốp |
| **PopIt** | Đồ chơi pop-it |
| **SlimeSquish / SlimeJelly / Jelly / GummySquish** | Slime nhớp, thạch nảy, kẹo dẻo lún |
| **KineticSand** | Cát động lún và vỡ |
| **Orbeez** | Biển hạt nở lăn |
| **AquaRun** | Nước tóe |
| **Clay** | Đất sét nhão |
| **Soap** | Xà phòng cắt/trượt |
| **CrystalDrop** | Pha lê rơi leng keng |
| **SqueakyDuck** | Vịt cao su kêu |

**Chủ đề obby của 15 stage (World 1):**
1 Keyboard Hop · 2 Laser Grid · 3 Clashing Crushers · 4 Boss Chase · 5 Conveyor Chaos ·
6 Shrinking Platform · 7 Crumbling Path · 8 Spinning Sweeper · 9 Tsunami Sprint ·
10 Slime Avalanche · 11 Highway Mayhem · 12 Wind Tunnel · 13 Momentum Pinball ·
14 Floor Opens Canyon · 15 Momentum Jumps.

**Phong cách hình ảnh:** "Modern Retro" — khối hộp + mái vòm, dải màu kem, palette pastel
hoàng hôn. Sáng, dễ chịu, ảnh chụp lên rất "sạch" — hợp với hướng satisfying/ASMR chứ không
phải hướng edgy/dark.

> **Gợi ý chiến lược (quan trọng):** game này có thể chạy **hai kênh nội dung song song** —
> (a) kênh Roblox truyền thống: flex Speed, số to, rebirth, thumbnail chói;
> (b) kênh ASMR/satisfying: quay cận sàn, thu âm, không lời thoại — kênh này reach ra ngoài
> tệp Roblox và rẻ hơn nhiều. Rất ít game Roblox có được đường (b).

---

## 4. HỆ THỐNG TIẾN TRÌNH & SỐ LIỆU (cho ai cần viết nội dung "guide/tips")

- **Speed/XP:** cộng mỗi tick 0.35s khi đứng trên Treadmill hoặc Multiplier Pad.
- **4 xô nhân hệ số độc lập:**
  1. **Premium** (Robux): Treadmill x1→x100, Speed Pass x2/x4/x8, VIP +0.5
  2. **Cosmetic** (cày Wins): Trail + Aura
  3. **Rebirth**: `1 + (số lần rebirth × 0.5)` — nhân chồng
  4. **Live-Ops**: Playtime Boost (tối đa x4 ở phút 60) × Friends Boost (+10%/bạn trong server,
     tối đa x1.5) × Server Boost (mua Robux, buff CẢ SERVER 10 phút)
- **Rebirth:** cần Level `50 + (rebirth × 10)`. Reset Speed/Level, **giữ nguyên** Wins,
  cosmetics, pads, gamepass.
- **Multiplier Pads ở Lobby:** 8 bậc, mở khóa bằng Wins (0 → 3 → 15 → 100 → 500 → 2.500 →
  15.000 → 50.000), step từ +1 lên +500.

**Móc social có sẵn (dùng được cho campaign):**
- **Friends Boost**: có bạn trong cùng server là mạnh hơn thật → cực dễ làm chiến dịch
  "rủ bạn cùng vào".
- **Server Boost**: một người mua, **cả server** được x2 trong 10 phút → tạo khoảnh khắc
  "vị cứu tinh của server", nội dung viral tự nhiên.
- **Group Rewards**: vào group được tag `[Fan]`/`[Member]`, **+10% Wins vĩnh viễn** mỗi lần
  clear stage, + 5.000 Speed từ Group Chest → đây là công cụ tăng member group tốt nhất.
- **Speed Roulette**: 15 phút online = 1 vé quay miễn phí (trữ tối đa 3). Giải Legendary 1%
  là **Frozen Bloom Aura** — món DUY NHẤT trong game không thể mua bằng bất kỳ loại tiền nào.
  → "Chỉ 1% người chơi có được" là một hook nội dung rất mạnh.

**Promo codes đang hoạt động (dùng cho video/community):**
`RELEASE` (+1.000 Wins + 1 vé quay) · `SPEED` (+5.000 Speed) ·
`FREEWINS` (+2.500 Wins) · `LUCKY` (+10.000 Speed + 2 vé quay)
→ Hệ thống code đã có sẵn trong game; **có thể phát code mới theo từng chiến dịch**
(ví dụ code riêng cho mỗi YouTuber hợp tác).

---

## 5. MONETIZATION (để hiểu game kiếm tiền ở đâu → campaign nên đẩy gì)

**Gamepass (vĩnh viễn):** x2 Speed 3R$ · x4 Speed 9R$ · x8 Speed 27R$ · Auto-Rebirth 99R$ ·
Infinite Revives 249R$ · VIP Membership 399R$ · Treadmill Purple 99R$ / Blue 249R$ /
Gold 699R$ / Red Admin 1.299R$ · 6 Trail + 5 Aura (19R$ → 299R$) ·
Premium display: Dark Aura 299 / Mystic Violet Trail 399 / Flame Aura 499 /
Golden Ray Trail 599 / Red Heart Aura 799 / Crimson Fury Trail 899R$.

**Dev Products (tiêu hao):** Revive 19R$ · Skip Stage 39R$ · **Double Wins 49R$** ·
Skip Rebirth 149R$ · Wins Packs 99/299/699/1.299R$ · Server Boosts 99/99/149R$ ·
Vé quay 1/5/10 = 19/79/149R$.

**Nhận xét cho marketing:** điểm vào rẻ nhất là **3 R$** (x2 Speed) — gần như không có rào cản,
rất hợp thông điệp "ai cũng bắt đầu được". Còn sản phẩm cảm xúc mạnh nhất là **Double Wins 49R$**
ngay tại khoảnh khắc vừa hoàn thành stage khó — đó là lúc người chơi đang phấn khích nhất.

---

## 6. GIỌNG ĐIỆU & RÀO CHẮN (brand guardrails)

**Nên:** vui, năng lượng cao, "satisfying", nhấn cảm giác âm thanh + tốc độ; tự hào là
game **không pay-to-win** (WalkSpeed cap là thật, kiểm chứng được trong code).

**Không nên:** hứa hẹn phần thưởng không có thật; dùng thumbnail lừa đảo kiểu "FREE ROBUX";
so sánh hạ bệ game khác; nội dung không phù hợp lứa tuổi (đối tượng chủ yếu là trẻ em →
phải tuân thủ Roblox Community Standards và quy định quảng cáo hướng tới trẻ em).

**Ràng buộc thực tế cần biết khi lập kế hoạch:**
- Game phát hành dưới **group** (không phải tài khoản cá nhân).
- Có sẵn 2 place: **QA** và **Live**, tách DataStore → có thể test chiến dịch trước khi đẩy live.
- Đã có hệ thống telemetry/analytics phía server (TelemetryService) và RemoteConfig
  → **có thể bật/tắt tính năng hoặc đổi số liệu từ xa mà không cần update game.**
- Chưa có tài sản marketing nào được sản xuất (icon/thumbnail/trailer/kênh social)
  → mọi thứ đang là trang giấy trắng.

---

## 7. NHỮNG GÌ TÔI CẦN TỪ BẠN (chọn 1 hoặc nhiều)

Khi dán context này, hãy nêu rõ yêu cầu. Ví dụ các hướng có thể đặt hàng:

1. **Chiến lược ra mắt** — kế hoạch 4 tuần trước & sau launch: kênh nào, thứ tự nào,
   ngân sách Roblox Ads nên đặt ở đâu, KPI nào cần theo dõi (D1/D7 retention, playtime,
   conversion rate).
2. **Kịch bản video short-form** — TikTok/Shorts/Reels 15–45s: hook 3 giây đầu, nhịp cắt,
   câu thoại, on-screen text, gợi ý âm thanh trending.
3. **ASO / Store page** — tên game tối ưu tìm kiếm Roblox, mô tả, danh sách tag,
   ý tưởng icon và 3 thumbnail (mô tả bố cục cụ thể để artist vẽ được).
4. **Concept trailer** — kịch bản trailer 60–90s có shot list và timeline.
5. **Chiến dịch creator/influencer** — cách tiếp cận YouTuber Roblox, gói hợp tác,
   mẫu tin nhắn, cấu trúc code riêng cho từng creator.
6. **Kế hoạch LiveOps 90 ngày** — lịch sự kiện, cadence update, code drop, event theo mùa
   để giữ chân người chơi.
7. **Community** — Discord/group Roblox: cấu trúc kênh, nội dung tuần, cơ chế thưởng.

**Ràng buộc chung cho mọi đề xuất:**
- Ngân sách nhỏ, đội ngũ nhỏ (gần như solo dev) → ưu tiên chiến thuật organic/chi phí thấp.
- Mọi thứ đề xuất phải làm được với những gì game ĐANG có (liệt kê ở trên) —
  nếu cần tính năng mới trong game, hãy nói rõ đó là yêu cầu phát triển thêm.
- Đừng bịa ra tính năng, con số hay phần thưởng không có trong tài liệu này.

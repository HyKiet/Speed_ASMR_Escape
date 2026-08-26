# TikTok @shk.studio — quay & dựng

Game: **+1 Speed ASMR Escape | Satisfying Floors!**
https://www.roblox.com/games/94107323826144/1-Speed-ASMR-Escape-Satisfying-Floors

Bạn quay → bỏ file vào `raw/` → tôi dựng ra `out/` kèm caption.

> 👉 **Quay clip đầu tiên thì chỉ cần đọc [`VIDEO_1.md`](VIDEO_1.md).** File này là kế hoạch
> cả 3 tuần — đọc sau, khi clip 1 đã lên sóng.

---

## 0. Kênh này là kênh gì

**Kênh của một solo dev, không phải kênh của một game.** Nhân vật chính là bạn; game chỉ là
thứ bạn đang làm lúc này. Game sau đổi thì kênh không phải làm lại từ đầu — follower đi theo
người, không đi theo sản phẩm.

Hệ quả lên cách dựng: **trụ C (hậu trường Studio) là xương sống**, không phải phần phụ.
Đó là phần duy nhất còn nguyên giá trị khi bạn đổi game. Clip ASMR kéo người lạ vào,
clip game biến họ thành người chơi, clip dev giữ họ lại.

Tỉ lệ 10 clip: **5 ASMR · 2 game · 3 dev**.

---

## 1. Bio TikTok (dán thẳng)

**Name** (30 ký tự — bản này 16):
```
SHK Studio Games
```

**Bio** (giới hạn 80 ký tự — bản này 73):
```
Solo dev. Roblox games you can HEAR 🎧
search "SHK Studio Games" on Roblox
```

> **Không cần Business account.** TikTok bắt xác minh doanh nghiệp thật nên bỏ hướng đó —
> ô Website coi như không có.
>
> Thay vào đó, chuỗi tìm kiếm là **tên studio, không phải tên game**. Ba lý do:
> 1. `+1 Speed` là tên cả một thể loại, hàng trăm game trùng chữ — gõ ra là lạc sang đối thủ.
>    `SHK Studio Games` là chuỗi **chỉ mình bạn có**.
> 2. Nó trỏ vào hồ sơ creator → thấy **mọi** game của bạn, kể cả game sau. Không phải sửa bio
>    mỗi lần ra game mới.
> 3. Name TikTok = tên creator Roblox = cùng một chuỗi, đọc một lần nhớ luôn.
>
> Link đầy đủ để **ghim ở bình luận đầu tiên** của mỗi clip (bio không click được, bình luận
> thì copy được):
> ```
> https://www.roblox.com/games/94107323826144/1-Speed-ASMR-Escape-Satisfying-Floors
> ```

---

## 2. Cài đặt quay

- **Win + Alt + R** (Game Bar) hoặc OBS · **1920×1080, 60fps, quay NGANG** — tôi cắt về 9:16
- Tắt **Discord**, nhạc, tab trình duyệt đang phát → Game Bar thu hết tiếng hệ thống
- Cảnh ASMR: bật **"Ẩn UI"** trên topbar · Cảnh trụ B: **giữ HUD** (số Wins chạy là kịch tính)
- Giữ thứ đáng xem ở **giữa khung** — hai bên sẽ bị cắt
- **Quay dư 30–45 giây mỗi cảnh.** Clip cuối chỉ 7–13s, tôi cần dư để chọn đoạn tiếng đẹp nhất

**Mẹo quan trọng nhất — chạy CHẬM ở cảnh ASMR (WalkSpeed 16–40).**
Ở 200+, bước chân dồn thành một tiếng rẹt: tai nghe ra tiếng ồn, không ra tiếng phím cơ.
Trong Studio, bấm Play rồi gõ Command Bar:
```lua
game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 24
```
⚠️ Đừng teleport tay để tới zone xa — AntiCheat giật ngược rồi giết. **Dời `SpawnLocation`
trước khi bấm Play.**

---

## 3. 12 cảnh cần quay

Đặt tên file đúng cột đầu, bỏ vào `raw/`.

### Trụ A — ASMR · không giọng đọc · ẩn UI

| File | Quay gì | Ghi chú |
| --- | --- | --- |
| `A1_melody.mp4` | Zone 13 MelodyRun — chạy hết một lượt thang 10 nốt | **Cảnh mạnh nhất.** Quay 2 tốc độ (~30 và ~120), ít nhất 4 lượt |
| `A2_keyboard.mp4` | Sàn phím cơ, vùng phím dày nhất | Camera sát sàn, thấy phím lún. Phải nghe TÁCH từng phím |
| `A3_bubblewrap.mp4` | Sàn bọc bóng khí | Đi zíc-zắc, đừng đi thẳng — nổ được nhiều bóng hơn |
| `A4_duck.mp4` | Sàn vịt cao su — chạy qua rồi **dừng, dậm tại chỗ 3–4 cái** | Đoạn dậm tại chỗ mới là đoạn buồn cười |
| `A5_orbeez.mp4` | Sàn orbeez, chạy chậm cho hạt lăn | Camera rất cận, gần ngang mặt sàn |
| `A6_soap.mp4` | Sàn xà phòng hoặc slime | Dự phòng, quay nếu còn thời gian |

### Trụ B — có giọng đọc · GIỮ HUD

| File | Quay gì |
| --- | --- |
| `B1_greed_win.mp4` | Rest Stop **Stage 14** (đang cầm 50.000 Wins). Đi tới pad vàng, **dừng ~3s lưỡng lự, quay đầu nhìn cổng** → bước qua cổng → chạy Stage 15 → **về đích**, dậm pad ăn 150.000 |
| `B2_greed_death.mp4` | Y hệt trên nhưng **chết ở Stage 15**, càng gần đích càng tốt. Chạy tới khi nào chết gần đích thì thôi |
| `B3_no_p2w.mp4` | Mở Shop khoe các gói Speed → HUD hiện **số Speed khổng lồ** → cắt sang cảnh chạy obby, **vẫn chạy tốc độ thường**. Cần thấy cả hai trong một clip |
| `B4_serverboost.mp4` | Mua Server Boost → banner buff hiện cho cả server. Có bạn cùng server phản ứng trong chat thì quý hơn nhiều |

### Trụ C — có giọng đọc · quay màn hình Studio

| File | Quay gì |
| --- | --- |
| `C1_studio_keyboard.mp4` | Bung Explorer cho thấy hàng loạt part phím (cuộn dài dằng dặc — đừng cắt ngắn, đó là bằng chứng), rồi xoay camera nhìn toàn cảnh sàn phím |
| `C2_studio_melody.mp4` | Phần MelodyRun: các ô sàn được đánh nốt → bấm Play chạy thử ra giai điệu |
| `C3_bug.mp4` | **Một con bug thật.** Sàn phím nảy tung khi fps thấp, pad tô sai màu, nhân vật rơi xuyên sàn — thứ gì đang hỏng hoặc từng hỏng. Quay cả lúc nó vỡ | 

**Không cần đủ 13 mới gửi.** Quay được cảnh nào tôi dựng cảnh đó.
Nếu chỉ quay nổi 3 cảnh: **A1 → A2 → C1**.

> `C3_bug` là dạng clip được chia sẻ nhiều nhất trong ngách gamedev, và bạn có sẵn chất liệu
> thật — không phải dàn dựng. Dựng bằng khung `blur` để thấy được cả Explorer hai bên.

---

## 4. Lời thoại & chữ trên màn hình

Đã viết sẵn cho cả 12 clip trong [`scripts.json`](scripts.json) — mỗi clip có chữ overlay,
lời thoại kèm mốc giây, caption và hashtag. Muốn đổi câu nào thì sửa thẳng ở đó rồi tôi dựng lại.

Nguyên tắc đang áp dụng:
- **7–13 giây/clip.** Clip 10s dễ đạt 90% xem hết; clip 30s khó vượt 40%
- **Clip ASMR không có giọng đọc.** Giọng TTS đè lên tiếng phím cơ là giết luôn lý do clip tồn tại
- Chữ overlay tối đa 6 từ, đặt ở 1/3 trên (1/3 dưới bị nút TikTok che)

---

## 5. Dựng

```bash
cd marketing/tiktok
python build.py --check          # xem cảnh nào đã có
python build.py A1_melody        # dựng 1 clip
python build.py all              # dựng mọi clip có footage
python build.py A1_melody --in 4.2 --out 13.8   # chọn lại điểm cắt
```

Ra `out/<id>.mp4` (1080×1920, âm lượng chuẩn TikTok) + `out/<id>.txt` (caption + hashtag).
Giọng đọc dùng edge-tts, đã cài sẵn. Đăng 2 clip/ngày, **20:00** và **08:00** giờ VN.

**Quay xong nhắn tôi.**

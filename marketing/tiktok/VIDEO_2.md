# Video 2 — Sàn cát Lobby

Được, và nó **mạnh hơn video 1**. Đây là lý do.

Tôi đọc engine sàn cát (`ASMR/Floors/KineticSandLive.luau`, sàn `Lobby.ASMR.Live`). Nó không
chỉ kêu — nó **để lại vết**:

- Vết chân lún xuống, có **viền phồng** quanh mép, và cát chỗ đó **sẫm màu như cát ướt**
- Đi bộ → vết **so le trái/phải** như dấu chân thật
- Đứng yên vẫn hằn vết
- Vết giữ **3,5–6 giây rồi từ từ trồi lên đầy lại**

Video 1 chỉ có tiếng. Video 2 có **tiếng + hình biến đổi**. "Kinetic sand" là một trong những
ngách ASMR lớn nhất TikTok — người ta xem cát bị ấn xuống rồi phục hồi hàng triệu lượt.

Và nó ở **Lobby** — vào game là đứng ngay trên nó. Còn dễ hơn video 1.

---

## Chữ trên clip & caption

| Giây | Chữ |
| --- | --- |
| 0 → 3.2 | **this floor remembers your steps** |
| 7.4 → 9.8 | +1 Speed ASMR Escape |

```
The lobby floor is kinetic sand. Footprints sink, leave a rim, then slowly fill back in.

#asmr #kineticsand #satisfying #roblox
```

Ghim link ở bình luận đầu như video 1.

---

## Quay — điểm khác video 1

Cài đặt máy y hệt (tắt Discord, ẩn UI, quay ngang 1080p60, **F11 cho full màn hình** để khỏi
dính taskbar). Chỉ khác ba chỗ:

**1. ĐI BỘ, tuyệt đối đừng chạy.** Chạy nhanh thì engine gộp thành **một rãnh liền** — mất
sạch vết chân so le, mà vết chân mới là thứ đáng xem. Đi bộ thường là đúng.

**2. Camera chếch xuống nhiều hơn video 1**, gần như nhìn từ trên xuống. Cần thấy rõ **vết
chân phía sau lưng**, không phải thấy đường phía trước.

**3. Quay theo đúng nhịp này, lặp lại 3–4 lần (mỗi lần ~20 giây):**

| | Làm gì |
| --- | --- |
| ~5 giây | Đi bộ chậm một đường thẳng, để lại một hàng vết chân |
| ~2 giây | **Dừng hẳn.** Xoay camera nhìn lại hàng vết chân vừa tạo |
| ~8 giây | **Đứng im, đừng động vào gì cả.** Để camera nhìn vết tự đầy lại |

Đoạn cuối là đoạn quan trọng nhất và cũng là đoạn dễ bị bỏ nhất, vì đứng im 8 giây trong game
có cảm giác rất lâu. Đừng cắt sớm. **Cú vết chân đầy lại chính là điểm chốt của clip.**

Quay dư như lần trước — 60 giây tổng là thoải mái.

## Giao file

`A7_sand.mp4` → `marketing/tiktok/raw/` → nhắn tôi.

---

## Một con số cần đo lại

Trong code ghi sàn cát Lobby có **5.180 ô**. Tôi lấy từ comment trong source, **chưa tự đếm**
— và lần trước đúng kiểu số truyền miệng như vậy (4.650 phím) đã sai. Nên caption ở trên cố ý
**không nhắc con số**. Lúc nào bạn mở Studio, tôi đếm lại; đúng thì thêm vào caption, vì
"5.180 ô cát" là một chi tiết rất đắt.

---

## Bản đang dùng — `out/A7_sand.mp4` (12.0s)

Ghép **hai đoạn** từ `A7_sand_2.mp4`, nối bằng crossfade 0.3s:

| Đoạn | Giây trong file gốc | Nội dung |
| --- | --- | --- |
| 1 | 7.2 → 13.2 | Đi bộ, vết chân **hình thành** |
| 2 | 14.9 → 21.2 | Đứng im, vết chân **tự lành** |

Hai câu chữ bám đúng hai đoạn: *"this floor remembers your steps"* → *"...and then forgets them"*.

Vì sao phải ghép chứ không cắt một mạch: quãng 13.5–14.85 camera quét qua sát góc nhìn thứ
nhất, Roblox làm nhân vật trong suốt và để lại một vệt tròn mờ giữa khung — không dùng được.
Mà bỏ hẳn đoạn đi bộ thì đoạn sau mất nghĩa: người xem thấy cát tự phẳng ra mà không hiểu
vết ở đâu ra.

### Hai chỗ nhiễm trong file gốc (để lần sau tránh)

- **Sau giây 21.4** lọt trình chuyển cửa sổ rồi cửa sổ OBS vào khung.
  → **Bấm dừng ghi TRƯỚC, alt-tab SAU.**
- **Con trỏ chuột** đứng giữa khung suốt clip. Lần này xoá được bằng `delogo` vì nó đứng yên
  trên nền cát trơn; con trỏ mà di chuyển thì không cứu được.
  → OBS → Sources → Game/Display Capture → bỏ tick **"Capture Cursor"**.

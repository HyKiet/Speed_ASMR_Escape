# Rà soát kinh tế & công thức sức mạnh

> Chốt 2026-08-13. Mọi con số dưới đây tính bằng **chính công thức trong `Config/Formulas.luau`**,
> không phải ước lượng.

---

## 1. Đường cong XP — lành mạnh

`GetRequiredXP(level) = 1.010.000 × 1,1584^(level−67)` → **+15,84% mỗi level**, thuần mũ.

| Level | Cần riêng level đó | Tổng tích luỹ | MaxWalkSpeed |
|---:|---:|---:|---:|
| 1 | 62 | 62 | 12 |
| 10 | 231 | 1,3K | 30 |
| 25 | 2,1K | 15,0K | 60 |
| 50 | 82,9K | 605,9K | 110 |
| 67 | 1,01M | 7,39M | 144 |
| 100 | 129,4M | 946,1M | 210 |
| 120 | 2,45B | **17,91B** | **250 (trần)** |
| 150 | 201,9B | 1,48T | 250 |

15,84%/level hơi dốc so với mặt bằng thể loại (8–12%), nhưng được bù bằng dải multiplier rất rộng. Không cần đụng.

## 2. Rebirth — lỗi nghiêm trọng nhất

### Vấn đề

- `GetRequiredLevelForRebirth(r) = 50 + 10r` — mỗi 10 level là **×4,35 chi phí**
- `GetRebirthMultiplier(r) = 1 + 0,5r` — mỗi lần chỉ **+0,5 tuyến tính**

Chi phí tăng theo cấp số nhân, phần thưởng tăng theo cấp số cộng. Hai đường này phân kỳ ngay lập tức.

### Đo bằng THỜI GIAN (thứ người chơi thật sự cảm nhận)

`thời gian(N) = chi phí(N) ÷ hệ số đang có(N−1)`

| Rebirth | Cần Level | Tổng Speed | Hệ số đang có | Lâu gấp lần trước | Nếu r1 = 1 giờ |
|---:|---:|---:|---:|---:|---:|
| 1 | 50 | 605,9K | ×1,0 | — | 1 giờ |
| 2 | 60 | 2,64M | ×1,5 | 2,90× | 2,9 giờ |
| 3 | 70 | 11,48M | ×2,0 | 3,26× | 9,5 giờ |
| 4 | 80 | 49,96M | ×2,5 | 3,48× | 33 giờ |
| 5 | 90 | 217,4M | ×3,0 | 3,63× | 5 ngày |
| 6 | 100 | 946,1M | ×3,5 | 3,73× | 18,6 ngày |
| 7 | 110 | 4,12B | ×4,0 | 3,81× | 71 ngày |

Chuẩn của thể loại: thời gian giữa hai lần prestige **gần như không đổi**, hoặc tăng nhẹ (1,2–1,4×). Ở đây nó tăng **3,7×** mỗi lần và còn đang tăng dần.

⚠️ Bức tường rơi vào khoảng rebirth 4–5, tức **tuần thứ hai** của người chơi chăm — đúng mốc **Ngày 8–28** mà thuật toán Roblox 2026 đo nặng nhất.

### Hệ số `1 + 0,5r` KHÔNG phải chỗ hỏng

Bản rà soát đầu tiên đổ lỗi cho `GetRebirthMultiplier`. **Sai.** Thang ×1,5 → ×2,0 → ×2,5 là
mẫu chuẩn, có thật, dùng rộng rãi trong simulator lớn — nó được lấy từ game mẫu chứ không phải
làm bừa. Giữ nguyên.

Chỗ hỏng nằm ở **`GetRequiredLevelForRebirth`, và chỉ ở một con số: bước +10 level.**

Trong các game dùng hệ số tuyến tính đó, điều kiện rebirth thường ra thẳng bằng tiền mềm theo
một thang gần tuyến tính. Ở đây điều kiện lại là *level*, mà level nằm trên đường cong mũ
15,84%. Cộng 10 level = **×4,35 chi phí**. Hai mảnh đều đúng khi đứng riêng; ghép lại mới hỏng.

### Cách sửa: đổi đúng một số

```lua
function Formulas.GetRequiredLevelForRebirth(currentRebirths: number): number
    return 50 + (currentRebirths * 3)     -- 10 → 3: chi phí ×1,55 thay vì ×4,35
end
-- GetRebirthMultiplier GIỮ NGUYÊN = 1 + 0,5r
```

`1,1584³ = 1,554` chi phí, chia cho mức tăng hệ số mỗi lần → thời gian giãn rất chậm:

| Rebirth | Cần Level | Tổng Speed | Hệ số | Lâu gấp lần trước | Nếu r1 = 1 giờ |
|---:|---:|---:|---:|---:|---:|
| 1 | 50 | 605,9K | ×1,0 | — | 1 giờ |
| 2 | 53 | 941,7K | ×1,5 | 1,04× | 1,04 giờ |
| 3 | 56 | 1,46M | ×2,0 | 1,17× | 1,2 giờ |
| 4 | 59 | 2,28M | ×2,5 | 1,24× | 1,5 giờ |
| 5 | 62 | 3,54M | ×3,0 | 1,30× | 2,0 giờ |
| 6 | 65 | 5,50M | ×3,5 | 1,33× | 2,6 giờ |
| 10 | 77 | 33,5M | ×5,5 | 1,40× | 7,3 giờ |

Tổng tới rebirth 10 ≈ **22 giờ chơi**. Mấy lần rebirth đầu còn *nhanh dần* — đúng cảm giác
"bấm rebirth là được thưởng" — rồi giãn ra rất từ tốn, tiệm cận 1,55× chứ không nổ ×3,7×.

Muốn rộng tay hơn nữa thì `50 + 2r` (chi phí ×1,34): thời gian gần như đứng yên ở 1,15–1,28×
suốt hàng chục lần rebirth. Đổi lại là cần nhiều lần rebirth hơn để đạt cùng một hệ số.

### Ghi chú

Với `1 + 0,5r`, số lần rebirth sẽ nhiều (hàng chục tới hàng trăm) trước khi hệ số thành to.
Đó là hành vi **đúng** của mẫu tuyến tính và cũng là điều các game mẫu làm — miễn là mỗi lần
bấm đều nằm trong tầm một buổi chơi.

### Khi sửa nhớ

`Tuning.CORE_LOOP_VERSION` phải bump (hiện `= 2`) — `DataService` dùng nó để migrate profile. Đổi công thức mà không bump là để người chơi cũ mắc kẹt giữa hai hệ.

## 3. Trần WalkSpeed 250 vs bảng gate tới Stage 30 — mâu thuẫn

`GetMaxWalkSpeed` kẹp cứng **250** (đạt ở level 120), nhưng `Stages.STAGE_GATES` khai tới stage 30 với `minWS` từ **262 đến 444**.

**Stage 17 trở đi đang yêu cầu tốc độ không thể đạt được.** Hiện chưa lộ vì mới có 15 zone, nhưng phải nâng trần hoặc hạ bảng **trước khi dựng World 2**.

## 4. Điểm mạnh — giữ nguyên

- **Trần tốc độ là chủ ý và gắn với obby.** Gate cao nhất (Stage 15 = 234 WS) nằm sát trần 250, nên obby luôn còn thử thách. Đa số simulator để sức mạnh vô hạn nên nội dung mất nghĩa sau vài giờ.
- **Hai loại tiền tách bạch đúng cách.** Wins = tiền cứng (mở pad, teleport, không hồi); Speed = tiền mềm (mất khi rebirth). Vòng quay đã được cân theo đúng nguyên tắc này (xem khối comment trong `Config/Roulette.luau`).
- **Bậc pad ×5 chi phí / ×2,2 sức mạnh** — đường cong giảm dần lành mạnh, chống lạm phát tốt.

## 5. Giữ chân theo ba cửa sổ của thuật toán

| Cửa sổ | Hiện trạng | Đánh giá |
|---|---|---|
| **Ngày 1** | Level 1 chỉ cần 62 Speed (~20 giây farm); sàn ASMR cho phản hồi cảm giác ngay; có tutorial | **Mạnh.** Trừ hai chỗ: modal Daily Rewards che kín màn hình ngay lần vào đầu, và vé quay đầu tiên bị khoá 15 phút |
| **Ngày 2–7** | Daily Rewards 7 ngày có streak + jackpot Ngày 7 (Streak Aurora Trail); Playtime boost; Codes | **Ổn.** Thiếu nhiệm vụ ngày — chỉ có phần thưởng đăng nhập |
| **Ngày 8–28** | Bức tường rebirth; trần WalkSpeed; hết nội dung sau Stage 15; không có cơ chế chơi cùng bạn | **Yếu** — và đây đúng là cửa sổ thuật toán 2026 đo nặng nhất |

### Khoảng trống lớn nhất theo thứ tự đòn bẩy

1. **Bức tường rebirth** (mục 2) — sửa được bằng hai dòng code
2. **Không có gì cho "intentional co-play days"** — đây là một tín hiệu *Quan trọng* được Roblox nêu đích danh, mà `FriendService` hiện chỉ đếm bạn bè trong server để nhân hệ số thụ động. Không có đua, không có co-op, không có mục tiêu chung
3. **Sàn ASMR không có trục tiến trình** — 14 loại sàn là mỏ khác biệt thật, nhưng độ mới lạ cảm giác chỉ đánh được một lần cho mỗi sàn. Không có bộ sưu tập, huy hiệu, hay lý do quay lại một sàn đã đi qua
4. **Hết nội dung sau Stage 15** — World 2 chưa dựng (và bảng gate của nó đang hỏng, xem mục 3)

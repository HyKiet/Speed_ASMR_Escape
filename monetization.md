# 💸 CHI TIẾT THIẾT KẾ MONETIZATION SHOP — SpeedEscape v4

Tài liệu này hệ thống hóa các gói Gamepass, Developer Product (Đồ ăn liền), Máy chạy bộ và Vật phẩm trang trí (Trails & Auras) của game SpeedEscape theo chuẩn **Giá gốc Mỹ (US Base Pricing)** để áp dụng tính năng Tự động định giá theo khu vực (Region Pricing) của Roblox.

---

## 🚀 1. GÓI TĂNG TỐC ĐỘ CÀY CUỐC (SPEED GAMEPASSES)
*Được cấu hình giá gốc Mỹ (US Base Price) sao cho khi hệ thống Roblox tự động quy đổi theo khu vực (Region Pricing) tại Việt Nam (tỷ lệ chiết khấu khoảng 68% - 70%), người chơi Việt Nam sẽ thấy các mức giá mục tiêu: 3, 9, và 19 Robux.*

*   **⚡ x2 Speed**
    *   Giá gốc Mỹ (US Base): **10 Robux**
    *   Giá sau quy đổi tại Việt Nam: **3 Robux** *(Tỷ lệ ~30%)*
*   **⚡ x4 Speed**
    *   Giá gốc Mỹ (US Base): **29 Robux**
    *   Giá sau quy đổi tại Việt Nam: **9 Robux** *(Tỷ lệ ~30%)*
*   **⚡ x8 Speed**
    *   Giá gốc Mỹ (US Base): **59 Robux**
    *   Giá sau quy đổi tại Việt Nam: **19 Robux** *(Tỷ lệ ~32%)*

> [!IMPORTANT]
> **Cơ chế hoạt động:** 
> Các SPEED GAMEPASSES này **không nhân dồn hay cộng dồn** với nhau. Hệ thống sẽ áp dụng hệ số nhân cao nhất mà người chơi đang sở hữu. 
> *Ví dụ: Nếu người chơi đang dùng x2 Speed và mua tiếp x4 Speed, hệ số nhân mới sẽ là x4 Speed (chứ không nhân dồn thành x8 Speed).*

---

## 👑 2. GAMEPASS TIỆN ÍCH & VIP MEMBERSHIP
*Đặc quyền cao cấp và tự động hóa treo máy (QoL) được điều chỉnh theo giá chuẩn US.*

*   **⚜️ VIP Membership (399 Robux):**
    *   🏷️ Có tag [VIP] phát sáng Neon trong khung chat và trên bảng tên.
    *   📈 Cộng vĩnh viễn x1.5 Speed và x1.2 Wins (cộng dồn với các gamepass khác).
    *   ✨ Nhận ngay 1 Trail độc quyền VIP (Golden Sparkle Trail - Vệt sáng lấp lánh).
    *   🌀 Nhận ngay 1 Aura độc quyền VIP (Neon Rainbow Aura - Hào quang cầu vồng).
*   **🔄 Auto-Rebirth (99 Robux):** Tự động Rebirth khi đạt đủ cấp độ yêu cầu, tối ưu cày Rebirth qua đêm khi AFK.

---

## 💰 3. GÓI ĐỒ ĂN LIỀN (DEVELOPER PRODUCTS)
*Bán Wins trực tiếp bằng Robux theo tỷ giá US tiêu chuẩn để phục vụ Whales.*

*   **💎 Gói Wins Nhỏ** (49 Robux) ➔ Nhận ngay **+1,000 Wins** (Mở nhanh Pad 2, 3, 4)
*   **💎 Gói Wins Vừa** (149 Robux) ➔ Nhận ngay **+10,000 Wins** (Mở nhanh Pad 5, 6)
*   **💎 Gói Wins Lớn** (399 Robux) ➔ Nhận ngay **+100,000 Wins** (Lên thẳng Pad 7)
*   **💎 Gói Siêu Cấp** (999 Robux) ➔ Nhận ngay **+1,000,000 Wins** (Mở khóa Pad 8 tối thượng)

---

## 🛹 4. GAMEPASS MÁY CHẠY BỘ (TREADMILLS)
*Hệ số nhân của máy chạy bộ đang trang bị (Treadmill Multiplier). Người chơi mua bằng Robux để sở hữu các hệ số nhân khủng vĩnh viễn (Auto-Train).*

*   🪵 `treadmill_1` | **Máy Gỗ** ➔ Hệ số nhân **x1.0** | Giá: **Miễn phí** (Tân thủ)
*   🟡 `treadmill_2` | **Máy Vàng** ➔ Hệ số nhân **x3.0** | Giá: **99 Robux** (Chuẩn US)
*   🟢 `treadmill_3` | **Máy Xanh** ➔ Hệ số nhân **x9.0** | Giá: **249 Robux** (Chuẩn US)
*   🌸 `treadmill_4` | **Máy Hồng** ➔ Hệ số nhân **x25.0** | Giá: **499 Robux** (Chuẩn US)
*   🔴 `treadmill_5` | **Máy Admin Đỏ** ➔ Hệ số nhân **x100.0** | Giá: **999 Robux** (Whale tối thượng)

---

## ✨ 5. VỆT SÁNG & HÀO QUANG NÂNG CAO (TRAILS & AURAS)

### 🌌 A. Hệ thống Hào Quang (Auras)
*Hiệu ứng VFX bao quanh cơ thể nhân vật, mở khóa bằng Wins.*

*   ✨ `aura_sparkle`   | **Hào Quang Lấp Lánh** ➔ Hệ số nhân **x1.2** | Giá: **200 Wins**
*   🔥 `aura_fire`      | **Hào Quang Lửa Đỏ**   ➔ Hệ số nhân **x1.8** | Giá: **2,000 Wins**
*   ⚡ `aura_lightning` | **Hào Quang Sét Điện** ➔ Hệ số nhân **x2.5** | Giá: **8,000 Wins**
*   🌀 `aura_void`      | **Hào Quang Hư Không** ➔ Hệ số nhân **x4.5** | Giá: **40,000 Wins**
*   🌌 `aura_cosmic`    | **Hào Quang Vũ Trụ**   ➔ Hệ số nhân **x8.0** | Giá: **200,000 Wins**

### 💫 B. Hệ thống Vệt Sáng (Trails)
*Vệt sáng kéo dài theo bước chạy. Mở khóa bằng Wins hoặc mua nhanh bằng Robux theo giá US.*

*   🟢 `trail_green`   | **Vệt Sáng Lục** ➔ Hệ số nhân **x1.5** | Giá: **500 Wins**   | Mua nhanh: **29 Robux**
*   🔵 `trail_blue`    | **Vệt Sáng Lam** ➔ Hệ số nhân **x2.0** | Giá: **1,500 Wins** | Mua nhanh: **99 Robux**
*   🟣 `trail_purple`  | **Vệt Sáng Tím** ➔ Hệ số nhân **x3.0** | Giá: **5,000 Wins** | Mua nhanh: **199 Robux**
*   🔴 `trail_red`     | **Vệt Sáng Đỏ** ➔ Hệ số nhân **x4.0** | Giá: **25,000 Wins**| Mua nhanh: **299 Robux**
*   🌈 `trail_rainbow` | **Vệt Sáng Cầu Vồng** ➔ Hệ số nhân **x5.0** | Giá: **100,000 Wins**| Mua nhanh: **499 Robux**
*   🌌 `trail_galaxy`  | **Vệt Sáng Thiên Hà** ➔ Hệ số nhân **x10.0**| Giá: **500,000 Wins**| Mua nhanh: **799 Robux**

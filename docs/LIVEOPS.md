# LiveOps — nhịp vận hành cho một người, chạy bằng Open Cloud

> Tài liệu này nói **sau khi publish thì mỗi tuần làm gì**. Phần tạo API key và cấp scope nằm
> ở [`OPEN_CLOUD.md`](OPEN_CLOUD.md); phần đi tới ngày publish nằm ở [`LAUNCH_PLAN.md`](LAUNCH_PLAN.md).
> Viết 2026-08-24.

LiveOps của studio lớn là một đội. Của một người thì nó phải là **một nhịp lặp ngắn, làm
được trong ~3 giờ/tuần, và phần lớn chạy bằng lệnh** — vì thứ giết solo dev không phải thiếu ý
tưởng mà là mỗi lần cập nhật đều phải mở Studio, bấm mười chỗ, rồi quên mất một chỗ.

---

## 0. Ba số hiệu phải thuộc

| Thứ | ID |
|---|---|
| Universe **QA** | `10648253073` |
| Place **QA** | `134428972694212` |
| Universe **LIVE** | `10456737957` |
| Place **LIVE** | `94107323826144` |
| Group sở hữu | `675923086` |

⛔ **Ràng buộc lớn nhất của dự án này:** QA và Live là **hai universe riêng**. Toàn bộ gamepass
và dev product **chỉ tồn tại ở universe Live** — dashboard QA trống trơn. Roblox đã tắt
cross-game sale từ 2026-05-29, nên **không thể test thanh toán ở QA**. Hộp mua vẫn hiện đúng
tên và giá trong QA (vì `GetProductInfo` tra theo ID thì universe nào cũng tra được) — cái bị
chặn là bước **trừ tiền**. Xem `src/shared/Util/Env.luau`.

⇒ Hệ quả cho vận hành: **mọi thay đổi liên quan tới tiền chỉ nghiệm thu được trên Live.** Đó là
lý do mục 4 dưới đây tồn tại.

---

## 1. Chỉ nhìn ba con số

Creator Hub → Analytics. Đừng đọc hết bảng — mỗi con số dưới đây gắn với **một hành động duy
nhất**, và nếu không có hành động thì đừng nhìn.

| Số | Ngưỡng | Nếu dưới ngưỡng thì làm gì |
|---|---|---|
| **D1 retention** | < 20% | Sửa 5 phút đầu (FTUE), **cấm tiêu tiền quảng cáo**. Tiền đổ vào cái phễu thủng chỉ mua về churn |
| **Average session** | < 8 phút | Vấn đề ở vòng lặp/nhịp, không phải ở nội dung. Thêm món mới không cứu được |
| **Conversion %** | < 1% | Vấn đề ở storefront hoặc giá, không phải ở số lượng món bán |

Thêm một số của riêng game này: **funnel onboarding** (`TelemetryService` đã bắn
`LogOnboardingFunnelStepEvent`). Bước nào rụng nhiều nhất thì sửa đúng bước đó, publish, đo lại.
Sửa hai bước cùng lúc là mất khả năng biết bước nào ăn.

---

## 2. Nhịp tuần

Cố định thứ trong tuần. Nhịp quan trọng hơn khối lượng — Roblox và người chơi đều thưởng cho
sự đều đặn, không thưởng cho một bản update to sau ba tháng im lặng.

| Ngày | Việc | Thời gian |
|---|---|---|
| **Thứ 2** | Đọc Error Report + 3 số ở mục 1. Ghi ra ĐÚNG MỘT việc sẽ sửa tuần này | 20 phút |
| **Thứ 3–5** | Làm việc đó. Test ở QA | ~2 giờ |
| **Thứ 6** | Publish QA → chạy hồi quy (`docs/REGRESSION.md`) → publish Live → đổi tag `[UPD n]` ở tiêu đề → đăng patch note vào mô tả | 40 phút |
| **Thứ 7** | Thả 1 mã quà mới. Xem 100 phiên đầu sau update có crash không | 15 phút |
| **Chủ nhật** | Nghỉ. Nếu Live cháy thì mục 5 | — |

**Mỗi bản update phải có đúng ba thứ:** một món mới để thèm, một mã quà mới, một dòng patch
note. Thiếu mã quà thì không ai vào group; thiếu patch note thì thuật toán không thấy game
"còn sống".

⚠️ Mã quà: **không phát Wins** (xem `Config/Economy/Codes.luau` — phát Wins là mở cửa sau phá
đúng phép siết mà bảng daily đã làm). Phát Speed + vé quay.

---

## 3. Bốn công thức Open Cloud dùng thật

Cần `$env:ROBLOX_OPEN_CLOUD_KEY` — xem [`OPEN_CLOUD.md`](OPEN_CLOUD.md).

> ⚠️ **Dùng PowerShell, đừng dùng `curl`.** Trên máy này `curl` trả `HTTP 415` với body rỗng
> cho endpoint Luau Execution, dù request hoàn toàn hợp lệ. Các endpoint GET thì `curl` gọi
> bình thường, nên lỗi này rất dễ tưởng là mình gửi sai. `Invoke-RestMethod` chạy ngay.

### 3.1. Người chơi báo "mất Wins" — đọc thẳng profile, không cần vào Studio

```powershell
$u = 10456737957            # Live
$k = @{ "x-api-key" = $env:ROBLOX_OPEN_CLOUD_KEY }
Invoke-RestMethod -Headers $k `
  "https://apis.roblox.com/cloud/v2/universes/$u/data-stores/ProfileStore/entries/Player_<USERID>"
```

Đây là cách duy nhất trả lời được câu "họ mất thật hay họ nhớ nhầm" mà không phải đoán. Ghi lại
số đọc được trước khi đền bù — đền xong mới đọc thì mất luôn bằng chứng.

### 3.2. Chạy Luau trên **place Live đang chạy thật**

Thứ MCP Studio không làm được: MCP chỉ nói chuyện với cửa sổ Studio trên máy này, còn cái này
chạy trên server Roblox thật, trên **bản đã publish**.

```powershell
$u = 10648253073; $p = 134428972694212     # QA — đổi sang Live khi đã chắc tay
$k = @{ "x-api-key" = $env:ROBLOX_OPEN_CLOUD_KEY }
# ⚠️ ĐỌC FILE BẰNG [System.IO.File]::ReadAllText — KHÔNG dùng Get-Content -Raw.
#    PowerShell 5.1: chuỗi từ Get-Content mang NoteProperty, ConvertTo-Json sinh ra
#    {"script":{"value":"..."}} và API báo "must contain a luauExecutionSessionTask".
$body = @{ script = [System.IO.File]::ReadAllText("C:\path\probe.luau") } | ConvertTo-Json
$task = Invoke-RestMethod -Method Post -Headers $k -ContentType "application/json" -Body $body `
  "https://apis.roblox.com/cloud/v2/universes/$u/places/$p/luau-execution-session-tasks"
# Poll tới khi state != PROCESSING; kết quả nằm ở output.results
Invoke-RestMethod -Headers $k "https://apis.roblox.com/cloud/v2/$($task.path)"
```

**Đo được:** số instance/part/mesh, thuộc tính, dữ liệu DataStore — tức chi phí nội dung và
trạng thái server.
**KHÔNG đo được:** FPS hay bất cứ thứ gì phía client — session này **không có client**. FPS
vẫn phải đo trên máy thật.

### 3.3. Publish bằng lệnh

```powershell
rojo build default.project.json -o build.rbxl
$u = 10648253073; $p = 134428972694212
Invoke-RestMethod -Method Post `
  -Headers @{ "x-api-key" = $env:ROBLOX_OPEN_CLOUD_KEY } `
  -ContentType "application/octet-stream" `
  -InFile build.rbxl `
  "https://apis.roblox.com/universes/v1/$u/places/$p/versions?versionType=Published"
```

⚠️ **Nhưng ở dự án này KHÔNG publish bằng đường đó được cho phần map.** Map (Workspace) nằm
trong `SpeedEscape.rbxl`, không do Rojo sinh ra — `rojo build` chỉ đóng gói `src/`. Publish
bằng lệnh sẽ **thay map bằng một place rỗng**. Đường đúng: Studio → File → Publish to Roblox.
Chỉ dùng lệnh trên nếu sau này map được đưa hết vào Rojo.

### 3.4. Đòn bẩy LiveOps mạnh nhất: đổi hệ số event **không cần publish**

`RemoteConfigService` đọc Roblox Configs mỗi 60 giây, nên bật một sự kiện x2 cuối tuần chỉ là
sửa 4 ô trên Creator Hub → **Configs**:

| Key | Kiểu | Ví dụ |
|---|---|---|
| `event_enabled` | bool | `true` |
| `event_name` | string | `WEEKEND RUSH` |
| `event_speed_multiplier` | number | `2` |
| `event_wins_multiplier` | number | `1` |

Tới server sau ~15 giây–1 phút, cộng tối đa 60 giây nữa. Hệ số bị **kẹp trong `[MIN, MAX]`** ở
server — gõ nhầm `100` thay vì `1.0` sẽ bị chặn chứ không thổi bay nền kinh tế. Đây là lớp bảo
vệ có chủ đích, **đừng gỡ**.

> 💡 **Tạo cả 4 key này ngay cả khi chưa chạy event.** Key không tồn tại thì engine in
> `ConfigService: Config value not found for key "..."` mỗi lần refresh — lần đo 2026-08-21 nó
> chiếm **396 dòng** trong Error Report và đẩy lỗi thật xuống dưới. Fallback vẫn đúng, nhưng
> tiếng ồn đó làm mù chính cái bảng bạn phải đọc mỗi thứ 2.

---

## 4. Nghiệm thu thanh toán — chỉ làm được trên Live

Vì QA không bán được (mục 0), mỗi lần đụng vào code tiền phải chạy đúng vòng này:

1. Publish Live.
2. Tự mua **món rẻ nhất** (Spin 1 vé, 19 R$) bằng tài khoản thật.
3. Xác nhận quà **vào tay** — không chỉ xem banner chúc mừng.
4. Đọc log `[GamepassService] … mua pass … thành công` (đây là `Log.Info`, luôn in).
5. Chỉ khi bước 3 xong mới coi như đường tiền còn sống.

Robux tự mua của mình quay lại ví sau khi trừ phí nền tảng, nên đây là phép thử rẻ. **Bỏ qua
bước này là cách phổ biến nhất để phát hiện đường tiền chết sau khi đã mất một tuần traffic.**

---

## 5. Sự cố — làm gì trong 10 phút đầu

| Triệu chứng | Việc làm NGAY | Rồi mới |
|---|---|---|
| Người chơi mất dữ liệu | **Ngừng publish.** Đọc profile bằng 3.1 để xem hư ở DataStore hay ở hiển thị | Sửa xong test ở QA rồi mới đẩy |
| Kinh tế lạm phát (ai cũng giàu bất thường) | Đặt `event_enabled = false` (3.4) — có tác dụng sau ~1 phút, **không cần publish** | Truy nguồn rồi mới bật lại |
| Bản mới gây crash | **Rollback bằng Version History** trên Creator Dashboard, không phải bằng cách sửa vội rồi publish đè | Tìm nguyên nhân ở QA |
| Lỗi lạ tràn Error Report | Phân loại theo **severity trước, count sau** | Bảng xếp theo số lần nên một cảnh báo vô hại lặp nhiều sẽ chôn lỗi thật |

**Rollback luôn rẻ hơn hotfix.** Một bản publish vội lúc 11 giờ đêm để chữa crash thường tạo
ra crash thứ hai.

---

## 6. Bẫy đã trả giá — đừng vấp lại

- **`curl` trả 415 vô nghĩa** cho Luau Execution → dùng `Invoke-RestMethod`.
- **`Get-Content -Raw` + `ConvertTo-Json`** sinh `{"script":{"value":…}}` → dùng
  `[System.IO.File]::ReadAllText`.
- **Key chỉ cấp scope QA.** Muốn chạm Live thì cấp key riêng, và cân nhắc tài khoản phụ — key
  mang quyền của chủ nhân nó, mà tài khoản bạn là chủ group.
- **Đừng để `No Expiration`.** Key không hạn là key sẽ sống mãi trong một file ai cũng quên.
- **Luau Execution không có client** → mọi kết luận về FPS từ đó đều sai.
- **`default.project.json` KHÔNG có `Workspace`.** Đã kiểm: nó chỉ map `src/` + `Packages` vào
  ReplicatedStorage / ServerScriptService / StarterPlayer / ReplicatedFirst. Nghĩa là
  `rojo build` sinh ra một place **không có map**, và publish nó bằng lệnh sẽ xoá sạch thế
  giới game. Map chỉ tồn tại dưới dạng snapshot `SpeedEscape.rbxl` (được `.gitignore` cho
  ngoại lệ giữ lại) và trong chính place trên Roblox.

---

## Liên quan

- [`OPEN_CLOUD.md`](OPEN_CLOUD.md) — tạo key, cấp scope, thu hồi
- [`LAUNCH_PLAN.md`](LAUNCH_PLAN.md) — bốn giai đoạn tới ngày ra mắt
- [`REGRESSION.md`](REGRESSION.md) — danh sách chạy tay trước mỗi lần publish
- [`ECONOMY_REVIEW.md`](ECONOMY_REVIEW.md) — nền kinh tế, đọc trước khi chỉnh hệ số event

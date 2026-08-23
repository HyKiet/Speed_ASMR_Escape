# Open Cloud — tạo key và nối cho AI dùng

> Mục đích: cho AI (Claude) gọi được Roblox Open Cloud từ máy này mà **không bao giờ nhìn thấy
> nội dung key**. Đã probe 2026-08-21: mạng từ máy này tới `apis.roblox.com` thông, chỉ thiếu key.

## 0. Số hiệu cần nhớ

| Thứ | ID |
|---|---|
| Universe QA | `10648253073` |
| Place QA (start place) | `134428972694212` |
| Universe Live | `10456737957` |
| Place Live | `94107323826144` |
| Group sở hữu | `675923086` |

Game thuộc **group**, nhưng key thì tạo bằng **User API Key** — xem mục 1.

## 1. Tạo API key — dùng *User*, không dùng *Group*

Trang API Keys hiện cảnh báo *"Group API Keys are not recommended"*. Sửa lại hướng dẫn cũ
(2026-08-21 tôi ghi "phải tạo dưới group" — sai): bấm **Create User API Key**.

**Vì sao User mà vẫn chạm được game của group:** phạm vi của key được chọn theo **từng
universe** ở bước 3, không theo chủ sở hữu key. Tài khoản của bạn có quyền edit universe
`10648253073` nên nó hiện ra trong danh sách chọn, và key thừa hưởng quyền đó.

**Vì sao Roblox không khuyên dùng Group key:** Group API Key gắn với chính *group*, nên mọi
người có quyền quản trị group đều thấy và sửa được nó, và mọi lời gọi ghi log dưới danh
nghĩa group — không truy được ai đã làm gì. User key gắn với một tài khoản: thu hồi là xong,
và log chỉ ra đúng danh tính.

> Roblox còn khuyên dùng **tài khoản phụ** cho key đụng tới tài nguyên group. Lý do: key này
> mang quyền của chủ nhân nó, mà tài khoản của bạn là chủ group — tài khoản phụ chỉ được mời
> vào group với đúng quyền cần thiết thì key rò rỉ cũng không kéo theo cả group. Với key chỉ
> đọc DataStore QA + publish QA thì mức rủi ro này chấp nhận được; nếu sau này cấp thêm scope
> vào **Live** thì hãy lập tài khoản phụ.

1. Vào <https://create.roblox.com/dashboard/credentials> → tab **API Keys** → **Create User API Key**.
2. **Name:** `speedescape-ai-qa` (đặt tên nói rõ ai dùng — sau này thu hồi khỏi nhầm).
3. **Access Permissions** — bấm **Add API System**, mỗi lần chọn MỘT dòng dưới đây trong ô
   *Select API System*, rồi trong mục đó chọn universe **QA** (`10648253073`) và tích operation:

   | API System (tên đúng trong dropdown) | Operations cần tích | Để làm gì |
   |---|---|---|
   | `universe` | `read` | Lệnh kiểm tra ở mục 3 gọi đúng endpoint này |
   | `universe-datastores` | `read`, `list` | Soi profile ProfileStore của QA |
   | `luau-execution-sessions` | `write` | Chạy Luau trên place QA đang chạy thật |
   | `universe-places` | `write` | Publish `.rbxl` lên QA bằng lệnh |

   ⚠️ Dropdown có cả nhóm `legacy-*` (`legacy-universes`, `legacy-assets`…). **Bỏ qua hết** —
   đó là API v1 đời cũ, không phải thứ `cloud/v2` dùng.

   ⛔ **Không thêm** bất cứ mục nào trỏ vào universe **Live** (`10456737957`). Key này để thử
   ở QA; một lệnh gọi nhầm vào Live là người chơi thật lãnh. Cần thì cấp sau.

4. **Security → Restrict which IP addresses** — bật lên rồi dán IP công cộng của máy này:
   ```powershell
   (Invoke-RestMethod https://api.ipify.org?format=json).ip
   ```
   Mạng nhà đổi IP liên tục thì để tắt cũng được, nhưng bù lại đừng nới hạn dùng ở bước sau.

5. **Expiration:** chọn **30 Days From Now** (đừng để `No Expiration` — key không hạn là key
   sẽ sống mãi trong một file nào đó ai cũng quên). Roblox còn tự thu hồi sau 60 ngày không
   dùng tới.

6. **Save & Generate Key** → copy chuỗi hiện ra. **Chỉ hiện đúng một lần.**

## 2. Nối vào máy — đừng dán key vào chat

Chạy trong PowerShell (thay `<KEY>`):

```powershell
setx ROBLOX_OPEN_CLOUD_KEY "<KEY>"
```

Rồi **mở lại VSCode/terminal** (biến `setx` chỉ có hiệu lực với tiến trình mở sau đó).

Vì sao kiểu này: AI gọi lệnh dạng `$env:ROBLOX_OPEN_CLOUD_KEY` — hệ điều hành thay giá trị vào
lúc chạy, còn key **không bao giờ nằm trong đoạn chat, trong file, hay trong git**. Dán thẳng key
vào chat là coi như đã lộ (transcript lưu lại) và phải thu hồi ngay.

Cách khác nếu không muốn đặt biến hệ thống: tạo file `.env` ở gốc repo với dòng
`ROBLOX_OPEN_CLOUD_KEY=<KEY>` — `.gitignore` đã chặn file này. Kém an toàn hơn một bậc (key nằm
trên đĩa dạng chữ thường), nhưng vẫn không lọt vào git.

## 3. Kiểm tra đã thông

```powershell
curl.exe -s -o NUL -w "%{http_code}`n" `
  -H "x-api-key: $env:ROBLOX_OPEN_CLOUD_KEY" `
  https://apis.roblox.com/cloud/v2/universes/10648253073
```

| Mã | Nghĩa |
|---|---|
| `200` | Xong, dùng được |
| `401` | Máy không thấy biến — mở lại terminal, hoặc `setx` chưa chạy |
| `403` | Key đúng nhưng **thiếu scope** hoặc **IP không nằm trong danh sách** |
| `404` | Sai universe id |

## 4. Nó mở thêm được những gì

- **Đọc DataStore của QA** — xem thẳng profile ProfileStore của một người chơi mà không cần vào
  Studio (soi bug kiểu "mất Wins", "pad tụt cấp").
- **Luau Execution** — chạy một đoạn Luau trên place QA đã publish. Cái này chạm được vào
  **place thật đang chạy trên server Roblox** — thứ MCP Studio không làm được (MCP chỉ nói
  chuyện với cửa sổ Studio đang mở trên máy này).
- **Place Management** — publish `.rbxl` bằng lệnh, tức là CI đẩy được lên QA tự động.

## 5. Khi nào phải thu hồi

Vào lại trang API Keys → chọn key → **Delete**. Làm ngay nếu: key bị dán vào chat/screenshot,
laptop cho người khác mượn, hoặc đơn giản là đã xong việc cần key.

Vì đây là **User key**, thu hồi chỉ chạm tới key đó — game, group và các key khác không bị
ảnh hưởng. Đó chính là cái Group key không cho bạn.

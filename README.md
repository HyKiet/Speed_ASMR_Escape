# +1 Speed Escape

Speed Simulator × Obby trên Roblox.

## Chạy dự án

```bash
rojo serve      # rồi Connect từ plugin Rojo trong Studio
```

Rojo sync **một chiều**: VSCode → Studio. Đừng sửa script trong Studio.

## Cấu trúc

```
src/client   LocalScript, UI (Fusion)
src/server   Services
src/shared   Config, Network, Util
docs/        Tài liệu nội bộ
```

Thiết kế game: `GDD.md`. Trước khi publish: `docs/REGRESSION.md`.

> Repo chứa **code**, không chứa **map**. Thế giới game sống trên place Roblox;
> `SpeedEscape.rbxl` chỉ là snapshot sao lưu.

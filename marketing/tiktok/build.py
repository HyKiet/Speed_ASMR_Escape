#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Dựng clip TikTok 9:16 từ footage thô + kịch bản trong scripts.json.

    python build.py --check              # xem cảnh nào đã quay, cảnh nào chưa
    python build.py A1_melody            # dựng 1 clip
    python build.py all                  # dựng mọi clip có footage
    python build.py A1_melody --in 4.2 --out 13.8   # chọn lại điểm cắt
    python build.py B1_greed_win --no-vo # xuất bản KHÔNG giọng (để dán TTS của TikTok)

Cần: ffmpeg trong PATH, và `pip install edge-tts` cho các clip có giọng đọc.

Vì sao viết bằng ffmpeg chứ không phải CapCut: mỗi clip dựng lại được từ đúng một dòng lệnh.
Sửa một câu thoại trong scripts.json rồi chạy lại là ra bản mới y hệt — không phải nhớ mình đã
kéo cái gì ở đâu. Với nhịp 2 clip/ngày trong 21 ngày thì đó là khác biệt sống còn.
"""

import argparse
import json
import re
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(ROOT, "raw")
OUT = os.path.join(ROOT, "out")
TMP = os.path.join(ROOT, ".tmp")

W, H = 1080, 1920  # khung dọc chuẩn TikTok

# Console Windows mặc định là cp1252 — in tiếng Việt ra là ném UnicodeEncodeError giữa chừng.
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


def sh(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", **kw)
    if r.returncode != 0:
        sys.stderr.write(r.stderr[-4000:] + "\n")
        raise SystemExit(f"Lệnh hỏng: {' '.join(cmd[:3])} ...")
    return r


def load():
    with open(os.path.join(ROOT, "scripts.json"), encoding="utf-8") as f:
        return json.load(f)


def esc_path(p):
    """Đường dẫn nằm TRONG chuỗi filter của ffmpeg: dấu : và \\ phải escape."""
    return p.replace("\\", "/").replace(":", r"\:")


def loudnorm(inputs, a_pre, lufs):
    """
    loudnorm HAI LƯỢT: đo trước, rồi mới nắn.

    Một lượt thì loudnorm phải đoán độ to trong lúc chạy, và với nguồn dải động hẹp như
    tiếng sàn ASMR nó đoán hụt — bản thử ra -18.3 LUFS thay vì -14. Trên TikTok, clip nằm
    kề clip: cái nào nhỏ tiếng hơn thì bị nghe thành "chất lượng kém hơn", dù nội dung y hệt.
    Lượt đo tốn ~2 giây, đáng.
    """
    probe = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", *inputs, "-filter_complex",
         a_pre + f";[apre]loudnorm=I={lufs}:TP=-1.5:LRA=11:print_format=json[a]",
         "-map", "[a]", "-f", "null", "-"],
        capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=ROOT)
    m = re.search(r"\{[^{}]*input_i[^{}]*\}", probe.stderr, re.S)
    base = f"loudnorm=I={lufs}:TP=-1.5:LRA=11"
    if not m:
        return base
    j = json.loads(m.group(0))
    if j.get("input_i") in ("-inf", "inf"):
        return base
    return (f"{base}:measured_I={j['input_i']}:measured_TP={j['input_tp']}"
            f":measured_LRA={j['input_lra']}:measured_thresh={j['input_thresh']}"
            f":offset={j['target_offset']}:linear=true")


def make_vo(clip, d, voice, rate):
    """Đọc từng dòng thoại thành file mp3 riêng. Trả về [(đường dẫn, giây bắt đầu)]."""
    out = []
    for i, line in enumerate(clip.get("vo") or []):
        mp3 = os.path.join(TMP, f"{clip['id']}_vo{i}.mp3")
        sh([sys.executable, "-m", "edge_tts",
            "--voice", voice, f"--rate={rate}",
            "--text", line["s"], "--write-media", mp3])
        out.append((mp3, float(line["t"])))
    return out


def int_fps(fx):
    return str(int(fx.get("fps", 60)))


def build(clip, d, args):
    src = os.path.join(RAW, clip["source"])
    if not os.path.exists(src):
        print(f"  bỏ qua {clip['id']}: chưa có {clip['source']}")
        return False

    t_in = args.t_in if args.t_in is not None else float(clip.get("in") or 0)
    t_out = args.t_out if args.t_out is not None else float(clip.get("out") or 0)
    if not clip.get("segments") and t_out <= t_in:
        raise SystemExit(f"{clip['id']}: điểm cắt không hợp lệ (in={t_in} out={t_out})")
    dur = t_out - t_in

    voice = clip.get("voice", d["voice"])
    rate = clip.get("rate", d["rate"])
    want_vo = bool(clip.get("vo")) and not args.no_vo
    vo = make_vo(clip, d, voice, rate) if want_vo else []

    #  NHIỀU ĐOẠN GHÉP LẠI (`segments`).
    #
    #  Bản một-đoạn cắt được chỗ đẹp nhất, nhưng với clip sàn cát thì "chỗ đẹp nhất" là hai
    #  chỗ RỜI NHAU: đoạn đi bộ TẠO ra vết chân, và đoạn đứng im vết TỰ LÀNH. Giữa hai đoạn
    #  là quãng camera quét qua góc nhìn thứ nhất — không dùng được. Mà bỏ đoạn đầu thì đoạn
    #  sau mất nghĩa: người xem thấy cát tự phẳng ra mà không hiểu vết ở đâu ra.
    #
    #  Nối bằng `xfade`/`acrossfade` 0.3s chứ không cắt phựt: hai đoạn cùng một khung cảnh,
    #  cắt phựt sẽ đọc ra như lỗi tua chứ không như một cú chuyển cảnh.
    segs = clip.get("segments")
    xf = float(clip.get("xfade", 0.3)) if segs else 0.0
    pre_v, pre_a_seg = "", ""
    vsrc, asrc = "0:v", "0:a"
    if segs:
        dur = sum(float(g["out"]) - float(g["in"]) for g in segs) - xf * (len(segs) - 1)
        inputs = ["-i", src]
        for i, g in enumerate(segs):
            # delogo khai trong TỪNG đoạn, không khai chung cho cả clip: ô xoá con trỏ nằm
            # giữa khung, mà giữa khung ở đoạn đi bộ chính là chỗ nhân vật đứng — đặt chung
            # là bôi nhoè luôn cái đầu nhân vật (user báo 2026-08-26).
            gd = g.get("delogo")
            gs = f",delogo=x={gd['x']}:y={gd['y']}:w={gd['w']}:h={gd['h']}" if gd else ""
            pre_v += (f"[0:v]trim=start={g['in']}:end={g['out']},setpts=PTS-STARTPTS{gs}[sv{i}];")
            pre_a_seg += (f"[0:a]atrim=start={g['in']}:end={g['out']},asetpts=PTS-STARTPTS[sa{i}];")
        cv, ca = "sv0", "sa0"
        off = float(segs[0]["out"]) - float(segs[0]["in"]) - xf
        for i in range(1, len(segs)):
            pre_v += (f"[{cv}][sv{i}]xfade=transition=fade:duration={xf}:offset={off}[xv{i}];")
            pre_a_seg += f"[{ca}][sa{i}]acrossfade=d={xf}:c1=tri:c2=tri[xa{i}];"
            cv, ca = f"xv{i}", f"xa{i}"
            off += float(segs[i]["out"]) - float(segs[i]["in"]) - xf
        vsrc, asrc = cv, ca
    else:
        inputs = ["-ss", str(t_in), "-t", str(dur), "-i", src]
    for mp3, _ in vo:
        inputs += ["-i", mp3]

    # ---- hình ----
    # Cắt bỏ viền cửa sổ Windows TRƯỚC mọi thứ khác. Game Bar quay cả thanh tiêu đề Roblox
    # ở trên và taskbar ở dưới; khung cắt giữa 9:16 lấy trọn chiều cao nên hai thứ đó đi
    # thẳng vào clip nếu không bỏ ở đây.
    ins = {**d.get("inset", {}), **clip.get("inset", {})}
    top, bot = int(ins.get("top", 0)), int(ins.get("bottom", 0))
    # delogo: xoá con trỏ chuột đứng yên giữa khung. Nó nội suy từ viền quanh ô nên chỉ ăn
    # khi con trỏ KHÔNG di chuyển và nền quanh nó trơn (mặt cát) — đúng cả hai ở đây.
    dl = clip.get("delogo")
    dls = f",delogo=x={dl['x']}:y={dl['y']}:w={dl['w']}:h={dl['h']}" if dl else ""
    pre = pre_v + (f"[{vsrc}]crop=iw:ih-{top + bot}:0:{top}{dls}[src];" if (top or bot)
                   else f"[{vsrc}]null{dls}[src];")

    framing = clip.get("framing", "crop")
    if framing == "blur":
        # Giữ trọn khung hình gốc, lấp trên dưới bằng chính nó làm mờ.
        # Dùng cho cảnh cần thấy hai bên (Studio/Explorer), nơi cắt giữa sẽ mất thông tin.
        v = (pre + f"[src]split=2[bg][fg];"
             f"[bg]scale={W}:{H}:force_original_aspect_ratio=increase,crop={W}:{H},"
             f"gblur=sigma=28,eq=brightness=-0.12[bgb];"
             f"[fg]scale={W}:-2[fgs];[bgb][fgs]overlay=(W-w)/2:(H-h)/2[v0]")
    else:
        # Mặc định: cắt cột giữa rồi phóng full-bleed. Đây cũng là thứ tự động
        # loại bỏ nút menu + khung chat Roblox ở góc trên trái.
        #
        # `region` = cắt một cửa sổ NHỎ HƠN chiều cao khung rồi phóng lên. Đây là zoom
        # quang học giả lập, dùng khi máy quay đặt quá xa lúc quay: đổi độ nét lấy bố cục.
        # Bản render Roblox tô phẳng, ít chi tiết tần số cao, nên chịu phóng 2× vẫn sạch —
        # với footage thật (nhiều noise) thì mẹo này hỏng.
        rg = clip.get("region")
        if rg:
            rh = int(rg["h"])
            rw = int(rh * 9 / 16) // 2 * 2
            v = (pre + f"[src]crop={rw}:{rh}:(iw-{rw})/2:{int(rg.get('y', 0))},"
                 f"scale={W}:{H}:flags=lanczos,setsar=1[v0]")
        else:
            v = (pre + f"[src]crop=ih*9/16:ih:(iw-ih*9/16)/2:0,"
                 f"scale={W}:{H}:flags=lanczos,setsar=1[v0]")

    # ---- đẩy máy chậm (slow push-in) ----
    # Vì sao là hiệu ứng DUY NHẤT trên clip ASMR: nó thêm chuyển động mà không thêm tiếng
    # động nào. Zoom giật / chớp sáng / rung khung đều buộc mắt phải làm việc, mà clip ASMR
    # sống bằng chuyện người xem thả lỏng. 6% trong 9 giây thì không ai chỉ ra được là có
    # zoom — họ chỉ thấy khung hình "có sức sống".
    fx = {**d.get("effects", {}), **clip.get("effects", {})}
    zoom = float(fx.get("zoom", 0) or 0)
    punch = float(fx.get("punch", 0) or 0)
    if zoom > 0 or punch > 0:
        fps = int(fx.get("fps", 60))
        frames = max(2, int(round(dur * fps)))
        big = int(W * (1 + max(zoom, punch))) // 2 * 2
        #  Đường đi của cỡ khung:  1+punch → 1.0 → 1+zoom → 1+punch
        #                          (thụt vào)  (đẩy chậm)   (dấn tới)
        #
        #  ĐẦU CLIP — cú thụt vào 0.45s: khung mở ra to hơn 10% rồi lùi về đúng cỡ. Đây là
        #  chuyển động ở khung hình ĐẦU TIÊN, chỗ người xem quyết định vuốt hay ở lại.
        #
        #  CUỐI CLIP — dấn tới 0.5s, kết thúc ĐÚNG CỠ MÀ CLIP BẮT ĐẦU. Đây mới là phần đáng
        #  nói: TikTok tự phát lại từ đầu, và lượt xem-lại được cộng dồn vào thời gian xem.
        #  Hiệu ứng kết kiểu mờ ra đen chặt đứt vòng lặp; còn kết đúng cỡ khung ban đầu thì
        #  mối nối biến mất — clip 9 giây được xem 2–3 vòng thành 18–27 giây trong mắt thuật
        #  toán. Vì vậy cú dấn cuối KHÔNG lùi về 1.0: nó phải về 1+punch mới khớp.
        a_frac = min(0.45, float(fx.get("punch_s", 0.45))) / dur if punch > 0 else 0.0
        b_frac = min(0.6, float(fx.get("settle_s", 0.5))) / dur if zoom > 0 else 0.0
        z_end = 1 + punch if punch > 0 else 1.0
        seg_body = f"1+{zoom}*(ld(0)-{a_frac})/{max(1e-6, 1 - b_frac - a_frac)}"
        seg_in = f"1+{punch}*pow((1-ld(0)/{max(1e-6, a_frac)}),2)" if a_frac > 0 else "1"
        seg_out = (f"{1 + zoom}+{z_end - 1 - zoom}*(1-pow((1-ld(0))/{max(1e-6, b_frac)},2))"
                   if b_frac > 0 else seg_body)
        z = (f"st(0,on/{frames - 1}); "
             f"if(lt(ld(0),{a_frac}), {seg_in}, "
             f"if(gt(ld(0),{1 - b_frac}), {seg_out}, {seg_body}))")
        v += (f";[v0]scale={big}:-2:flags=lanczos,"
              f"zoompan=z='{z}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':"
              f"d=1:s={W}x{H}:fps={fps},setsar=1[v0z]")
        last_v = "v0z"
    else:
        last_v = "v0"

    font = esc_path(clip.get("font", d["font"]))
    y = clip.get("text_y", d["text_y"])
    last = last_v
    anim = bool(fx.get("text_anim", True))
    for i, t in enumerate(clip.get("text") or []):
        tf = os.path.join(TMP, f"{clip['id']}_txt{i}.txt")
        with open(tf, "w", encoding="utf-8") as f:
            f.write(t["s"])
        rel = esc_path(os.path.relpath(tf, ROOT))
        st, en = float(t["t"]), float(t["t"]) + float(t["d"])
        if anim:
            # Mờ dần vào/ra 0.28s + trượt lên 20px. Chữ hiện đột ngột là dấu hiệu rõ nhất
            # của video dựng ẩu; 0.28s đủ để mắt thấy "mượt" mà chưa kịp thấy "chậm".
            k = f"min(1\\,max(0\\,(t-{st})/0.28))"
            alpha = f"{k}*min(1\\,max(0\\,({en}-t)/0.28))"
            ypos = f"{y}+20*(1-{k})"
        else:
            alpha, ypos = "1", str(y)
        # borderw thay vì box: chữ viền đen đọc được trên mọi nền mà không thành cái nhãn
        # đen chình ình — đúng yêu cầu "vừa phải, tự nhiên".
        # TỰ CO CỠ CHỮ. Segoe UI Black rộng ~0.56×cỡ chữ mỗi ký tự; câu 30 ký tự ở cỡ 74
        # cần ~1250px trong khi khung chỉ rộng 1080 ⇒ cụt hai đầu. drawtext KHÔNG tự xuống
        # dòng và cũng không báo lỗi, nó cứ vẽ tràn ra ngoài — nên phải chặn ở đây.
        base = int(t.get("fontsize", fx.get("fontsize", 74)))
        fit = int((W - 96) / (0.56 * max(1, len(t["s"]))))
        size = max(34, min(base, fit))
        v += (f";[{last}]drawtext=fontfile='{font}':textfile='{rel}':"
              f"fontcolor=white:fontsize={size}:borderw=7:bordercolor=black@0.9:"
              f"alpha='{alpha}':x=(w-text_w)/2:y='{ypos}':"
              f"enable='between(t,{st},{en})'[t{i}]")
        last = f"t{i}"

    # ---- thẻ kết: ảnh game trên nền chính clip làm mờ ----
    # Nền mờ lấy TỪ CHÍNH khung hình đang chạy chứ không phải một mảng màu: cảnh vẫn động
    # phía sau nên mắt không thấy video "dừng lại", chỉ thấy nó lùi ra sau.
    ec = clip.get("endcard")
    if ec:
        ec_path = os.path.join(ROOT, ec["image"])
        inputs += ["-loop", "1", "-framerate", int_fps(fx), "-t", str(dur), "-i", ec_path]
        ei = len(inputs) // 2 - 1 if False else (1 + len(vo))
        at = float(ec.get("at", dur - 2.2))
        fd = float(ec.get("fade", 0.45))
        cw = int(W * float(ec.get("w", 0.66))) // 2 * 2
        v += (f";[{last}]split=2[ecm][ecb]"
              f";[ecb]gblur=sigma={ec.get('blur', 26)},eq=brightness={ec.get('dim', -0.22)},"
              f"format=yuva420p,fade=t=in:st={at}:d={fd}:alpha=1[ecbf]"
              f";[ecm][ecbf]overlay=0:0:enable='gte(t,{at})'[ecv]"
              f";[{ei}:v]scale={cw}:-1,format=rgba,"
              f"fade=t=in:st={at + 0.12}:d={fd}:alpha=1[card]"
              f";[ecv][card]overlay=(W-w)/2:(H-h)/2{ec.get('y_off', -70):+d}:"
              f"enable='gte(t,{at + 0.12})'[vend]")
        last = "vend"

    # ---- tiếng ----
    lufs = float(clip.get("lufs", d["lufs"]))
    # Cắt trầm trước khi chuẩn hoá. Bản quay Game Bar có nền ù ~-36dB; loudnorm kéo cả clip
    # lên -14 nghĩa là kéo luôn nền ù lên theo. Bỏ phần dưới ~110Hz thì tiếng phím không
    # mất gì (nó nằm ở 1–6kHz) nhưng nền sạch hẳn — nghe tách được từng phím rõ hơn.
    hp = fx.get("hp_hz", 0)
    #  DẬP DẢI CHÓI (2026-08-26, user: "âm thanh bị chói tai quá").
    #
    #  Đo bằng bandpass trên chính bản quay: năng lượng dồn vào 2,5–4kHz (-8.8dB) và
    #  4,5–7kHz (-7.7dB) — đúng vùng tai người nhạy nhất. Chuẩn hoá lên -14 LUFS đẩy dải
    #  2,5–4k lên tới -2.4dB, và đó là tiếng chói.
    #
    #  Hai lỗi của bản trước cộng hưởng:
    #    • highpass 110Hz cắt sạch phần thân âm ⇒ tiếng mỏng, dải cao nổi bật hơn tương đối
    #    • ép -14 LUFS trên nguồn vốn đã sáng sẵn
    #  Nên: hạ highpass xuống 70Hz (vẫn bỏ ù, giữ thân), dập hai dải chói, và nới mục tiêu
    #  xuống -16 LUFS. ASMR nghe bằng tai nghe — to không phải là hay.
    chain = [f"highpass=f={int(hp)}"] if hp else []
    for e in (fx.get("eq") or []):
        chain.append(f"equalizer=f={e['f']}:width_type=q:w={e['q']}:g={e['g']}")
    if fx.get("lp_hz"):
        chain.append(f"lowpass=f={int(fx['lp_hz'])}")
    pre_a = ",".join(chain) if chain else "anull"
    if vo:
        duck = clip.get("duck_db", d["duck_db"])
        a_pre = pre_a_seg + f"[{asrc}]volume={duck}dB[g]"
        legs = ["[g]"]
        for i, (_, start) in enumerate(vo):
            a_pre += f";[{i + 1}:a]adelay={int(start * 1000)}|{int(start * 1000)}[v{i}]"
            legs.append(f"[v{i}]")
        a_pre += f";{''.join(legs)}amix=inputs={len(legs)}:normalize=0:dropout_transition=0[am]"
        a_pre += f";[am]{pre_a}[apre]"
    else:
        # Trụ A: tiếng game để trần, chỉ chuẩn hoá âm lượng. Không nhạc, không giọng.
        a_pre = pre_a_seg + f"[{asrc}]{pre_a}[apre]"

    # alimiter cuối chuỗi: bảo hiểm chống clip liên-mẫu sau khi mã hoá AAC. loudnorm nhắm
    # TP=-1.5 nhưng chế độ linear vẫn vượt lên ~-0.9 với nguồn nhiều transient như tiếng phím.
    a = (a_pre + ";[apre]" + loudnorm(inputs, a_pre, lufs)
         + ",alimiter=limit=0.83:level=disabled[a0]")

    dst = os.path.join(OUT, clip["id"] + ".mp4")
    sh(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", *inputs,
        "-filter_complex", v + ";" + a,
        "-map", f"[{last}]", "-map", "[a0]",
        "-c:v", "libx264", "-preset", "slow", "-crf", "18",
        "-pix_fmt", "yuv420p", "-profile:v", "high",
        "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2",
        "-movflags", "+faststart", "-shortest", dst], cwd=ROOT)

    # Caption dán thẳng vào TikTok, không phải gõ lại.
    with open(os.path.join(OUT, clip["id"] + ".txt"), "w", encoding="utf-8") as f:
        f.write(clip["caption"] + "\n\n" + clip["hashtags"] + "\n")
        if not want_vo and clip.get("vo"):
            f.write("\n--- lời thoại (dán vào text-to-speech của TikTok) ---\n")
            for line in clip["vo"]:
                f.write(f"[{line['t']}s] {line['s']}\n")

    print(f"  ✓ {clip['id']}  {dur:.1f}s  →  out/{clip['id']}.mp4")
    return True


def main():
    p = argparse.ArgumentParser()
    p.add_argument("id", nargs="?", help="id clip, hoặc 'all'")
    p.add_argument("--check", action="store_true", help="liệt kê footage đã có / còn thiếu")
    p.add_argument("--in", dest="t_in", type=float, default=None)
    p.add_argument("--out", dest="t_out", type=float, default=None)
    p.add_argument("--no-vo", action="store_true", help="xuất bản không giọng đọc")
    args = p.parse_args()

    if not shutil.which("ffmpeg"):
        raise SystemExit("Không tìm thấy ffmpeg trong PATH.")

    data = load()
    d, clips = data["defaults"], data["clips"]
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(TMP, exist_ok=True)
    os.makedirs(RAW, exist_ok=True)

    if args.check or not args.id:
        have = miss = 0
        for c in clips:
            ok = os.path.exists(os.path.join(RAW, c["source"]))
            have, miss = have + ok, miss + (not ok)
            print(f"  {'có   ' if ok else 'THIẾU'}  [{c['pillar']}] {c['id']:<20} {c['source']}")
        print(f"\n  {have} cảnh đã quay, {miss} cảnh còn thiếu.")
        if not args.id:
            return

    todo = clips if args.id == "all" else [c for c in clips if c["id"] == args.id]
    if not todo:
        raise SystemExit(f"Không có clip id '{args.id}' trong scripts.json")
    if len(todo) > 1 and (args.t_in is not None or args.t_out is not None):
        raise SystemExit("--in/--out chỉ dùng khi dựng một clip.")

    n = sum(build(c, d, args) for c in todo)
    print(f"\nDựng xong {n} clip → {os.path.relpath(OUT, os.getcwd())}")


if __name__ == "__main__":
    main()

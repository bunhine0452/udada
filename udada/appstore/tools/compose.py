"""우다다 App Store 스크린샷 합성 — 「차분한 종이 시간표」.
종이 바탕 위에 작은 꼬리표(코발트) · 가는 줄 · 부리 글꼴 머리말 · 한 줄 설명 · 실제 앱 화면(둥근 모서리 + 먹선).
그라데이션·그림자·빛 번짐·기기 틀 없음."""
import sys, json
from PIL import Image, ImageDraw, ImageFont

PAPER = (0xF1, 0xF3, 0xEE); SHEET = (0xFB, 0xFC, 0xF9); INK = (0x19, 0x22, 0x1F); INK2 = (0x56, 0x64, 0x5E)
INK3 = (0x8B, 0x96, 0x91); COBALT = (0x2E, 0x4A, 0xE3); RULE = (0xD8, 0xDE, 0xD8); MINT = (0xCD, 0xE8, 0xDD); FILL = (0xE6, 0xEA, 0xE4)
import os
HERE = os.path.dirname(os.path.abspath(__file__))
SERIF = os.path.join(HERE, "..", "..", "ios", "Udada", "Resources", "Fonts", "GowunBatang-Bold.ttf")
SANS = "/System/Library/Fonts/AppleSDGothicNeo.ttc"  # 0 Regular · 2 Medium · 4 SemiBold · 6 Bold
BASE_W, BASE_H = 1320, 2868

def font(path, size, index=0):
    return ImageFont.truetype(path, int(round(size)), index=index)

def rounded_mask(size, r, ss=4):
    w, h = size
    m = Image.new("L", (w * ss, h * ss), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w * ss - 1, h * ss - 1], radius=r * ss, fill=255)
    return m.resize((w, h), Image.LANCZOS)

def outline(canvas, box, r, width, color, ss=4):
    x, y, w, h = box
    pad = int(width) + 2
    layer = Image.new("L", ((w + 2 * pad) * ss, (h + 2 * pad) * ss), 0)
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle([pad * ss, pad * ss, (pad + w) * ss - 1, (pad + h) * ss - 1], radius=r * ss, outline=255, width=int(width * ss))
    layer = layer.resize((w + 2 * pad, h + 2 * pad), Image.LANCZOS)
    solid = Image.new("RGB", layer.size, color)
    canvas.paste(solid, (x - pad, y - pad), layer)

def tracked(draw, xy, text, f, fill, track):
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=f, fill=fill)
        x += draw.textlength(ch, font=f) + track
    return x

def place(canvas, img, box, radius, border=3.0, border_color=INK):
    x, y, w, h = box
    im = img.convert("RGB").resize((w, h), Image.LANCZOS)
    canvas.paste(im, (x, y), rounded_mask((w, h), radius))
    if border: outline(canvas, box, radius, border, border_color)

# 바탕 세 가지: 종이(기본) · 먹 · 코발트. 한 장에 한 색, 평평하게.
THEMES = {
    "paper":  dict(bg=(0xE7, 0xEB, 0xE4), ink=INK, ink2=INK2, kicker=COBALT, bezel=INK),
    "ink":    dict(bg=(0x14, 0x1C, 0x19), ink=(0xF1, 0xF5, 0xF1), ink2=(0xA9, 0xB7, 0xB0), kicker=(0x9D, 0xAE, 0xFF), bezel=(0x33, 0x40, 0x3A)),
    "cobalt": dict(bg=COBALT, ink=(0xFF, 0xFF, 0xFF), ink2=(0xD5, 0xDC, 0xFB), kicker=(0xFF, 0xFF, 0xFF), bezel=(0x14, 0x1C, 0x19)),
}

def theme(spec): return THEMES[spec.get("theme", "paper")]

def header(canvas, spec, s):
    """꼬리표(작게) → 큰 명조 머리말 두 줄 → 설명. 번호·줄 같은 장식은 없다."""
    d = ImageDraw.Draw(canvas)
    W = canvas.width
    t = theme(spec)
    mx = int(96 * s)
    y = int(150 * s)
    tracked(d, (mx, y), spec["label"], font(SANS, 40 * s, 6), t["kicker"], 2.5 * s)
    y += int(84 * s)
    size = spec.get("hsize", 124)
    fh = font(SERIF, size * s)
    for line in spec["headline"].split("\n"):
        if d.textlength(line, font=fh) > W - 2 * mx: print("  ! 머리말 넘침:", line)
        d.text((mx, y), line, font=fh, fill=t["ink"])
        y += int(size * 1.24 * s)
    fs = font(SANS, 44 * s, 2)
    y += int(22 * s)
    for line in spec["support"].split("\n"):
        if d.textlength(line, font=fs) > W - 2 * mx: print("  ! 설명 넘침:", line, int(d.textlength(line, font=fs)), ">", W - 2 * mx)
        d.text((mx, y), line, font=fs, fill=t["ink2"])
        y += int(44 * 1.5 * s)
    return y

def device(canvas, img, x, y, w, color, s):
    """평평한 기기: 먹색 테 + 둥근 화면. 아래로 넘치면 잘린다 (화면을 크게 보이려고)."""
    bez = int(20 * s)
    h = int(round(w * img.height / img.width))
    r = int(w * 0.128)
    ss = 3
    W2, H2 = w + 2 * bez, h + 2 * bez
    m = Image.new("L", (W2 * ss, H2 * ss), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, W2 * ss - 1, H2 * ss - 1], radius=(r + bez) * ss, fill=255)
    m = m.resize((W2, H2), Image.LANCZOS)
    canvas.paste(Image.new("RGB", (W2, H2), color), (x - bez, y - bez), m)
    im = img.convert("RGB").resize((w, h), Image.LANCZOS)
    canvas.paste(im, (x, y), rounded_mask((w, h), r))
    return h

def compose(spec, W, H, out):
    s = W / BASE_W
    t = theme(spec)
    canvas = Image.new("RGB", (W, H), t["bg"])
    y = header(canvas, spec, s)
    if spec.get("shot"):
        img = Image.open(spec["shot"])
        top = y + int(76 * s)
        if spec.get("fit") == "full":
            # 화면 전체가 보이게 (아래쪽이 중요한 화면)
            h = H - top - int(70 * s)
            w = int(round(h * img.width / img.height))
        else:
            # 크게, 아래로 넘치게
            w = int(spec.get("width", 1060) * s)
        device(canvas, img, (W - w) // 2, top, w, t["bezel"], s)
    canvas.save(out, optimize=True)
    return out

# ---- 6번: 위젯 · 실시간 현황 · Siri (위젯은 확장의 뷰 코드를 14:20 으로 그린 것) ----
def paste_card(canvas, img, xy, scale, radius, border=2.4, s=1.0):
    w, h = int(img.width * scale), int(img.height * scale)
    im = img.convert("RGBA").resize((w, h), Image.LANCZOS)
    mask = rounded_mask((w, h), int(radius * scale))
    if im.mode == "RGBA":
        alpha = im.split()[3]
        from PIL import ImageChops
        mask = ImageChops.multiply(mask, alpha)
    canvas.paste(im.convert("RGB"), xy, mask)
    if border: outline(canvas, (xy[0], xy[1], w, h), int(radius * scale), border * s, INK)
    return w, h

def caption(canvas, xy, text, s):
    d = ImageDraw.Draw(canvas)
    d.text(xy, text, font=font(SANS, 30 * s, 2), fill=INK2)

def siri_card(canvas, box, phrase, s):
    x, y, w, h = box
    d = ImageDraw.Draw(canvas)
    ss = 4
    layer = Image.new("L", (w * ss, h * ss), 0)
    ImageDraw.Draw(layer).rounded_rectangle([0, 0, w * ss - 1, h * ss - 1], radius=int(40 * s) * ss, fill=255)
    layer = layer.resize((w, h), Image.LANCZOS)
    canvas.paste(Image.new("RGB", (w, h), SHEET), (x, y), layer)
    outline(canvas, box, int(40 * s), 2.4 * s, INK)
    d.text((x + int(40 * s), y + int(34 * s)), "Siri에게", font=font(SANS, 30 * s, 4), fill=COBALT)
    fh = font(SERIF, 46 * s)
    ty = y + int(92 * s)
    for line in phrase.split("\n"):
        d.text((x + int(40 * s), ty), line, font=fh, fill=INK)
        ty += int(62 * s)

def compose_widgets(spec, W, H, out):
    s = W / BASE_W
    canvas = Image.new("RGB", (W, H), theme(spec)["bg"])
    hy = header(canvas, spec, s)
    wd = spec["widgets_dir"]
    k = 1.0 * s  # 위젯은 실제 크기 (1320 폭 기기의 3배 픽셀)
    x0 = int((W - 1092 * k) / 2)
    y = max(int(700 * s), hy + int(70 * s))
    gap, cap = int(22 * s), int(60 * s)
    w, h = paste_card(canvas, Image.open(f"{wd}/w-medium.png"), (x0, y), k, 66, s=s)
    caption(canvas, (x0 + int(6 * s), y + h + int(16 * s)), "홈 화면 위젯 · 네모를 누르면 바로 끝", s)
    y += h + cap + gap
    sw, sh = paste_card(canvas, Image.open(f"{wd}/w-small.png"), (x0, y), k, 66, s=s)
    cx = x0 + sw + int(36 * s)
    cw = int(1092 * k) - sw - int(36 * s)
    ch = (sh - int(28 * s)) // 2
    siri_card(canvas, (cx, y, cw, ch), "“우다다한테\n시키기”", s)
    siri_card(canvas, (cx, y + ch + int(28 * s), cw, ch), "“우다다로\n정리해 줘”", s)
    caption(canvas, (x0 + int(6 * s), y + sh + int(16 * s)), "작은 위젯 · Siri와 단축어", s)
    y += sh + cap + gap
    lw, lh = paste_card(canvas, Image.open(f"{wd}/la-0.png"), (x0, y), k, 72, s=s)
    caption(canvas, (x0 + int(6 * s), y + lh + int(16 * s)), "잠금 화면 실시간 현황 · 집중", s)
    y += lh + cap + gap
    lw, lh = paste_card(canvas, Image.open(f"{wd}/la-1.png"), (x0, y), k, 72, border=0, s=s)
    caption(canvas, (x0 + int(6 * s), y + lh + int(16 * s)), "잠금 화면 실시간 현황 · 식히기", s)
    canvas.save(out, optimize=True)
    return out

SIZES = {"iphone-6.9": (1320, 2868), "iphone-6.5": (1284, 2778), "iphone-6.3": (1206, 2622)}

def preview(d, out, tw=360):
    """전부를 다섯 칸짜리 한 장으로"""
    import glob
    files = sorted(glob.glob(os.path.join(d, "[01]*.png")))
    ims = [Image.open(f).convert("RGB") for f in files]
    th, gap, cols = int(ims[0].height * tw / ims[0].width), 24, 5
    rows = (len(ims) + cols - 1) // cols
    c = Image.new("RGB", (cols * tw + (cols + 1) * gap, rows * th + (rows + 1) * gap), INK)
    for i, im in enumerate(ims):
        c.paste(im.resize((tw, th), Image.LANCZOS), (gap + (i % cols) * (tw + gap), gap + (i // cols) * (th + gap)))
    c.save(out, optimize=True)

if __name__ == "__main__":
    # usage: compose.py <shots.json> <촬영 폴더> <위젯 폴더> <screenshots 폴더>
    spec_path, shots, widgets, root = sys.argv[1:5]
    specs = json.load(open(spec_path))
    for sp in specs:
        if sp.get("shot"): sp["shot"] = os.path.join(shots, sp["shot"])
        if sp.get("custom") == "widgets": sp["widgets_dir"] = widgets
    for folder, (W, H) in SIZES.items():
        out = os.path.join(root, "ko", folder)
        os.makedirs(out, exist_ok=True)
        for sp in specs:
            f = os.path.join(out, sp["file"])
            (compose_widgets if sp.get("custom") == "widgets" else compose)(sp, W, H, f)
        print(folder, W, H, len(specs), "장")
    preview(os.path.join(root, "ko", "iphone-6.9"), os.path.join(root, "preview.png"))
    print("preview.png")

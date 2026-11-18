#!/usr/bin/env python3
"""우다다 앱 아이콘 「지금 우」 생성기.

    python3 udada/design/brand/icon.py

쓰는 파일
  ios/Udada/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png         기본(밝은) · RGB, 알파 없음
  ios/Udada/Assets.xcassets/AppIcon.appiconset/AppIcon-1024-dark.png    다크 · 투명 바탕(시스템 배경이 비친다)
  ios/Udada/Assets.xcassets/AppIcon.appiconset/AppIcon-1024-tinted.png  틴트 · 회색조, 투명 바탕
  design/brand/icon.svg · construction.png · appearances.png · home-light.png · home-dark.png · preview.png

필요: Python 3, Pillow, numpy, fontTools. 미리보기 라벨은 macOS 의 Apple SD Gothic Neo.
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from fontTools.ttLib import TTFont
from fontTools.pens.basePen import BasePen
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

HERE = os.path.dirname(os.path.abspath(__file__))
UDADA = os.path.normpath(os.path.join(HERE, "..", ".."))
FONT = os.path.join(UDADA, "ios/Udada/Resources/Fonts/GowunBatang-Bold.ttf")
ICONSET = os.path.join(UDADA, "ios/Udada/Assets.xcassets/AppIcon.appiconset")
LABEL = "/System/Library/Fonts/AppleSDGothicNeo.ttc"

# ── 색 (ios/Shared/Theme.swift) ────────────────────────────────────────────
PAPER, INK, COBALT = 0xF1F3EE, 0x19221F, 0x2E4AE3      # Ink.ground · Ink.text · Ink.accent (밝은)
D_INK, D_COBALT = 0xE6EDE9, 0x8399FF                   # Ink.text · Ink.accent (어두운)
T_GLYPH, T_BAR = 0xC8C8C8, 0xFFFFFF                    # 틴트: 글자 78 %, 지금 줄 100 % (가장 밝게 = 강조 유지)
VARIANTS = {
    "light": dict(bg=PAPER, glyph=INK, bar=COBALT),
    "dark": dict(bg=None, glyph=D_INK, bar=D_COBALT),
    "tinted": dict(bg=None, glyph=T_GLYPH, bar=T_BAR),
}

# ── 구성 (1024 px 캔버스 · 글꼴 단위 1/1000 em, y 위로) ──────────────────────
SIZE, SS = 1024, 8          # 캔버스, 초표본 배율(픽셀당 64 표본)
EM = 740                    # 우 글자 크기 px
AXIS, CY = 512, 520         # 공통 세로축 · 구성 bbox 중심 y (ㅇ 의 무게만큼 8 px 내림)
GLYPH_TOP, GLYPH_BOTTOM = 850, -40
IEUNG_CX = 481.5            # ㅇ 중심 x
STEM_X0, STEM_X1 = 445, 540 # ㅣ 기둥
K = EM / 1000
BASE = CY + (GLYPH_TOP + GLYPH_BOTTOM) / 2 * K
# 지금 줄(붓 ㅡ 대신 그은 막대). 네 변을 60 px 격자(1024/60 = 17.07 px)에 맞춰 60·120·180 px 에서 번지지 않게:
# 두께 3칸 = 51.2 px(69 u — 기둥 95 u 보다 가늘게, 명조의 가로획처럼) · 길이 38칸 = 648.5 px(원래 ㅡ 890 u 와 거의 같음)
GRID = SIZE / 60
BAR = (AXIS - 19 * GRID, 32 * GRID, AXIS + 19 * GRID, 35 * GRID)


def fy(v):
    return BASE - v * K


X_IEUNG = AXIS - IEUNG_CX * K                          # ㅇ 을 축에 맞춘 글자 원점
X_STEM = AXIS - (STEM_X0 + STEM_X1) / 2 * K            # 기둥을 축에 맞춘 원점 (글꼴은 붓 ㅡ 때문에 11 u 오른쪽)
# ㅜ 윤곽에서 기둥만: 막대 두께 가운데보다 아래 · 기둥 폭 ±30 u (그 위의 ㅡ 조각은 막대 밑에 숨는다)
STEM_CLIP = (X_STEM + (STEM_X0 - 30) * K, (BAR[1] + BAR[3]) / 2, X_STEM + (STEM_X1 + 30) * K, SIZE)


def rgb(h):
    return np.array([(h >> 16) & 255, (h >> 8) & 255, h & 255], np.float64)


# ── 글자 윤곽 ────────────────────────────────────────────────────────────────
class _Flat(BasePen):
    def __init__(self, gs, steps=32):
        super().__init__(gs)
        self.out, self.cur, self.n = [], [], steps

    def _moveTo(self, p):
        self.cur = [p]

    def _lineTo(self, p):
        self.cur.append(p)

    def _qCurveToOne(self, p1, p2):
        p0 = self.cur[-1]
        for i in range(1, self.n + 1):
            t = i / self.n
            self.cur.append(tuple((1 - t) ** 2 * a + 2 * (1 - t) * t * b + t * t * c for a, b, c in zip(p0, p1, p2)))

    def _curveToOne(self, p1, p2, p3):
        p0 = self.cur[-1]
        for i in range(1, self.n + 1):
            t = i / self.n
            self.cur.append(tuple((1 - t) ** 3 * a + 3 * (1 - t) ** 2 * t * b + 3 * (1 - t) * t * t * c + t ** 3 * d
                                  for a, b, c, d in zip(p0, p1, p2, p3)))

    def _closePath(self):
        self.out.append(self.cur)
        self.cur = []

    _endPath = _closePath


FONT_TT = TTFont(FONT)
GLYPH = FONT_TT.getBestCmap()[ord("우")]   # 윤곽 0 = ㅇ 바깥, 1 = ㅜ(ㅡ+ㅣ), 2 = ㅇ 안


def contours():
    gs = FONT_TT.getGlyphSet()
    pen = _Flat(gs)
    gs[GLYPH].draw(pen)
    return pen.out


def _area(c):
    return sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(c, c[1:] + c[:1])) / 2


# ── 덮임(coverage) 마스크: SS 배로 그려 상자 필터로 줄인다 ─────────────────────
def _down(mask_bool):
    n = SIZE
    return mask_bool.reshape(n, SS, n, SS).sum(axis=(1, 3), dtype=np.uint16) / (SS * SS)


def glyph_cov(which, x_left, clip=None):
    W = SIZE * SS
    acc = np.zeros((W, W), np.int16)
    for i, c in enumerate(contours()):
        if i not in which:
            continue
        m = Image.new("L", (W, W), 0)
        ImageDraw.Draw(m).polygon([((x_left + x * K) * SS, (BASE - y * K) * SS) for x, y in c], fill=1)
        acc += np.asarray(m, np.int16) * (1 if _area(c) > 0 else -1)   # 0이 아닌 감김 규칙
    inside = acc != 0
    if clip:
        x0, y0, x1, y1 = (round(v * SS) for v in clip)
        keep = np.zeros_like(inside)
        keep[max(y0, 0):y1, max(x0, 0):x1] = True
        inside &= keep
    return _down(inside)


def rect_cov(x0, y0, x1, y1):
    """축 정렬 사각형의 정확한 픽셀 덮임."""
    p = np.arange(SIZE)
    cx = np.clip(np.minimum(p + 1, x1) - np.maximum(p, x0), 0, 1)
    cy = np.clip(np.minimum(p + 1, y1) - np.maximum(p, y0), 0, 1)
    return cy[:, None] * cx[None, :]


def layers():
    return dict(
        ieung=glyph_cov({0, 2}, X_IEUNG),
        stem=glyph_cov({1}, X_STEM, STEM_CLIP),   # ㅡ 은 버리고 ㅣ 만. 위쪽 절반은 막대 밑으로 숨는다
        bar=rect_cov(*BAR),
    )


def compose(v, L):
    bg = VARIANTS[v]["bg"]
    P = np.zeros((SIZE, SIZE, 3))     # 미리 곱한 색
    A = np.zeros((SIZE, SIZE))
    if bg is not None:
        P[:] = rgb(bg)
        A[:] = 1
    for name, key in (("ieung", "glyph"), ("stem", "glyph"), ("bar", "bar")):
        a = L[name]
        P = rgb(VARIANTS[v][key]) * a[..., None] + P * (1 - a[..., None])
        A = a + A * (1 - a)
    if bg is not None:
        return Image.fromarray(np.round(P).astype(np.uint8), "RGB")
    col = np.where(A[..., None] > 0, P / np.maximum(A[..., None], 1e-9), 0)
    out = np.dstack([np.round(col), np.round(A * 255)]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


# ── 벡터 원본 ────────────────────────────────────────────────────────────────
def svg(path):
    gs = FONT_TT.getGlyphSet()

    def d(x_left, keep):
        pen = SVGPathPen(gs, ntos=lambda n: ("%.2f" % n).rstrip("0").rstrip("."))
        tp = TransformPen(pen, (K, 0, 0, -K, x_left, BASE))
        rec = RecordingPen()
        gs[GLYPH].draw(rec)
        idx = -1
        for op, args in rec.value:
            if op == "moveTo":
                idx += 1
            if idx in keep:
                getattr(tp, op)(*args)
        return pen.getCommands()

    hx = lambda h: "#%06X" % h
    x0, y0, x1, y1 = STEM_CLIP
    bx0, by0, bx1, by1 = BAR
    s = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {SIZE} {SIZE}" width="{SIZE}" height="{SIZE}">
  <!-- 우다다 앱 아이콘 「지금 우」 · 고운바탕 Bold 우(SIL OFL 1.1) + 코발트 지금 줄. 모서리는 시스템이 깎는다. -->
  <defs><clipPath id="stem"><rect x="{x0:.2f}" y="{y0:.2f}" width="{x1 - x0:.2f}" height="{y1 - y0:.2f}"/></clipPath></defs>
  <rect width="{SIZE}" height="{SIZE}" fill="{hx(PAPER)}"/>
  <path fill="{hx(INK)}" d="{d(X_IEUNG, {0, 2})}"/>
  <path fill="{hx(INK)}" clip-path="url(#stem)" d="{d(X_STEM, {1})}"/>
  <rect fill="{hx(COBALT)}" x="{bx0:.2f}" y="{by0:.2f}" width="{bx1 - bx0:.2f}" height="{by1 - by0:.2f}"/>
</svg>
"""
    with open(path, "w") as f:
        f.write(s)


# ── 미리보기 ─────────────────────────────────────────────────────────────────
SYS_DARK = 0x1C1C1E          # 다크 아이콘 뒤 시스템 배경(근사 · 평면)
TINT_DEMO, TINT_BG = 0xE9A23B, 0x141414
WALL_LIGHT, WALL_DARK = 0xDCE2E4, 0x101315
_sq = {}


def squircle(px, n=5.0):
    if px not in _sq:
        N = px * 4
        t = (np.arange(N) + 0.5) / N * 2 - 1
        X, Y = np.meshgrid(t, t)
        m = Image.fromarray(((np.abs(X) ** n + np.abs(Y) ** n <= 1) * 255).astype(np.uint8), "L")
        _sq[px] = m.resize((px, px), Image.BOX)
    return _sq[px]


def on_tile(img, v):
    """홈 화면에 실제로 보이는 모습: 다크는 시스템 배경 위, 틴트는 색을 입혀서."""
    if v == "light":
        return img.convert("RGB")
    a = np.asarray(img, np.float64) / 255
    if v == "dark":
        out = rgb(SYS_DARK) * (1 - a[..., 3:]) + a[..., :3] * 255 * a[..., 3:]
    else:
        lum = (a[..., 0] * a[..., 3])[..., None]
        out = rgb(TINT_BG) * (1 - lum) + rgb(TINT_DEMO) * lum
    return Image.fromarray(np.round(out).astype(np.uint8), "RGB")


def icon_px(tile, px):
    im = tile.resize((px, px), Image.LANCZOS).convert("RGBA")
    im.putalpha(squircle(px))
    return im


def font(size, face=6):
    try:
        return ImageFont.truetype(LABEL, size, index=face)
    except OSError:
        return ImageFont.load_default()


NEIGHBORS_LIGHT = [0x3A9D5D, 0xFFFFFF, 0x24262A, 0xE0823D, 0x3C78D8, 0xD9534F, 0xEDE3CF, 0x6A5ACD]
NEIGHBORS_DARK = [0x62C98A, 0xE8E8E8, 0xF0A35E, 0x6FA0F0, 0xEF7C77, 0xD8C9A8, 0x9B8CF0, 0x7FC4D0]


def neighbor(px, i, dark):
    if not dark:
        tile = Image.new("RGB", (px, px), tuple(int(c) for c in rgb(NEIGHBORS_LIGHT[i % 8])))
    else:   # 다크 아이콘 흉내: 어두운 판 + 색 점
        tile = Image.new("RGB", (px * 4, px * 4), tuple(int(c) for c in rgb(SYS_DARK)))
        r = px * 4 * (0.16 + 0.05 * (i % 3))
        ImageDraw.Draw(tile).ellipse([px * 2 - r, px * 2 - r, px * 2 + r, px * 2 + r],
                                     fill=tuple(int(c) for c in rgb(NEIGHBORS_DARK[i % 8])))
        tile = tile.resize((px, px), Image.LANCZOS)
    t = tile.convert("RGBA")
    t.putalpha(squircle(px))
    return t


def home(tile, dark, path):
    sheet_bg = (0x0B, 0x0D, 0x0E) if dark else (0xF6, 0xF7, 0xF4)
    head = (0x9A, 0xA4, 0xA0) if dark else (0x5A, 0x66, 0x61)
    wall = tuple(int(c) for c in rgb(WALL_DARK if dark else WALL_LIGHT))
    lab = (0xEC, 0xEF, 0xED) if dark else (0x1D, 0x24, 0x21)
    ph = (0x3A, 0x40, 0x42) if dark else (0xB7, 0xC0, 0xC2)
    panels = []
    for px in (180, 120, 60):
        gap, fs = round(px * 0.42), max(11, round(px * 0.2))
        lh = round(fs * 1.7)
        pad = round(px * 0.34)
        w = 4 * px + 3 * gap + 2 * pad
        h = 2 * (px + lh) + gap // 2 + 2 * pad
        p = Image.new("RGB", (w, h), wall)
        d = ImageDraw.Draw(p)
        n = 0
        for r in range(2):
            for c in range(4):
                x, y = pad + c * (px + gap), pad + r * (px + lh + gap // 2)
                if (r, c) == (0, 1):
                    im = icon_px(tile, px)
                    p.paste(im, (x, y), im)
                    f = font(fs, 6)
                    tw = d.textlength("우다다", font=f)
                    d.text((x + (px - tw) / 2, y + px + fs * 0.35), "우다다", font=f, fill=lab)
                else:
                    im = neighbor(px, n + (3 if dark else 0), dark)
                    n += 1
                    p.paste(im, (x, y), im)
                    bw = px * (0.42 + 0.16 * ((n * 5) % 3))
                    by = y + px + fs * 0.55
                    d.rounded_rectangle([x + (px - bw) / 2, by, x + (px + bw) / 2, by + fs * 0.7], radius=fs * 0.35, fill=ph)
        panels.append((px, p))
    W = sum(p.width for _, p in panels) + 40 * (len(panels) + 1)
    H = max(p.height for _, p in panels) + 100
    out = Image.new("RGB", (W, H), sheet_bg)
    d = ImageDraw.Draw(out)
    x = 40
    for px, p in panels:
        d.text((x, 30), f"{px} px", font=font(26, 8), fill=head)
        out.paste(p, (x, 76))
        x += p.width + 40
    out.save(path, optimize=True)
    return out


def appearances(icons, path):
    names = {"light": "기본", "dark": "다크 · 투명 바탕 → 시스템 배경", "tinted": "틴트 · 회색조 (예: 호박색)"}
    big, pad = 300, 44
    W = 3 * (big + 2 * pad) + 4 * 16
    H = big + 2 * pad + 200
    out = Image.new("RGB", (W, H), (0xF6, 0xF7, 0xF4))
    d = ImageDraw.Draw(out)
    for i, v in enumerate(("light", "dark", "tinted")):
        x = 16 + i * (big + 2 * pad + 16)
        wall = tuple(int(c) for c in rgb(WALL_LIGHT if v == "light" else WALL_DARK))
        panel = Image.new("RGB", (big + 2 * pad, H - 70), wall)
        tile = on_tile(icons[v], v)
        im = icon_px(tile, big)
        panel.paste(im, (pad, pad), im)
        xx = pad
        for px in (120, 60):
            im = icon_px(tile, px)
            panel.paste(im, (xx, pad + big + 40 + (120 - px) // 2), im)
            xx += px + 36
        out.paste(panel, (x, 16))
        d.text((x, H - 44), names[v], font=font(20, 6), fill=(0x3A, 0x44, 0x40))
    out.save(path, optimize=True)
    return out


def construction(img, path):
    S = 3   # 선을 곱게 긋기 위해 크게 그렸다 줄인다
    W, H = 1560, 1124
    out = Image.new("RGB", (W * S, H * S), (0xF6, 0xF7, 0xF4))
    ox, oy = 50, 50
    out.paste(img.resize((SIZE * S, SIZE * S), Image.LANCZOS), (ox * S, oy * S))
    d = ImageDraw.Draw(out)
    red, grey = (0xD2, 0x45, 0x2C), (0x8B, 0x96, 0x91)
    f = font(19 * S, 6)
    P = lambda x, y: ((ox + x) * S, (oy + y) * S)
    # 시스템 모서리(근사: 초타원 n=5)
    t = np.linspace(0, 2 * np.pi, 1441)
    c, s_ = np.cos(t), np.sin(t)
    pts = [P(512 + 512 * np.sign(a) * abs(a) ** 0.4, 512 + 512 * np.sign(b) * abs(b) ** 0.4) for a, b in zip(c, s_)]
    d.line(pts, fill=grey, width=2 * S)
    ys_, xs_ = np.nonzero(np.asarray(img.convert("L")) < 200)
    ieung_top = ys_.min()
    stem_bottom = ys_.max()
    L = layers()
    ie = np.nonzero(L["ieung"].sum(axis=1) > 0.5)[0]
    ieung_bottom = ie.max()
    rmax = float(np.sqrt((xs_ + 0.5 - 512) ** 2 + (ys_ + 0.5 - 512) ** 2).max())
    # 내용 반경
    r = rmax
    d.ellipse([P(512 - r, 512 - r), P(512 + r, 512 + r)], outline=grey, width=S)
    # 축
    for y in range(0, SIZE, 24):
        d.line([P(AXIS, y), P(AXIS, y + 12)], fill=red, width=S)
    rows = [
        (ieung_top, f"ㅇ 위 {ieung_top} px"),
        (ieung_bottom + 1, f"ㅇ 아래 {ieung_bottom + 1} px · 틈 {BAR[1] - ieung_bottom - 1:.0f} px"),
        (BAR[1], f"지금 줄 위 {BAR[1]:.1f} px"),
        (BAR[3], f"지금 줄 아래 {BAR[3]:.1f} px · 두께 {BAR[3] - BAR[1]:.1f}"),
        (stem_bottom + 1, f"기둥 끝 {stem_bottom + 1} px · 기둥 폭 {(STEM_X1 - STEM_X0) * K:.1f} px"),
    ]
    for y, text in rows:
        d.line([P(0, y), P(SIZE + 30, y)], fill=red, width=S)
        if text:
            d.text(P(SIZE + 40, y - 13), text, font=f, fill=red)
    for x in (BAR[0], BAR[2]):
        d.line([P(x, BAR[1] - 70), P(x, BAR[3] + 70)], fill=red, width=S)
    d.text(P(BAR[0], BAR[3] + 78), f"{BAR[0]:.1f}", font=f, fill=red)
    d.text(P(BAR[2] - 62, BAR[3] + 78), f"{BAR[2]:.1f}", font=f, fill=red)
    notes = [
        "고운바탕 Bold 「우」 · em 740 px",
        "ㅇ · 기둥 · 지금 줄 모두 x = 512 축",
        f"구성 bbox 중심 y = {CY} (기하 중심 +8)",
        "지금 줄 네 변 = 60 px 격자(17.07 px)",
        f"내용 반경 ≤ {rmax:.0f} px (회색 원)",
        "회색 테 = 시스템 모서리(근사)",
    ]
    for i, line in enumerate(notes):
        d.text(P(SIZE + 40, 640 + i * 32), line, font=f, fill=(0x3A, 0x44, 0x40))
    out.resize((W, H), Image.LANCZOS).save(path, optimize=True)
    return dict(ieung_top=int(ieung_top), ieung_bottom=int(ieung_bottom + 1), stem_bottom=int(stem_bottom + 1), rmax=rmax)


def main():
    L = layers()
    icons = {v: compose(v, L) for v in VARIANTS}
    names = {"light": "AppIcon-1024.png", "dark": "AppIcon-1024-dark.png", "tinted": "AppIcon-1024-tinted.png"}
    for v, im in icons.items():
        im.save(os.path.join(ICONSET, names[v]), optimize=True)
    svg(os.path.join(HERE, "icon.svg"))
    info = construction(icons["light"], os.path.join(HERE, "construction.png"))
    a = appearances(icons, os.path.join(HERE, "appearances.png"))
    hl = home(on_tile(icons["light"], "light"), False, os.path.join(HERE, "home-light.png"))
    hd = home(on_tile(icons["dark"], "dark"), True, os.path.join(HERE, "home-dark.png"))
    W = max(a.width, hl.width, hd.width)
    parts = [a, hl, hd]
    out = Image.new("RGB", (W, sum(p.height for p in parts) + 20 * (len(parts) - 1)), (0xF6, 0xF7, 0xF4))
    y = 0
    for p in parts:
        out.paste(p, ((W - p.width) // 2, y))
        y += p.height + 20
    out.save(os.path.join(HERE, "preview.png"), optimize=True)
    print("bar", tuple(round(v, 1) for v in BAR), "stem clip", tuple(round(v, 1) for v in STEM_CLIP), info)


if __name__ == "__main__":
    main()

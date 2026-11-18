"""우다다 Mac App Store 스크린샷 합성 (2880×1800). iPhone 것과 같은 말씨: 평평한 바탕 한 색 · 큰 명조 머리말 · 실제 화면.
usage: compose_mac.py <촬영 폴더> <screenshots/mac 폴더>
촬영 폴더에는 창을 그대로 찍은 day.png 와, 시트만 흰 바탕 위에 찍힌 dump.png · find.png · siri.png 가 있다."""
import sys, os
from PIL import Image, ImageChops, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compose import THEMES, SERIF, SANS, font, tracked, rounded_mask, outline

W, H = 2880, 1800
SPECS = [
    dict(file="1-day.png", shot="day.png", kind="window", theme="paper", label="하루 한 장",
         headline="하루를 세 칸에,\n지금 할 일 하나", support="아침 · 낮 · 저녁과 지금 줄.\niPhone과 내 iCloud로 이어져요."),
    dict(file="2-dump.png", shot="dump.png", kind="sheet", theme="cobalt", label="Apple Intelligence",
         headline="쏟아내면\n한 줄씩 나눠요", support="떠오르는 대로 적으면 지금 · 날짜 ·\n걱정 · 버리기로 나눠 줘요.\n지원하는 Mac 안에서만 처리해요."),
    dict(file="3-find.png", shot="find.png", kind="sheet", theme="paper", label="말로 하기",
         headline="낱말이 달라도\n뜻으로 찾아요", support="“병원 가는 거 뭐 있어”라고 물으면\n적어 둔 ‘치과’를 찾아 줘요.\n시키는 말은 바꾸기 전에 먼저 보여 줘요."),
    dict(file="4-siri.png", shot="siri.png", kind="sheet", theme="ink", label="Siri · 앱 안 사용법 장면",
         headline="Siri에게\n한 문장으로", support="“우다다한테 시키기” · “우다다로 정리해 줘”.\n앱을 열지 않고 여러 일을 바꿔요."),
]

def crop_sheet(im):
    """시트 둘레의 빈 바탕(귀퉁이 색과 거의 같은 곳)을 잘라 낸다"""
    im = im.convert("RGB")
    im = im.crop((80, 80, im.width - 80, im.height - 80))  # 창 테두리·귀퉁이는 뺀다
    diff = ImageChops.difference(im, Image.new("RGB", im.size, im.getpixel((im.width // 2, 30)))).convert("L").point(lambda v: 255 if v > 10 else 0)
    box = diff.getbbox()
    if not box: return im
    x0, y0, x1, y1 = box
    return im.crop((x0 + 2, y0 + 2, x1 - 2, y1 - 2))

def compose(spec, src, out):
    t = THEMES[spec["theme"]]
    c = Image.new("RGB", (W, H), t["bg"])
    d = ImageDraw.Draw(c)
    mx, y = 170, 300
    tracked(d, (mx, y), spec["label"], font(SANS, 46, 6), t["kicker"], 3)
    y += 110
    fh = font(SERIF, 156)
    for line in spec["headline"].split("\n"):
        d.text((mx, y), line, font=fh, fill=t["ink"]); y += int(156 * 1.22)
    y += 34
    fs = font(SANS, 54, 2)
    for line in spec["support"].split("\n"):
        d.text((mx, y), line, font=fs, fill=t["ink2"]); y += int(54 * 1.5)
    img = Image.open(os.path.join(src, spec["shot"]))
    if spec["kind"] == "window":
        # 창은 크게, 오른쪽 아래로 넘치게
        w = 2400; h = int(w * img.height / img.width); x, yy, r = 1300, 210, 36
        im = img.convert("RGB").resize((w, h), Image.LANCZOS)
    else:
        im = crop_sheet(img)
        h = 1520 if im.height > im.width else 1100
        w = int(h * im.width / im.height)
        if w > 1500: w = 1500; h = int(w * im.height / im.width)
        im = im.resize((w, h), Image.LANCZOS)
        x, yy, r = 1330 + (W - 1330 - 140 - w) // 2, (H - h) // 2, 30
    c.paste(im, (x, yy), rounded_mask((w, h), r))
    outline(c, (x, yy, w, h), r, 5, t["bezel"])
    c.save(out, optimize=True)

if __name__ == "__main__":
    src, dst = sys.argv[1:3]
    for sp in SPECS:
        compose(sp, src, os.path.join(dst, sp["file"])); print(sp["file"])

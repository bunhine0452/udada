"""우다다 소개 영상의 효과음. 전부 여기서 만든 소리다 (사인파와 잡음) — 가져다 쓴 음원이 없다.
usage: sfx.py <cues.json> <out.wav>
영상 렌더러가 적어 준 컷 시작 시각(cues)에, 장면마다 일이 벌어지는 시각(아래 표 — GuideScenes 의 박자와 같다)을 더해 소리를 놓는다."""
import json, math, random, struct, sys, wave

SR = 44100
random.seed(7)
cues = json.load(open(sys.argv[1]))
N = int((cues["total"] + 0.5) * SR)
buf = [0.0] * N

def put(t, samples, gain=1.0):
    i0 = int(t * SR)
    for i, v in enumerate(samples):
        j = i0 + i
        if 0 <= j < N: buf[j] += v * gain

def env(n, attack, decay):
    a = max(1, int(attack * SR))
    return [min(1.0, i / a) * math.exp(-(i / SR) / decay) for i in range(n)]

def tone(freq, dur, decay, attack=0.002, sweep=None):
    n = int(dur * SR); e = env(n, attack, decay); out = []; ph = 0.0
    for i in range(n):
        f = freq if sweep is None else freq + (sweep - freq) * (i / n)
        ph += 2 * math.pi * f / SR
        out.append(math.sin(ph) * e[i])
    return out

def noise(dur, decay, lp=0.25, attack=0.001):
    n = int(dur * SR); e = env(n, attack, decay); out = []; y = 0.0
    for i in range(n):
        y += lp * (random.uniform(-1, 1) - y)
        out.append(y * e[i])
    return out

def mixed(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] for p in parts if i < len(p)) for i in range(n)]

def key():    # 자판 한 번
    return mixed([v * 0.5 for v in tone(1900 + random.uniform(-180, 180), 0.03, 0.006)], noise(0.02, 0.004, lp=0.6))
def tap():    # 손가락이 화면을 누른다
    return mixed(tone(170, 0.09, 0.022), [v * 0.4 for v in noise(0.012, 0.003, lp=0.5)])
def pop():    # 꼬리표·줄이 톡 나타난다
    return tone(560, 0.11, 0.03, sweep=900)
def land():   # 카드가 제자리에 앉는다
    return mixed(tone(118, 0.16, 0.045), [v * 0.3 for v in noise(0.02, 0.006, lp=0.3)])
def rise():   # 판이 올라온다
    return noise(0.32, 0.12, lp=0.08, attack=0.12)
def stamp():  # 도장
    return mixed(tone(58, 0.5, 0.11), [v * 0.55 for v in noise(0.05, 0.012, lp=0.35)], [v * 0.4 for v in tone(116, 0.2, 0.05)])
def bloom():  # 이름이 설 때의 부드러운 화음
    return mixed(*[[v * g for v in tone(f, 2.4, 0.75, attack=0.09)] for f, g in ((220, 1.0), (329.6, 0.7), (554.4, 0.45))])

GAIN = {"key": 0.10, "tap": 0.26, "pop": 0.15, "land": 0.30, "rise": 0.22, "stamp": 0.85, "bloom": 0.085}
MAKE = {"key": key, "tap": tap, "pop": pop, "land": land, "rise": rise, "stamp": stamp, "bloom": bloom}

def typing(start, text, per):
    return [(start + per * i, "key") for i, ch in enumerate(text) if ch != " "]

# 장면 시각(초) → 소리. 장면 코드의 박자와 같은 수다.
SCENES = {
    6: [(4.4, "rise"), (4.8, "pop"), (5.1, "pop")],
    3: [(4.3, "pop"), (4.65, "pop"), (5.0, "pop"), (5.9, "key"), (6.2, "key"), (6.5, "key"), (8.3, "tap"), (9.0, "land"), (9.18, "land"), (9.36, "land")],
    0: [(1.0, "tap"), *typing(1.3, "3시 치과", 0.3), (2.9, "pop"), (4.75, "tap"), (5.45, "land")],
    4: [*typing(0.6, "치과 내일로 미루고 보고서는 끝냈어", 0.14), (3.35, "tap"), (3.6, "rise"), (4.0, "pop"), (4.3, "pop"), (5.3, "tap"), (6.5, "land"), (6.9, "pop")],
    7: [(6.5, "tap"), (7.4, "tap"), (8.1, "stamp"), (8.9, "pop")],
}

events = []
# 여는 장면 (1.35배로 돈다)
sp = cues["introSpeed"]
events += [(t / sp, k) for t, k in typing(0.45, "머릿속이 시끄러울 때.", 0.085)] + [(2.75 / sp, "bloom")]
for s in cues["shots"]:
    for t, k in SCENES.get(s["chapter"], []):
        if s["from"] <= t <= s["to"]: events.append((s["start"] + cues["lead"] + t - s["from"], k))
o = cues["outroStart"]
events += [(o + 0.4, "bloom"), (o + 1.1, "pop"), (o + 1.3, "pop"), (o + 1.5, "pop"), (o + 3.3, "bloom")]

for t, k in events: put(t, MAKE[k](), GAIN[k])

peak = max(1e-9, max(abs(v) for v in buf))
scale = min(1.0, 0.89 / peak)
with wave.open(sys.argv[2], "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(b"".join(struct.pack("<hh", s, s) for s in (int(max(-1, min(1, v * scale)) * 32767) for v in buf)))
print(f"sfx {len(events)} sounds, {N / SR:.1f}s, peak {peak:.2f}")

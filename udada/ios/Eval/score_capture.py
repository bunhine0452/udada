import json, sys
# 밖에서 받기: 받아야 할 일정·할 일(want)을 이름·날짜·시각까지 맞게 받았나, 없는 일(want·ok 어디에도 안 걸리는 줄)을 몇 개 만들었나.
exp = json.load(open(sys.argv[1])); got = json.load(open(sys.argv[2])); verbose = len(sys.argv) > 3 and sys.argv[3]
def score(key):
    need = found = named = extra = made = 0; notes = []
    for e, g in zip(exp, got):
        lines = g[key]; used = set(); need += len(e["want"]); made += len(lines)
        for w in e["want"]:
            hit = None; name = False
            for i, l in enumerate(lines):
                if i in used or not any(k in l["line"] for k in w["has"]): continue
                name = True
                if l["off"] in w["off"] and l["time"] in w["time"]: hit = i; break
            if hit is not None: used.add(hit); found += 1
            elif name: named += 1; notes.append(f'· 날짜·시각 틀림 {w["has"][0]}: {[(l["line"], l["off"], l["time"]) for l in lines]}')
            else: notes.append(f'· 못 받음 {w["has"][0]} ← {e["msg"][:30]}')
        for i, l in enumerate(lines):
            if i in used: continue
            if any(k in l["line"] for w in e["want"] for k in w["has"]) or any(k in l["line"] for k in e["ok"]): continue
            extra += 1; notes.append(f'· 없는 일 "{l["line"]}" ← {e["msg"][:30]}')
    return need, found, named, extra, made, notes
n, f, nm, x, made, notes = score("lines")
rn, rf, rnm, rx, rmade, _ = score("rule")
if verbose: print("\n".join(notes))
secs = sorted(g["seconds"] for g in got); ai = sum(1 for g in got if g["ai"])
print(f'상태 {got[0]["status"]} · 글 {len(exp)} · 모델이 읽은 글 {ai} · 가운데값 {secs[len(secs)//2]:.1f}초 · 가장 긴 것 {secs[-1]:.1f}초')
print("capture: 받은 것 %d/%d (%d%%) · 날짜·시각 틀림 %d · 없는 일 %d/%d (%d%%) · 규칙만 %d/%d (%d%%), 없는 일 %d/%d" % (
    f, n, 100*f//max(1,n), nm, x, made, 100*x//max(1,made), rf, rn, 100*rf//max(1,rn), rx, rmade))

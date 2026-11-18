import json, sys
exp = json.load(open(sys.argv[1])); got = {g["file"]: g for g in json.load(open(sys.argv[2]))}; verbose = len(sys.argv) > 3 and sys.argv[3]
def score(path):
    total = found = dated = extra = 0
    for e in exp:
        g = got.get(e["file"]); lines = g[path] if g else []
        used = set(); notes = []
        for x in e["expect"]:
            total += 1
            hit = next((i for i, l in enumerate(lines) if i not in used and any(k in l["line"] for k in x["keys"])), None)
            if hit is None: notes.append("못 찾음: " + x["keys"][0]); continue
            used.add(hit); found += 1
            l = lines[hit]
            ok = l["month"] == x["month"] and l["day"] == x["day"] and (("time" not in x and True) or l["time"] == x.get("time"))
            if ok: dated += 1
            else: notes.append(f'날짜·시각 틀림: {l["line"]} → {l["month"]}/{l["day"]} {l["time"]} (기대 {x["month"]}/{x["day"]} {x.get("time", "-")})')
        left = [l["line"] for i, l in enumerate(lines) if i not in used]
        extra += len(left)
        if verbose and path == verbose:
            print("·", e["file"], "| 남는 줄:", left); [print("    " + n) for n in notes]
    return total, found, dated, extra
see = sum(1 for g in got.values() if g["ai"]); secs = sorted(g["seconds"] for g in got.values())
print(f'그림 {len(exp)}장 · 모델이 본 것 {see}장 · 가운데값 {secs[len(secs)//2]:.1f}초 · 가장 긴 것 {secs[-1]:.1f}초')
for name, path in (("글자 인식만", "ocr"), ("모델이 그림을 봄", "model")):
    t, f, d, x = score(path)
    print(f'photos[{name}]: 일정 {t}개 중 이름 찾음 {f} · 날짜·시각까지 맞음 {d} ({100*d//t}%) · 군말로 남는 줄 {x}')

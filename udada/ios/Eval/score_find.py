import json, sys
exp = json.load(open(sys.argv[1])); got = json.load(open(sys.argv[2])); verbose = len(sys.argv) > 3 and sys.argv[3]
n = len(exp); ok = {"words": 0, "span": 0, "state": 0, "kind": 0}; whole = 0; ai = 0; secs = []
for e, g in zip(exp, got):
    secs.append(g["seconds"]); ai += 1 if g["ai"] else 0
    good = True; notes = []
    for k in ok:
        same = (sorted(e[k]) == sorted(g[k])) if k == "words" else e[k] == g[k]
        # 미팅·회의처럼 약속 낱말을 찾는 낱말로도 잡은 것은 맞게 친다
        if not same and k == "words" and set(e[k]) <= set(g[k]) and len(g[k]) <= len(e[k]) + 1: same = True
        if same: ok[k] += 1
        else: good = False; notes.append(f"{k}: {g[k]} (기대 {e[k]})")
    whole += good
    if verbose and notes: print("·", e["q"], "→", "; ".join(notes))
secs.sort()
print(f'상태 {got[0]["status"]} · 물음 {n} · 모델이 읽은 것 {ai} · 가운데값 {secs[len(secs)//2]:.1f}초')
print("find: 통째로 맞음 %d/%d (%d%%) · 낱말 %d · 때 %d · 상태 %d · 종류 %d" % (whole, n, 100*whole//n, ok["words"], ok["span"], ok["state"], ok["kind"]))

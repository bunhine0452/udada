import json, sys
# 뜻으로 찾기: 찾아야 할 기록(want)을 얼마나 찾았나, 엉뚱한 것(want·ok 어디에도 없는 것)을 몇 개 골랐나. 규칙만의 값도 같이.
exp = json.load(open(sys.argv[1])); got = json.load(open(sys.argv[2])); verbose = len(sys.argv) > 3 and sys.argv[3]
need = found = base = wrong = picked = basewrong = ai = 0; secs = []
for e, g in zip(exp, got):
    want, ok = set(e["want"]), set(e["ok"]); fin, lit = set(g["final"]), set(g["literal"])
    need += len(want); found += len(want & fin); base += len(want & lit)
    bad = fin - want - ok; wrong += len(bad); picked += len(fin); basewrong += len(lit - want - ok)
    ai += 1 if g["ai"] else 0; secs.append(g["seconds"])
    if verbose and (bad or want - fin):
        print("·", e["sense"], "| 못 찾음:", sorted(want - fin), "| 잘못:", sorted(bad), "| 낱말:", g["words"])
secs.sort()
print(f'상태 {got[0]["status"]} · 물음 {len(exp)} · 모델이 고른 물음 {ai} · 가운데값 {secs[len(secs)//2]:.1f}초 · 가장 긴 것 {secs[-1]:.1f}초')
print("sense: 찾아야 할 것 %d/%d (%d%%) · 잘못 고른 것 %d/%d (%d%%) · 규칙만 %d/%d (%d%%), 잘못 %d" % (
    found, need, 100*found//max(1,need), wrong, picked, 100*wrong//max(1,picked), base, need, 100*base//max(1,need), basewrong))

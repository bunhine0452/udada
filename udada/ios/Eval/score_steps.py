# 쪼개기 채점: 걸음 수 3~5 · 모델이 썼나(검사를 넘었나) · 걸음이 마감을 넘지 않나 · 걸린 시간.
# 글의 질은 숫자로 다 못 잰다 — EVAL_VERBOSE=1 로 걸음을 읽어 본다. 'ending' 은 "~기"로 끝난 걸음의 비율(말투 지표).
import json, sys
exp = json.load(open(sys.argv[1])); got = json.load(open(sys.argv[2])); verbose = len(sys.argv) > 3 and sys.argv[3]
n = len(got); count_ok = ai = late = known = 0; secs = []; steps_n = ending = 0
for e, g in zip(exp, got):
    s = g["steps"]; secs.append(g["seconds"]); steps_n += len(s)
    count_ok += 3 <= len(s) <= 5; ai += bool(g["ai"]); known += bool(g.get("known")); ending += sum(1 for x in s if x.endswith("기"))
    due = g["dueOffset"]
    # 마감이 내일 이후면 걸음은 전날까지, 오늘이면 오늘
    if due >= 0: late += sum(1 for o in g["offsets"] if o > max(0, due - 1))
    if verbose:
        tag = "AI " if g["ai"] else ("틀  " if g.get("known") else "떨어짐")
        print(f'· [{tag}] {e["big"]} ({g["seconds"]:.1f}초)')
        for x, o in zip(s, g["offsets"]): print(f'      +{o}일  {x}')
secs.sort()
print(f'상태 {got[0]["status"]} · 큰일 {n} · 걸음 {steps_n} · "~기"로 끝남 {100*ending//max(1,steps_n)}% · 가장 긴 것 {secs[-1]:.1f}초')
print(f'steps: 3~5 걸음 {count_ok}/{n} · 모델이 쓴 것 {ai} · 다듬어 둔 걸음 {known} · 규칙으로 떨어짐 {n-ai-known} · 마감 넘긴 걸음 {late} · 가운데값 {secs[n//2]:.1f}초')

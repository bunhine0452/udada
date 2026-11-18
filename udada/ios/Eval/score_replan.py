"""한 주 풀기 채점. usage: score_replan.py <묶음.json> <결과.json> [v]
묶음마다: 때가 걸린 일(avoid — 내가 붙인 라벨)을 미뤘나 · 넘치는 칸이 풀렸나(범위의 넘침이 0 또는 처음의 20% 이하) · 지키라고 한 일을 건드렸나 · 넘치지 않는데 옮겼나 · 비우라는 날이 비었나.
모델만으로 얼마나 풀렸는지와 도구를 불렀는지도 따로 센다 (규칙이 모자란 만큼을 채우므로, 합친 점수만 보면 모델이 한 일이 안 보인다)."""
import json, sys
cases = json.load(open(sys.argv[1])); out = {o["ask"]: o for o in json.load(open(sys.argv[2]))}
verbose = len(sys.argv) > 3 and sys.argv[3]
relieve = solved = solved_ai = touched = needless = clear = cleared = tools = aimoves = moves = hasty = 0
secs = []
for c in cases:
    o = out.get(c["ask"]); e = c["expect"]
    if o is None: print("  ! 결과 없음:", c["ask"]); continue
    secs.append(o["seconds"]); tools += o["toolCalls"] > 0
    on = [m for m in o["moves"] if not m.get("optional")]   # 꺼 둔 선택지는 옮긴 것으로 치지 않는다
    moved = [m["title"] for m in on]; moves += len(moved); aimoves += sum(m["ai"] for m in on)
    bad = [t for t in e.get("keep", []) if t in moved]; touched += len(bad)
    note = []
    if e.get("none"):
        if moved: needless += len(moved); note.append(f"넘치지 않는데 {len(moved)}개 옮김")
    if e.get("relieve"):
        relieve += 1
        ok = o["after"] == 0 or o["after"] <= 0.2 * o["before"]; solved += ok
        solved_ai += (o["afterAIOnly"] == 0 or o["afterAIOnly"] <= 0.2 * o["before"]) and o["before"] > 0
        if not ok: note.append(f'안 풀림 {o["before"]}→{o["after"]}분')
        if o["before"] == 0: note.append("넘침을 못 읽음(범위)")
    if "clear" in e:
        clear += 1; ok = o["clear"] and o["left"] == 0; cleared += ok
        if not ok: note.append(f'안 비워짐 (남은 {o["left"]}, 비우기 읽음 {o["clear"]})')
    if bad: note.append("지키라는 일 건드림: " + ", ".join(bad))
    rush = [t for t in e.get("avoid", []) if t in moved]; hasty += len(rush)
    if rush: note.append("때가 걸린 일을 미룸: " + ", ".join(rush))
    if verbose or note:
        print(f'  {"✗" if note else "✓"} {c["ask"]}  [도구 {o["toolCalls"]}회 · 모델 옮김 {sum(m["ai"] for m in o["moves"])}/{len(moved)} · {o["seconds"]:.1f}초]' + ("  ← " + "; ".join(note) if note else ""))
        if verbose:
            if o.get("proposed"): print("      모델의 안:", " | ".join(o["proposed"]), "   (할 일:", "; ".join(o.get("todos", [])) + ")")
            for m in o["moves"]: print(f'      {"(꺼 둠) " if m.get("optional") else ""}{"AI" if m["ai"] else "규칙"} {m["title"]}: {m["from"]}일 {m["fromPart"]} → {m["to"]}일 {m["toPart"]}  {m["why"]}')
secs.sort(); med = secs[len(secs) // 2] if secs else 0
print(f'replan: 묶음 {len(cases)} · 도구를 부른 묶음 {tools}/{len(cases)} · 모델이 낸 옮김 {aimoves}/{moves} · 가운데값 {med:.1f}초 · 상태 {next(iter(out.values()))["status"] if out else "?"}')
print(f'replan 판정: 넘침 풀림 {solved}/{relieve} ({100 * solved // max(1, relieve)}%) · 모델만으로 {solved_ai}/{relieve} · 비우기 {cleared}/{clear} · 지키라는 일 건드림 {touched} · 필요 없는 옮김 {needless} · 때가 걸린 일을 미룸 {hasty}')

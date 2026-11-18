import json, sys
exp = json.load(open(sys.argv[1])); got = json.load(open(sys.argv[2])); verbose = len(sys.argv) > 3 and sys.argv[3]
total = right = whole = wrong_change = ai = steps_n = 0; secs = []
for e, g in zip(exp, got):
    secs.append(g["seconds"]); steps = g["steps"]; steps_n += len(steps); ai += sum(1 for s in steps if s["ai"])
    used = set(); notes = []; allok = True
    for x in e["expect"]:
        total += 1
        def match(s):
            if s["kind"] != x["kind"]: return False
            if x["kind"] == "add": return all(k in s["line"] for k in x.get("has", []))
            if s["target"] != x["target"]: return False
            if x["kind"] == "move":
                if x.get("later"): return s["later"]
                if "dayOffset" in x and s["dayOffset"] != x["dayOffset"]: return False
                if "time" in x and s["time"] != x["time"]: return False
            return True
        hit = next((i for i, s in enumerate(steps) if i not in used and match(s)), None)
        if hit is None: allok = False; notes.append("안 됨: " + json.dumps(x, ensure_ascii=False))
        else: used.add(hit); right += 1
    # 기대에 없는데 기존 일을 건드리는 줄 = 위험한 오류 (넣기는 덜 위험)
    for i, s in enumerate(steps):
        if i not in used and s["ok"]:
            allok = False
            if s["kind"] != "add": wrong_change += 1
            notes.append("기대에 없음: %s %s%s" % (s["kind"], s["target"] or s["line"], "" if s["kind"] == "add" else " ← 기존 일을 잘못 건드림"))
    whole += allok
    if verbose and notes: print("·", e["cmd"]); [print("    " + n) for n in notes]
secs.sort()
print(f'상태 {got[0]["status"]} · 문장 {len(exp)} · 기대 동작 {total} · 낸 줄 {steps_n} (모델이 읽은 줄 {ai}) · 가운데값 {secs[len(secs)//2]:.1f}초')
print(f'cmd: 문장 통째로 맞음 {whole}/{len(exp)} ({100*whole//len(exp)}%) · 동작 맞음 {right}/{total} ({100*right//total}%) · 기존 일을 잘못 건드림 {wrong_change}')

# 연구용: 표 수 · 따로 묻는 검사 둘을 여러 기준으로 겹쳐 본다.  python3 Eval/study_votes.py
import json, os
W = os.environ["TMPDIR"] + "udada-eval"
SETS = ["sense", "sense-verdict", "sense-verdict2", "sense-verdict3"]
def rule(name, f):
    row = []
    for s in SETS:
        exp = json.load(open(f"Eval/{s}.json")); got = json.load(open(f"{W}/{s}.votes.json"))
        need = found = wrong = picked = 0
        for e, g in zip(exp, got):
            want, ok = set(e["want"]), set(e["ok"]); lit = set(g["literal"])
            fin = set(lit)
            for t, v in g["votes"].items():
                if f(v, g["fits"].get(t, False), g["off"].get(t, True), bool(lit)): fin.add(t)
            need += len(want); found += len(want & fin); wrong += len(fin - want - ok); picked += len(fin)
        row.append(f"{100*found//need:3d}% · {wrong}/{picked} ({100*wrong/max(1,picked):.0f}%)")
    print(f"{name:34s}", " | ".join(row))
print(" " * 34, " | ".join(SETS))
rule("낱말만", lambda v, f, o, l: False)
rule("v>=3(lit 4) & fits  [지금]", lambda v, f, o, l: v >= (4 if l else 3) and f)
rule("v>=3(lit 4) & fits & !off", lambda v, f, o, l: v >= (4 if l else 3) and f and not o)
rule("v>=3(lit 5) & fits & !off", lambda v, f, o, l: v >= (5 if l else 3) and f and not o)
rule("v>=3, lit 없음만 & fits", lambda v, f, o, l: not l and v >= 3 and f)
rule("v>=3, lit 없음만 & fits & !off", lambda v, f, o, l: not l and v >= 3 and f and not o)
rule("v>=4(lit 5) & fits & !off", lambda v, f, o, l: v >= (5 if l else 4) and f and not o)
rule("v>=4 & fits", lambda v, f, o, l: v >= 4 and f)
rule("v>=4, lit 없음만 & fits", lambda v, f, o, l: not l and v >= 4 and f)
rule("v>=2 & fits & !off", lambda v, f, o, l: v >= 2 and f and not o)
rule("v==5 & fits", lambda v, f, o, l: v == 5 and f)
rule("lit 없음 & v>=3 & fits & !off [지금]", lambda v, f, o, l: not l and v >= 3 and f and not o)
rule("lit 없음 & (v==5 | v>=3&f&!o)", lambda v, f, o, l: not l and (v == 5 or (v >= 3 and f and not o)))
rule("lit 없음 & (v==5 | v>=3&f)", lambda v, f, o, l: not l and (v == 5 or (v >= 3 and f)))
rule("lit 없음 & (v>=4 | v>=3&f&!o)", lambda v, f, o, l: not l and (v >= 4 or (v >= 3 and f and not o)))
rule("lit 없음 & v==5", lambda v, f, o, l: not l and v == 5)

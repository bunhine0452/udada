import json, re, sys
exp = json.load(open(sys.argv[1])); got = json.load(open(sys.argv[2])); verbose = len(sys.argv) > 3 and sys.argv[3]
total = matched = right = lost = extra = leak = cards = ai = 0
secs = []
for e, g in zip(exp, got):
    cs = g["cards"]; cards += len(cs); secs.append(g["seconds"]); ai += sum(1 for c in cs if c["ai"])
    used = set(); notes = []
    for x in e["expect"]:
        total += 1
        hit = next((i for i, c in enumerate(cs) if i not in used and any(k in c["text"] for k in x["keys"])), None)
        if hit is None:
            # 다른 기대와 한 카드에 뭉쳤나 (끊지 못함) — 그것도 '잃은 줄'로 센다
            lost += 1; notes.append("잃음: " + "/".join(x["keys"]))
            continue
        used.add(hit); matched += 1
        if cs[hit]["bin"] in x["bins"]: right += 1
        else: notes.append(f'칸: {cs[hit]["text"]} → {cs[hit]["bin"]} (기대 {"/".join(x["bins"])})')
    for i, c in enumerate(cs):
        if i not in used: extra += 1; notes.append("남는 카드: " + c["text"])
        if re.search(r"[()\[\]]|\b(now|date|worry|drop)\b", c["text"]): leak += 1; notes.append("꼬리표: " + c["text"])
    if verbose and notes:
        print("·", e["raw"][:40] + "…"); [print("    " + n) for n in notes]
secs.sort()
print(f'상태 {got[0]["status"] if got else "?"} · 묶음 {len(exp)} · 기대 줄 {total} · 카드 {cards} (모델이 낸 것 {ai})')
print(f'걸린 시간 가운데값 {secs[len(secs)//2]:.1f}초 · 가장 긴 것 {secs[-1]:.1f}초')
print(f'eval: 잃은 줄 {lost} · 꼬리표 {leak} · 남는 카드 {extra} · 칸 정확도 {right}/{matched} ({100*right/max(1,matched):.0f}%)')

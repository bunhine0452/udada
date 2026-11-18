"""우다다 v5 저장 파일(udada-v5.json) 형식으로 '써 본 사람'의 데이터를 만든다 — 스크린샷용.
Date 는 JSONEncoder 기본값(2001-01-01 UTC 기준 초), DayKey 는 yyyy-MM-dd, Part 는 morning/afternoon/evening."""
import json, random, uuid, sys
from datetime import datetime, timedelta, timezone, date

KST = timezone(timedelta(hours=9))
REF = datetime(2001, 1, 1, tzinfo=timezone.utc)
def ts(dt): return (dt - REF).total_seconds()
def at(d, hh, mm=0): return datetime(d.year, d.month, d.day, hh, mm, tzinfo=KST)
def key(d): return d.strftime("%Y-%m-%d")
def uid(rng): return str(uuid.UUID(int=rng.getrandbits(128), version=4)).upper()

def item(rng, title, day=None, part="afternoon", time=None, duration=30, done_at=None, created=None, **kw):
    it = {"id": uid(rng), "title": title, "note": "", "part": part, "duration": duration,
          "done": done_at is not None, "created": ts(created), "exceptions": [], "worry": False,
          "pinned": False, "fromDump": False}
    if day is not None: it["day"] = key(day)
    if time is not None: it["time"] = time
    if done_at is not None: it["doneAt"] = ts(done_at)
    it.update(kw)
    return it

def build(today, now_hm, phase):
    rng = random.Random(20261112)
    items, rests, dumps, closes, focus = [], [], [], [], []
    now = at(today, *now_hm)
    week_start = today - timedelta(days=today.weekday())          # 월요일
    grid_start = week_start - timedelta(days=7 * 11)
    began = grid_start + timedelta(days=16)                          # 9월 중순부터 썼다
    pool = {
        "morning": ["메일 답장", "회의록 정리", "약 챙겨 먹기", "견적서 보내기", "출근길 책 20쪽", "일정 확인", "은행 업무", "단톡 답장"],
        "afternoon": ["보고서 초안", "택배 보내기", "기획서 수정", "발표 자료 정리", "세탁소 맡기기", "카드값 확인", "도서관 반납", "공과금 내기", "치과 예약", "이력서 업데이트"],
        "evening": ["빨래 개기", "장보기", "분리수거", "엄마한테 전화", "운동 30분", "설거지", "화분 물 주기", "냉장고 정리", "사진 백업", "영양제 주문"],
    }
    band_hours = {"morning": (7, 11), "afternoon": (12, 17), "evening": (18, 22)}

    # 매일 물 한 잔 (반복 원본)
    water_id = uid(rng)
    water = {"id": water_id, "title": "물 한 잔", "note": "", "day": key(began), "part": "morning", "duration": 5,
             "done": False, "created": ts(at(began, 8)), "repeatRule": {"kind": "daily", "weekdays": []},
             "exceptions": [], "worry": False, "pinned": False, "fromDump": False}

    def water_done(d, hh, mm):
        water["exceptions"].append(key(d))
        items.append(item(rng, "물 한 잔", d, "morning", duration=5, done_at=at(d, hh, mm), created=at(d, 6),
                          seriesID=water_id, occurrence=key(d)))

    # 지난날: 끝낸 일 · 식히기 · 비우기 · 하루 닫기 · 집중
    d = began
    while d < today:
        wd = d.weekday()
        weekend = wd >= 5
        # 하루에 끝낸 일 개수 — 평일 2~6, 주말 0~3, 가끔 쉬는 날
        n = rng.choice([0, 1, 2, 2, 3]) if weekend else rng.choice([0, 2, 3, 3, 4, 4, 5, 6])
        if (today - d).days < 21 and not weekend: n = max(n, 2)
        for _ in range(n):
            part = rng.choice(["morning", "afternoon", "afternoon", "evening"])
            title = rng.choice(pool[part])
            h0, h1 = band_hours[part]
            done_t = at(d, rng.randint(h0, h1), rng.choice([5, 15, 25, 40, 50]))
            items.append(item(rng, title, d, part, duration=rng.choice([15, 15, 30, 30, 45]),
                              done_at=done_t, created=done_t - timedelta(days=rng.randint(0, 3), hours=rng.randint(1, 5))))
        if rng.random() < 0.7: water_done(d, rng.randint(7, 9), rng.choice([10, 30, 45]))
        if rng.random() < (0.55 if (today - d).days < 28 else 0.35):
            b = rng.randint(3, 5)
            rests.append({"at": ts(at(d, rng.randint(13, 17), rng.choice([0, 20, 40]))), "kind": rng.choice(["breath", "breath", "far", "walk"]),
                          "seconds": 60, "before": b, "after": min(10, b + rng.randint(1, 4))})
        if rng.random() < 0.22:
            b = rng.randint(6, 9)
            dumps.append({"at": ts(at(d, rng.randint(20, 22), 10)), "before": b, "after": max(1, b - rng.randint(2, 4)),
                          "now": rng.randint(1, 2), "dated": rng.randint(2, 4), "worry": rng.randint(0, 2), "dropped": rng.randint(1, 3)})
        if (not weekend and rng.random() < 0.8) or (weekend and rng.random() < 0.3):
            closes.append({"day": key(d), "at": ts(at(d, 21, rng.choice([10, 30, 45]))), "done": n,
                           "tomorrow": rng.randint(0, 2), "later": rng.randint(0, 1), "dropped": rng.randint(0, 1)})
        d += timedelta(days=1)

    # 이번 주 월~수는 닫았다 (오늘은 아직)
    for k in range(today.weekday()):
        dd = week_start + timedelta(days=k)
        if not any(c["day"] == key(dd) for c in closes):
            closes.append({"day": key(dd), "at": ts(at(dd, 21, 30)), "done": 3, "tomorrow": 1, "later": 0, "dropped": 0})

    # 이번 주: 식히기 넷, 비우기 둘 (써 본 주처럼)
    for k, (hh, kind, b, a) in enumerate([(15, "breath", 4, 6), (16, "far", 3, 6), (14, "breath", 4, 7), (11, "walk", 5, 7)]):
        dd = week_start + timedelta(days=min(k, today.weekday()))
        if dd < today or hh < now_hm[0]:
            rests.append({"at": ts(at(dd, hh, 30)), "kind": kind, "seconds": 60, "before": b, "after": a})
    for dd, b, a, c in [(week_start, 8, 4, (2, 3, 1, 2)), (week_start + timedelta(days=2), 7, 4, (1, 4, 1, 1))]:
        dumps.append({"at": ts(at(dd, 8, 20)), "before": b, "after": a, "now": c[0], "dated": c[1], "worry": c[2], "dropped": c[3]})

    # 집중: 예상 대 실제 (대체로 1.3배)
    for k, (t, p, s) in enumerate([("보고서 초안", 30, 42), ("기획서 수정", 45, 58), ("메일 답장", 15, 18), ("발표 자료 정리", 60, 75),
                                   ("견적서 보내기", 15, 22), ("이력서 업데이트", 30, 36), ("회의록 정리", 20, 26), ("공과금 내기", 15, 12)]):
        dd = today - timedelta(days=2 + k * 3)
        focus.append({"at": ts(at(dd, 15, 10)), "title": t, "planned": p, "spent": s, "finished": True})

    # 오늘
    late = phase == "evening"
    water_done(today, 7, 40)
    items += [
        item(rng, "팀 회의", today, "morning", time=600, duration=60, created=at(today - timedelta(days=3), 18)),
        item(rng, "회의록 정리", today, "morning", duration=20, done_at=at(today, 11, 25), created=at(today, 9, 2)),
        item(rng, "메일 답장", today, "morning", duration=15, done_at=at(today, 14, 38) if late else None, created=at(today, 8, 1)),
        item(rng, "보고서 초안", today, "afternoon", duration=30, created=at(today, 8, 2)),
        item(rng, "택배 보내기", today, "afternoon", duration=15, done_at=at(today, 13, 5), created=at(today, 8, 3)),
        item(rng, "치과", today, "afternoon", time=900, duration=60, created=at(today - timedelta(days=6), 20)),
        item(rng, "저녁 약속", today, "evening", time=1170, duration=90, created=at(today - timedelta(days=2), 12)),
        item(rng, "빨래 개기", today, "evening", duration=15, created=at(today, 8, 4)),
        item(rng, "헬스 등록 알아보기", today, "evening", duration=15, created=at(today, 8, 5)),
        item(rng, "장보기", today + timedelta(days=1), "afternoon", duration=30, created=at(today, 8, 6)),
        item(rng, "여권 갱신", None, "afternoon", duration=30, created=at(today - timedelta(days=12), 21)),
        item(rng, "책장 정리", None, "afternoon", duration=30, created=at(today - timedelta(days=3), 21)),
        item(rng, "다음 달 월세 오르면 어떡하지", None, "afternoon", duration=30, created=at(today - timedelta(days=1), 22), worry=True),
    ]
    items.insert(0, water)
    data = {"version": 5, "items": items, "rests": rests, "dumps": dumps, "closes": closes, "focus": focus,
            "settings": {}, "seenIntro": True, "briefedDay": key(today)}
    return data

if __name__ == "__main__":
    out = sys.argv[1]
    today = date(2026, 11, 12)
    for name, hm, phase in [("lived-1420", (14, 20), "day"), ("lived-2140", (21, 40), "evening")]:
        d = build(today, hm, phase)
        with open(f"{out}/{name}.json", "w") as f: json.dump(d, f, ensure_ascii=False)
        done_week = sum(1 for it in d["items"] if it.get("doneAt") and it["doneAt"] >= ts(at(today - timedelta(days=today.weekday()), 0)))
        print(name, "items", len(d["items"]), "rests", len(d["rests"]), "dumps", len(d["dumps"]), "closes", len(d["closes"]), "done this week", done_week)

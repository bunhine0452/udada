#!/usr/bin/env bash
# 실제 기기 안 모델(Apple Intelligence)로 쏟아내기 나누기 품질을 잰다. Mac 에서만 돈다 (모델이 켜져 있어야 한다).
#   Eval/run.sh tune      조정용 묶음 (프롬프트·검사를 고칠 때 본다)
#   Eval/run.sh heldout   처음 보는 묶음 (판정은 이것으로)
#   EVAL_NOAI=1 …         규칙만 (모델 없는 기기의 점수)
set -euo pipefail
IOS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SET="${1:-heldout}"
WORK="${TMPDIR:-/tmp}/udada-eval"
mkdir -p "$WORK"
cd "$IOS"
if [[ "${EVAL_SKIP_BUILD:-}" != "1" ]]; then
  xcodegen generate --quiet
  xcodebuild build -project Udada.xcodeproj -scheme UdadaMac -destination 'platform=macOS' \
    -derivedDataPath "$WORK/dd" CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD FAILED" || true
fi
APP="$WORK/dd/Build/Products/Debug/Udada.app/Contents/MacOS/Udada"
[[ -x "$APP" ]] || { echo "빌드가 없다"; exit 1; }
if [[ "$SET" == photos* ]]; then
  # 사진 보기: 그림마다 글자 인식만 쓴 길과 모델이 그림을 본 길을 견준다
  OUT="$WORK/$SET.out.json"; rm -f "$OUT"; rm -rf "$WORK/data"
  "$APP" -udNoSync -udNoHotKey -udSkipIntro -udDataDir "$WORK/data" -udEvalPhotos "$IOS/Eval/$SET" "$OUT" >/dev/null 2>&1 || true
  [[ -f "$OUT" ]] || { echo "결과가 없다"; exit 1; }
  python3 "$IOS/Eval/score_photos.py" "$IOS/Eval/$SET/labels.json" "$OUT" "${EVAL_VERBOSE:-}"
  exit 0
fi
OUT="$WORK/$SET.out.json"
rm -f "$OUT"
NOAI=""; [[ "${EVAL_NOAI:-}" == "1" ]] && NOAI="-udNoAI"
[[ "${EVAL_RAW:-}" == "1" ]] && NOAI="-udEvalRaw"
[[ "${EVAL_STREAM:-}" == "1" ]] && NOAI="-udEvalStream"
rm -rf "$WORK/data"   # 설정(AI 끔)이 다음 실행에 남지 않게
"$APP" -udNoSync -udNoHotKey -udSkipIntro -udDataDir "$WORK/data" $NOAI -udEval "$IOS/Eval/$SET.json" "$OUT" >/dev/null 2>&1 || true
[[ -f "$OUT" ]] || { echo "결과가 없다 (앱이 끝까지 못 돌았다)"; exit 1; }
if [[ "${EVAL_STREAM:-}" == "1" ]]; then
  python3 - "$OUT" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
first = sorted(x["ticks"][0]["t"] for x in d); firstai = sorted(next((t["t"] for t in x["ticks"] if t["ai"] > 0), 99) for x in d); end = sorted(x["seconds"] for x in d)
steps = sorted(len(x["ticks"]) for x in d)
m = lambda a: a[len(a)//2]
print(f'stream: 묶음 {len(d)} · 첫 카드까지 {m(first)*1000:.0f}ms · 모델이 다듬은 첫 카드 {m(firstai):.1f}초 · 끝 {m(end):.1f}초 · 목록이 바뀐 횟수 가운데값 {m(steps)}')
x = d[0]
print("  예:", " → ".join(f'{t["t"]:.1f}초 {t["ai"]}/{t["cards"]}장' for t in x["ticks"]))
PY
fi
if [[ "$SET" == replan* ]]; then
  python3 "$IOS/Eval/score_replan.py" "$IOS/Eval/$SET.json" "$OUT" "${EVAL_VERBOSE:-}"
elif [[ "$SET" == cmd* ]]; then
  python3 "$IOS/Eval/score_cmd.py" "$IOS/Eval/$SET.json" "$OUT" "${EVAL_VERBOSE:-}"
elif [[ "$SET" == steps* ]]; then
  python3 "$IOS/Eval/score_steps.py" "$IOS/Eval/$SET.json" "$OUT" "${EVAL_VERBOSE:-}"
elif [[ "$SET" == capture* || "$SET" == audio* ]]; then
  python3 "$IOS/Eval/score_capture.py" "$IOS/Eval/$SET.json" "$OUT" "${EVAL_VERBOSE:-}"
elif [[ "$SET" == sense* ]]; then
  python3 "$IOS/Eval/score_sense.py" "$IOS/Eval/$SET.json" "$OUT" "${EVAL_VERBOSE:-}"
elif [[ "$SET" == find* ]]; then
  python3 "$IOS/Eval/score_find.py" "$IOS/Eval/$SET.json" "$OUT" "${EVAL_VERBOSE:-}"
else
  python3 "$IOS/Eval/score.py" "$IOS/Eval/$SET.json" "$OUT" "${EVAL_VERBOSE:-}"
fi

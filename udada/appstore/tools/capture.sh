#!/bin/zsh
# 우다다 App Store 스크린샷 다시 만들기 (약 15분).
#   시뮬레이터를 하나 새로 만들어 → 최신 코드로 빌드·설치 → '써 본 사람' 데이터로 화면을 찍고 →
#   위젯은 확장의 뷰 코드를 14:20 시계로 그려 → 세 크기로 합성해 udada/appstore/screenshots 에 쓴 뒤 →
#   시뮬레이터와 빌드 파일을 지운다. 다른 시뮬레이터는 건드리지 않는다.
# usage: udada/appstore/tools/capture.sh        (KEEP=1 이면 작업 폴더·시뮬레이터를 남긴다)
set -u
TOOLS=${0:A:h}; AS=${TOOLS:h}; IOS=${AS:h}/ios
WORK=$(mktemp -d -t udada-shots)
SHOTS=$WORK/shots; WID=$WORK/widgets; DATA=$WORK/data
mkdir -p $SHOTS $WID $DATA
APP=io.github.bunhine0452.udada; GAL=local.appstore.gallery
RUNTIME=${RUNTIME:-$(xcrun simctl list runtimes -j | python3 -c "
import json,sys
r=[x for x in json.load(sys.stdin)['runtimes'] if x['platform']=='iOS' and x['isAvailable']
   and any(d['identifier'].endswith('iPhone-17-Pro-Max') for d in x.get('supportedDeviceTypes',[]))]
print(sorted(r, key=lambda x: [int(p) for p in x['version'].split('.')])[-1]['identifier'])")}
SIM=$(xcrun simctl create "udada-appstore-shots" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max $RUNTIME) || exit 1
echo "sim $SIM ($RUNTIME) · work $WORK"

cleanup() {
  [[ ${KEEP:-0} == 1 ]] && { echo "kept $WORK, sim $SIM"; return; }
  xcrun simctl shutdown $SIM >/dev/null 2>&1; xcrun simctl delete $SIM >/dev/null 2>&1
  rm -rf $WORK; echo "cleaned sim + $WORK"
}
trap cleanup EXIT

# 1. 시뮬레이터: 한국어 · 한글 키보드 · 24시간제 · 밀어서 입력 안내 끄기
xcrun simctl boot $SIM && xcrun simctl bootstatus $SIM >/dev/null 2>&1
sp() { xcrun simctl spawn $SIM defaults write "$@"; }
sp -g AppleLanguages -array ko-KR en-US
sp -g AppleLocale -string ko_KR
sp -g AppleICUForce24HourTime -bool true
sp -g AppleKeyboards -array "ko_KR@sw=Korean;hw=Automatic" "en_US@sw=QWERTY;hw=Automatic" "emoji@sw=Emoji"
sp com.apple.Preferences KeyboardsCurrentAndNext -array "ko_KR@sw=Korean;hw=Automatic" "en_US@sw=QWERTY;hw=Automatic"
sp com.apple.Preferences DidShowContinuousPathIntroduction -bool true
sp com.apple.keyboard.preferences DidShowContinuousPathIntroduction -bool true
sp com.apple.Preferences KeyboardAutocorrection -bool false
sp com.apple.Preferences KeyboardPrediction -bool false
xcrun simctl shutdown $SIM && xcrun simctl boot $SIM && xcrun simctl bootstatus $SIM >/dev/null 2>&1

# 2. 빌드: 앱 · 스크린샷 UI 테스트 · 위젯 갤러리(확장의 뷰 파일을 그대로 컴파일) · 시계 옮기는 dylib
mkdir -p $WORK/runner/Tests $WORK/gallery/App
cp $TOOLS/runner/Shots.swift $WORK/runner/Tests/
cat > $WORK/runner/project.yml <<EOF
name: ShotRunner
options: { bundleIdPrefix: local.appstore.shots, deploymentTarget: { iOS: "18.0" } }
settings: { base: { SWIFT_VERSION: "5.0", CODE_SIGN_IDENTITY: "-", CODE_SIGN_STYLE: Manual, DEVELOPMENT_TEAM: "" } }
targets:
  ShotUITests:
    type: bundle.ui-testing
    platform: iOS
    sources: [Tests]
    settings: { base: { GENERATE_INFOPLIST_FILE: YES, PRODUCT_BUNDLE_IDENTIFIER: local.appstore.shots.uitests } }
schemes:
  ShotUITests: { build: { targets: { ShotUITests: [test] } }, test: { targets: [ShotUITests] } }
EOF
cp $TOOLS/gallery/GalleryApp.swift $WORK/gallery/App/
cat > $WORK/gallery/App/Info.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>UIAppFonts</key><array><string>GowunBatang-Bold.ttf</string></array></dict></plist>
EOF
cat > $WORK/gallery/project.yml <<EOF
name: WidgetGallery
options: { bundleIdPrefix: local.appstore.gallery, deploymentTarget: { iOS: "18.0" } }
settings: { base: { SWIFT_VERSION: "5.0", CODE_SIGN_IDENTITY: "-", CODE_SIGN_STYLE: Manual, DEVELOPMENT_TEAM: "" } }
targets:
  WidgetGallery:
    type: application
    platform: iOS
    sources:
      - path: App
      - path: $IOS/Shared
      - path: $IOS/UdadaWidgets/WidgetParts.swift
      - path: $IOS/UdadaWidgets/TodayWidget.swift
      - path: $IOS/UdadaWidgets/NowWidget.swift
      - path: $IOS/UdadaWidgets/DayProvider.swift
      - path: $IOS/UdadaWidgets/ActivityWidget.swift
      - { path: $IOS/Udada/Resources/Fonts/GowunBatang-Bold.ttf, buildPhase: resources }
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: $GAL
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_FILE: App/Info.plist
        INFOPLIST_KEY_UIApplicationSceneManifest_Generation: YES
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
EOF
(cd $WORK/runner && xcodegen generate >/dev/null) && (cd $WORK/gallery && xcodegen generate >/dev/null) || exit 1
build() { xcodebuild "$@" -destination "id=$SIM" > $WORK/build.log 2>&1 || { grep error: $WORK/build.log | head; echo "BUILD FAILED: $*"; exit 1; } }
build build -project $IOS/Udada.xcodeproj -scheme Udada -derivedDataPath $WORK/dd
build build -project $WORK/gallery/WidgetGallery.xcodeproj -scheme WidgetGallery -derivedDataPath $WORK/dd
build build-for-testing -project $WORK/runner/ShotRunner.xcodeproj -scheme ShotUITests -derivedDataPath $WORK/dd
xcrun -sdk iphonesimulator clang -arch arm64 -target arm64-apple-ios18.0-simulator -dynamiclib -O2 -o $WORK/faketime.dylib $TOOLS/faketime.c && codesign -s - -f $WORK/faketime.dylib >/dev/null 2>&1
xcrun simctl install $SIM $WORK/dd/Build/Products/Debug-iphonesimulator/Udada.app || exit 1
xcrun simctl install $SIM $WORK/dd/Build/Products/Debug-iphonesimulator/WidgetGallery.app || exit 1
echo "built + installed $(date +%H:%M)"

# 3. '써 본 사람' 데이터 (11월 12일 목요일, 12주치 기록)
python3 $TOOLS/gen_data.py $DATA >/dev/null
GROUP=$(xcrun simctl get_app_container $SIM $APP groups | awk '/group.io.github.bunhine0452.udada/{print $2}')
put() { xcrun simctl terminate $SIM $APP >/dev/null 2>&1; cp "$1" "$GROUP/udada-v5.json"; }
bar() { xcrun simctl status_bar $SIM override --time "$1" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3; }

# 4. 실행 인자만으로 열리는 화면: 다 그려질 때까지 기다렸다가 찍는다
snap() {  # snap <name> <data> <now> <clock> [udada://...]
  put $DATA/$2.json; bar $4
  local args=(-udSkipIntro -udNow $3); [[ -n ${5:-} ]] && args+=(-udOpen $5)
  (( $# > 5 )) && args+=("${@:6}")   # 그 밖의 실행 인자 (사용법 장면을 멈춰 찍을 때)
  xcrun simctl launch --terminate-running-process $SIM $APP $args >/dev/null
  local i n
  for i in $(seq 1 40); do
    sleep 2; xcrun simctl io $SIM screenshot $WORK/probe.png >/dev/null 2>&1
    n=$(python3 -c "
from PIL import Image
im=Image.open('$WORK/probe.png').convert('L').crop((0,400,1320,2600)).resize((132,220))
print(sum(1 for p in im.tobytes() if p<150))")
    (( n > 60 )) && break
  done
  sleep 3; xcrun simctl io $SIM screenshot $SHOTS/$1.png >/dev/null 2>&1 && echo "  $1"
}
snap today     lived-1420 2026-11-12T14:20 14:20
snap rest-pick lived-1420 2026-11-12T14:20 14:20 udada://rest
snap records   lived-2140 2026-11-12T21:40 21:40 udada://records
snap siri      lived-1420 2026-11-12T09:41 9:41 "" -udTourPage 6 -udTourAt 12.6

# 5. 눌러야 하는 화면 (UI 테스트)
ui() {  # ui <test> <data|-> <clock> [add text]
  [[ $2 != - ]] && put $DATA/$2.json; bar $3
  TEST_RUNNER_SHOT_DIR=$SHOTS TEST_RUNNER_ADD_TEXT="${4:-}" xcodebuild test-without-building \
    -project $WORK/runner/ShotRunner.xcodeproj -scheme ShotUITests -destination "id=$SIM" -derivedDataPath $WORK/dd \
    -only-testing:ShotUITests/Shots/$1 > $WORK/ui-$1.log 2>&1
  echo "  $1 $(grep -E 'Executed 1 test' $WORK/ui-$1.log | tail -1 | cut -c1-60)"
}
ui testJ_Split    lived-1420 14:20
ui testK_AIPanel  lived-1420 14:20
ui testH_DumpAll  -          14:20
ui testC_Close    lived-2140 21:40
ui testI_Evidence lived-1420 14:20

# 6. 위젯 · 실시간 현황: 갤러리 앱 프로세스의 벽시계만 2026-11-12 14:20 으로 옮겨 그린다
OFF=$(python3 -c "
from datetime import datetime, timezone, timedelta
print((datetime(2026,11,12,14,20,tzinfo=timezone(timedelta(hours=9))) - datetime.now(timezone.utc)).total_seconds() + 2)")
SIMCTL_CHILD_DYLD_INSERT_LIBRARIES=$WORK/faketime.dylib SIMCTL_CHILD_FAKE_OFFSET=$OFF \
  xcrun simctl launch --terminate-running-process $SIM $GAL -out $WID -data $DATA/lived-1420.json -now 2026-11-12T14:20 >/dev/null
for i in $(seq 1 20); do [[ -f $WID/la-rest.png ]] && break; sleep 1; done
sleep 3; xcrun simctl io $SIM screenshot $WID/gallery-live.png >/dev/null 2>&1
python3 - "$WID" <<'PY'
import sys
from PIL import Image, ImageChops
d = sys.argv[1]
im = Image.open(f"{d}/gallery-live.png").convert("RGB"); W, H = im.size
white = Image.new("RGB", (W, 1), (255, 255, 255))
rows = [ImageChops.difference(im.crop((0, y, W, y + 1)), white).getbbox() is not None for y in range(300, H)]
bands, start = [], None
for i, v in enumerate(rows):
    if v and start is None: start = i + 300
    if not v and start is not None: bands.append((start, i + 300)); start = None
for n, (a, b) in enumerate(bands[:2]):
    sub = im.crop((0, a, W, b)); sub.crop(ImageChops.difference(sub, Image.new("RGB", sub.size, (255, 255, 255))).getbbox()).save(f"{d}/la-{n}.png")
print("  widgets + live activities")
PY

# 날것 촬영분을 따로 남긴다 (RAW=<폴더> — 합성만 다시 손볼 때)
[[ -n ${RAW:-} ]] && mkdir -p $RAW && cp -R $SHOTS $WID $RAW/

# 7. 합성 → udada/appstore/screenshots (6.9" · 6.5" · 6.3" + preview.png)
python3 $TOOLS/compose.py $TOOLS/shots.json $SHOTS $WID $AS/screenshots

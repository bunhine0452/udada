#!/bin/zsh
# 우다다 소개 영상을 다시 만든다:  udada/film/render.sh [출력 폴더]      (UHD=1 이면 4K 도)
# 앱의 사용법 장면 코드를 그대로 컴파일해 프레임마다 그리고(시뮬레이터·화면 녹화 없음), 효과음은 sfx.py 가 만든다. ffmpeg 가 있어야 한다.
set -e
HERE=${0:A:h}; IOS=${HERE:h}/ios; OUT=${1:-$HERE/out}; BUILD=$(mktemp -d -t udada-film)
mkdir -p $OUT
swiftc -O -o $BUILD/film \
  $HERE/main.swift $HERE/Stubs.swift \
  $IOS/Shared/Theme.swift $IOS/Udada/AI/GuideKit.swift $IOS/Udada/AI/GuideScenesA.swift $IOS/Udada/AI/GuideScenesB.swift $IOS/Udada/AI/AITour.swift
FONT=$IOS/Udada/Resources/Fonts/GowunBatang-Bold.ttf
one() {  # one <이름> <폭> <높이>
  $BUILD/film $FONT $BUILD/$1.mp4 $2 $3 60 | tail -1
  python3 $HERE/sfx.py $BUILD/$1.mp4.cues.json $BUILD/sfx.wav
  ffmpeg -y -loglevel error -i $BUILD/$1.mp4 -i $BUILD/sfx.wav -c:v copy -c:a aac -b:a 192k -shortest -movflags +faststart $OUT/udada-intro-$1.mp4
}
one 1080p 1920 1080
[[ -n ${UHD:-} ]] && one 4k 3840 2160
# README 에 넣을 짧은 미리보기: 둘째 컷(쏟아내기). 시작 시각은 cues 에서 읽는다.
START=$(python3 -c "import json;c=json.load(open('$BUILD/1080p.mp4.cues.json'));s=c['shots'][1];print(s['start']+0.25)")
LEN=$(python3 -c "import json;c=json.load(open('$BUILD/1080p.mp4.cues.json'));s=c['shots'][1];print(c['lead']+s['to']-s['from']+0.3)")
ffmpeg -y -loglevel error -ss $START -t $LEN -i $OUT/udada-intro-1080p.mp4 -vf "fps=15,scale=800:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=64[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" $OUT/udada-preview.gif
rm -rf $BUILD
ls -la $OUT

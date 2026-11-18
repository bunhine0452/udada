#!/bin/zsh
# 우다다 소개 영상을 다시 만든다:  udada/film/render.sh [출력 폴더]
# 앱의 사용법 장면 코드를 그대로 컴파일해 프레임마다 그린다 (시뮬레이터·화면 녹화 없음). ffmpeg 가 있어야 한다.
set -e
HERE=${0:A:h}; IOS=${HERE:h}/ios; OUT=${1:-$HERE/out}; BUILD=$(mktemp -d -t udada-film)
mkdir -p $OUT
swiftc -O -o $BUILD/film \
  $HERE/main.swift $HERE/Stubs.swift \
  $IOS/Shared/Theme.swift $IOS/Udada/AI/GuideKit.swift $IOS/Udada/AI/GuideScenesA.swift $IOS/Udada/AI/GuideScenesB.swift $IOS/Udada/AI/AITour.swift
FONT=$IOS/Udada/Resources/Fonts/GowunBatang-Bold.ttf
$BUILD/film $FONT $OUT/udada-intro-1080p.mp4 1920 1080 60
[[ -n ${UHD:-} ]] && $BUILD/film $FONT $OUT/udada-intro-4k.mp4 3840 2160 60
# README 에 넣을 짧은 미리보기 (쏟아내기 장면, 소리 없음)
ffmpeg -y -loglevel error -ss 30.2 -t 11.5 -i $OUT/udada-intro-1080p.mp4 -vf "fps=20,scale=960:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" $OUT/udada-preview.gif
rm -rf $BUILD
ls -la $OUT

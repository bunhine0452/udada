#!/usr/bin/env bash
# 우다다 iOS 앱을 아카이브하고 TestFlight 로 올린다.
#
#   udada/ios/scripts/archive.sh              # 아카이브 + 업로드
#   udada/ios/scripts/archive.sh --no-upload  # 아카이브만
#   udada/ios/scripts/archive.sh --mac        # Mac 앱 (같은 번들 ID — App Store Connect 앱 레코드에 macOS 플랫폼이 있어야 한다)
#
# 전제: Xcode 에 개발자 계정 로그인(자동 서명), App Store Connect 에 io.github.bunhine0452.udada 앱 레코드.
# 빌드 번호는 App Store Connect 가 올린다(ExportOptions 의 manageAppVersionAndBuildNumber).
set -euo pipefail

IOS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE="$IOS/build/Udada.xcarchive"
EXPORT="$IOS/build/export"
UPLOAD=1
SCHEME=Udada
DEST='generic/platform=iOS'
for a in "$@"; do
    [[ "$a" == "--no-upload" ]] && UPLOAD=0
    if [[ "$a" == "--mac" ]]; then
        SCHEME=UdadaMac; DEST='generic/platform=macOS'
        ARCHIVE="$IOS/build/UdadaMac.xcarchive"; EXPORT="$IOS/build/export-mac"
    fi
done

cd "$IOS"
xcodegen generate --quiet
echo "▸ 아카이브 → $ARCHIVE"
rm -rf "$ARCHIVE"
xcodebuild archive \
    -project Udada.xcodeproj -scheme "$SCHEME" \
    -destination "$DEST" \
    -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates \
    | grep -E 'error:|warning: .*sign|ARCHIVE' || true
[[ -d "$ARCHIVE" ]] || { echo "아카이브가 없다"; exit 1; }


if [[ "$UPLOAD" == "1" ]]; then
    echo "▸ TestFlight 로 업로드"
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE" \
        -exportOptionsPlist Config/ExportOptions.plist \
        -exportPath "$EXPORT" \
        -allowProvisioningUpdates \
        2>&1 | grep -E 'error|EXPORT|Upload|upload' || true
fi

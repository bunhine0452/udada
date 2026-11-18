#!/usr/bin/env bash
# 우다다 Mac nightly 빌드: 지금 소스로 릴리스 빌드를 만들어 zip 으로 묶는다.
#
#   udada/ios/scripts/nightly.sh             # build/nightly/Udada-mac-nightly-YYYYMMDD.zip (+ .sha256)
#   udada/ios/scripts/nightly.sh --publish   # 위 + GitHub 의 'nightly' 릴리스를 새 빌드로 바꾼다 (gh 로그인 필요)
#
# App Store 판과 다른 점: iCloud 권한 없이 서명한다(UdadaMacNightly.entitlements) — 기록은 이 Mac 에만 남고 iPhone 과 맞추지 않는다.
# 번들 ID 도 따로(…udada.nightly)라 App Store 판과 저장소가 섞이지 않는다.
# NIGHTLY_IDENTITY 에 "Developer ID Application: …" 을 주면 그 인증서로, 없으면 임시 서명(-)으로 서명한다.
# NIGHTLY_NOTARIZE=1 이면 공증(notarization)까지 한다 — Xcode 에 로그인된 계정을 쓴다. 공증하지 않은 빌드는 처음 열 때
# 시스템 설정 → 개인정보 보호 및 보안에서 '그래도 열기'를 눌러야 한다.
set -euo pipefail

IOS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$IOS/build/nightly"
DD="$(mktemp -d -t udada-nightly)"
STAMP="$(date +%Y%m%d)"
IDENTITY="${NIGHTLY_IDENTITY:--}"
PUBLISH=0; [[ "${1:-}" == "--publish" ]] && PUBLISH=1

cd "$IOS"
xcodegen generate --quiet
SETTINGS=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" PROVISIONING_PROFILE_SPECIFIER=""
    CODE_SIGN_ENTITLEMENTS=UdadaMac/UdadaMacNightly.entitlements
    PRODUCT_BUNDLE_IDENTIFIER=io.github.bunhine0452.udada.nightly ENABLE_HARDENED_RUNTIME=YES)

if [[ "${NIGHTLY_NOTARIZE:-0}" == "1" ]]; then
    # 공증: Xcode 에 로그인된 계정으로 공증 서비스에 올리고, 끝나면 표(staple)가 붙은 앱을 받는다. 암호를 묻지 않는다.
    [[ "$IDENTITY" == Developer\ ID* ]] || { echo "공증하려면 NIGHTLY_IDENTITY 가 Developer ID 인증서여야 한다"; exit 1; }
    TEAM="$(sed -n 's/.*DEVELOPMENT_TEAM: *//p' project.yml | head -1)"
    echo "▸ 아카이브 (서명: $IDENTITY)"
    xcodebuild archive -project Udada.xcodeproj -scheme UdadaMac -configuration Release \
        -destination 'generic/platform=macOS' -archivePath "$DD/Udada.xcarchive" -derivedDataPath "$DD/dd" \
        "${SETTINGS[@]}" OTHER_CODE_SIGN_FLAGS="--timestamp" 2>&1 | grep -E 'error:|ARCHIVE' || true
    cat > "$DD/export.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>developer-id</string>
<key>destination</key><string>upload</string>
<key>signingStyle</key><string>manual</string>
<key>teamID</key><string>$TEAM</string>
<key>signingCertificate</key><string>Developer ID Application</string>
</dict></plist>
PLIST
    echo "▸ 공증 서비스에 올림"
    xcodebuild -exportArchive -archivePath "$DD/Udada.xcarchive" -exportOptionsPlist "$DD/export.plist" \
        -exportPath "$DD/up" -allowProvisioningUpdates 2>&1 | grep -E 'error|EXPORT|Uploaded' || true
    echo "▸ 공증을 기다림 (보통 몇 분)"
    for _ in $(seq 1 60); do
        xcodebuild -exportNotarizedApp -archivePath "$DD/Udada.xcarchive" -exportPath "$DD/notarized" >/dev/null 2>&1 && break
        sleep 20
    done
    APP="$DD/notarized/Udada.app"
    [[ -d "$APP" ]] || { echo "공증된 앱을 못 받았다"; rm -rf "$DD"; exit 1; }
    xcrun stapler validate "$APP"
else
    echo "▸ 빌드 (서명: $IDENTITY)"
    xcodebuild build -project Udada.xcodeproj -scheme UdadaMac -configuration Release \
        -destination 'generic/platform=macOS' -derivedDataPath "$DD" \
        "${SETTINGS[@]}" OTHER_CODE_SIGN_FLAGS="--timestamp=none" \
        2>&1 | grep -E 'error:|BUILD' || true
    APP="$DD/Build/Products/Release/Udada.app"
    [[ -d "$APP" ]] || { echo "앱이 없다"; rm -rf "$DD"; exit 1; }
fi
codesign --verify --deep --strict "$APP"

mkdir -p "$OUT"
ZIP="$OUT/Udada-mac-nightly-$STAMP.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
( cd "$OUT" && shasum -a 256 "$(basename "$ZIP")" > "$(basename "$ZIP").sha256" )
rm -rf "$DD"
echo "▸ $ZIP"

if [[ "$PUBLISH" == "1" ]]; then
    SHA="$(git -C "$IOS" rev-parse --short HEAD)"
    NOTES="지금 main($SHA)을 그대로 빌드한 Mac 앱입니다. 날마다 바뀔 수 있고 버그가 있을 수 있습니다.

- iCloud 권한 없이 서명했습니다. 기록은 이 Mac 에만 남고 iPhone 과 맞추지 않습니다. App Store 판과 저장소도 따로입니다.
- $([[ "${NIGHTLY_NOTARIZE:-0}" == "1" ]] && echo "Apple 공증(notarization)을 받았습니다. 내려받아 바로 열 수 있습니다." || echo "공증(notarization)을 하지 않았습니다. 처음 열 때 시스템 설정 → 개인정보 보호 및 보안에서 '그래도 열기'를 눌러야 합니다.")
- macOS 26 이상. Apple Intelligence 는 지원하는 Mac 에서만 돌고, 아니면 같은 흐름이 규칙으로 돕니다.
- 안정판과 iPhone 판은 App Store: https://apps.apple.com/kr/app/id6831147747"
    gh release delete nightly --yes --cleanup-tag 2>/dev/null || true
    # 소개 영상이 그려져 있으면 같이 올린다 (udada/film/render.sh)
    EXTRA=(); for f in "$IOS/../film/out/"udada-intro-*.mp4; do [[ -f "$f" ]] && EXTRA+=("$f"); done
    gh release create nightly "$ZIP" "$ZIP.sha256" "${EXTRA[@]}" --prerelease --target main \
        --title "Nightly $STAMP ($SHA)" --notes "$NOTES"
fi

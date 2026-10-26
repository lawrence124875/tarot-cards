#!/usr/bin/env bash
# iOS 平台設定（HANDOFF §9.1、§24）：ios/ 由 CI 以 flutter create 產生，這裡套用 App 設定。
# 只在 macOS CI 執行（用 PlistBuddy）。目前只做「不簽章建置」驗證能編譯；簽章與上架等 Apple 開發者帳號。
set -euo pipefail
PLIST=ios/Runner/Info.plist
PB=/usr/libexec/PlistBuddy
set_str() { $PB -c "Set :$1 $2" "$PLIST" 2>/dev/null || $PB -c "Add :$1 string $2" "$PLIST"; }

# Bundle ID 與 Android applicationId 相同（§9.1）
sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = com\.lclab\.tarotCards;/PRODUCT_BUNDLE_IDENTIFIER = com.lclab.tarot;/' ios/Runner.xcodeproj/project.pbxproj
grep -q 'PRODUCT_BUNDLE_IDENTIFIER = com.lclab.tarot;' ios/Runner.xcodeproj/project.pbxproj

# 顯示名稱（主畫面圖示下方）
set_str CFBundleDisplayName "光穗塔羅"

# App 圖示：用 branding/icon-1024.png（無透明，App Store 規定）覆蓋 flutter create 的預設圖示，
# 每個檔案照原本的像素大小重新縮放。
ICONSET=ios/Runner/Assets.xcassets/AppIcon.appiconset
for f in "$ICONSET"/*.png; do
  px=$(sips -g pixelWidth "$f" | awk '/pixelWidth/{print $2}')
  sips -s format png -z "$px" "$px" branding/icon-1024.png --out "$f" >/dev/null
done
ls "$ICONSET"/*.png >/dev/null

# 介面語言：iOS 只會把清單內的語言交給 Flutter，少了會一律退回英文
$PB -c "Delete :CFBundleLocalizations" "$PLIST" 2>/dev/null || true
$PB -c "Add :CFBundleLocalizations array" "$PLIST"
i=0
for lang in zh-Hant zh-Hans en ja ko vi es pt-BR id th ar; do
  $PB -c "Add :CFBundleLocalizations:$i string $lang" "$PLIST"; i=$((i + 1))
done

# AdMob App ID（沒設定用 Google 官方 iOS 測試 ID；少了這個 SDK 啟動就會當掉）
set_str GADApplicationIdentifier "${ADMOB_IOS_APP_ID:-ca-app-pub-3940256099942544~1458002511}"

# 呼吸音景背景播放（audio_service）
$PB -c "Delete :UIBackgroundModes" "$PLIST" 2>/dev/null || true
$PB -c "Add :UIBackgroundModes array" "$PLIST"
$PB -c "Add :UIBackgroundModes:0 string audio" "$PLIST"

# 匯出備份檔時讓「檔案」App 看得到（file_picker／share_plus）
$PB -c "Add :UISupportsDocumentBrowser bool true" "$PLIST" 2>/dev/null || true

# 最低版本：Firebase、AdMob、RevenueCat 皆需 iOS 13 以上；取 15 以免各套件升級時再改
# （Podfile 平常在第一次建置時才產生；這裡先從 Flutter 範本複製，才能先設定平台版本）
if [ ! -f ios/Podfile ]; then
  cp "$(dirname "$(command -v flutter)")/../packages/flutter_tools/templates/cocoapods/Podfile-ios" ios/Podfile
fi
sed -i '' "s/^# *platform :ios, .*/platform :ios, '15.0'/" ios/Podfile
grep -q "^platform :ios, '15.0'" ios/Podfile
sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*;/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/' ios/Runner.xcodeproj/project.pbxproj

# 日記回顧提醒：App 在前景時也顯示通知（flutter_local_notifications 的 iOS 說明）
APPDELEGATE=ios/Runner/AppDelegate.swift
if [ -f "$APPDELEGATE" ] && ! grep -q UNUserNotificationCenter "$APPDELEGATE"; then
  perl -0pi -e 's/import UIKit\n/import UIKit\nimport UserNotifications\n/; s/(\n\s*)(return super\.application\(application, didFinishLaunchingWithOptions)/$1UNUserNotificationCenter.current().delegate = self$1$2/' "$APPDELEGATE"
  grep -q 'UNUserNotificationCenter.current().delegate = self' "$APPDELEGATE"
fi

echo "iOS 設定完成：com.lclab.tarot、App 圖示、11 種介面語言、AdMob ${ADMOB_IOS_APP_ID:+正式}${ADMOB_IOS_APP_ID:-測試} App ID、背景播放"

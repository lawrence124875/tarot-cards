#!/usr/bin/env bash
# Firebase（HANDOFF §18）：解開 Secret GOOGLE_SERVICES_JSON_BASE64 → android/app/google-services.json，
# 檢查裡面有本 App 的套件名稱，再加上 google-services 與 Crashlytics 的 Gradle 外掛與 ProGuard 規則。
#
# Firebase 專案與智慧聽覺巡航共用（帳號專案數已滿）：google-services.json 內含兩個 App 的設定，
# 外掛會依 applicationId（com.lclab.tarot）挑出本 App 那一筆。
# ⚠️ 公開 repo 的 Actions 紀錄任何人都看得到：只印套件名稱，不印檔案內容或任何金鑰。
set -euo pipefail

PKG="com.lclab.tarot"
OUT="android/app/google-services.json"

if [ -z "${GOOGLE_SERVICES_JSON_BASE64:-}" ]; then
  echo "::warning::尚未設定 Secret GOOGLE_SERVICES_JSON_BASE64，本次建置不含 Firebase（統計、當機回報、遠端開關停用）"
  echo "FIREBASE=未啟用" >> "$GITHUB_ENV"
  exit 0
fi

# PowerShell 產生的 base64 可能帶換行或空白，先去掉
if ! printf '%s' "$GOOGLE_SERVICES_JSON_BASE64" | tr -d ' \r\n\t' | base64 -d > "$OUT" 2>/dev/null; then
  echo "::error::GOOGLE_SERVICES_JSON_BASE64 不是有效的 base64，請重新產生（HANDOFF §18）"
  rm -f "$OUT"; exit 1
fi

python3 - "$OUT" "$PKG" << 'PYEOF'
import json, sys
path, pkg = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(path, encoding="utf-8-sig"))
except Exception:
    print("::error::Secret 解碼後不是 JSON（請確認轉的是 google-services.json 本身）")
    sys.exit(1)
names = sorted({c.get("client_info", {}).get("android_client_info", {}).get("package_name", "?")
                for c in data.get("client", [])})
print("google-services.json 內的套件名稱：" + "、".join(names))
if pkg not in names:
    print(f"::error::google-services.json 裡沒有 {pkg}。請在 Firebase 專案加入這個 Android App 後重新下載，再更新 Secret")
    sys.exit(1)
print(f"✓ 含 {pkg}")
PYEOF

python3 << 'PYEOF'
import re
# 1) settings.gradle.kts 宣告外掛版本（版本同智慧聽覺巡航，已在同一套 CI 驗證）
p = "android/settings.gradle.kts"
s = open(p, encoding="utf-8").read()
for line in ['id("com.google.firebase.crashlytics") version "3.0.2" apply false',
             'id("com.google.gms.google-services") version "4.4.2" apply false']:
    if line.split(")")[0] not in s:
        s = re.sub(r'(plugins\s*\{)', lambda m: m.group(1) + "\n    " + line, s, count=1)
open(p, "w", encoding="utf-8").write(s)
# 2) app/build.gradle.kts 套用外掛
p = "android/app/build.gradle.kts"
s = open(p, encoding="utf-8").read()
for line in ['id("com.google.firebase.crashlytics")', 'id("com.google.gms.google-services")']:
    if line not in s:
        s = re.sub(r'(plugins\s*\{)', lambda m: m.group(1) + "\n    " + line, s, count=1)
open(p, "w", encoding="utf-8").write(s)
PYEOF
if grep -q 'com.google.gms.google-services' android/settings.gradle.kts \
   && grep -q 'id("com.google.gms.google-services")' android/app/build.gradle.kts \
   && grep -q 'id("com.google.firebase.crashlytics")' android/app/build.gradle.kts; then
  echo "已套用 google-services 與 Crashlytics 外掛"
else
  echo "::error::Firebase Gradle 外掛設定失敗（flutter create 範本可能改了）"; exit 1
fi

# 3) R8：Firebase 以反射找各元件的建構子，沒有 keep 規則 release 版初始化會失敗（智慧聽覺巡航的教訓）。
#    proguard-rules.pro 與 proguardFiles 設定已由 patch_android.sh 建好。
PROGUARD="android/app/proguard-rules.pro"
if ! grep -q "com.google.firebase.components.ComponentRegistrar" "$PROGUARD"; then
  cat >> "$PROGUARD" << 'RULES'
-keepattributes SourceFile,LineNumberTable
-keep class com.google.firebase.** { *; }
-keep interface com.google.firebase.** { *; }
-keep class * implements com.google.firebase.components.ComponentRegistrar { <init>(); }
-dontwarn com.google.firebase.**
RULES
fi
echo "已加入 Firebase 的 ProGuard 規則"
echo "FIREBASE=已啟用" >> "$GITHUB_ENV"

#!/usr/bin/env bash
# 權限報告（見 permission_report.py）：在 flutter build 之後、於 App 根目錄執行。
# 結果只寫入 Actions summary；找不到檔案時只警告，不讓建置失敗。
set -uo pipefail
report=$(find build/app -name 'manifest-merger-release-report.txt' -print -quit 2>/dev/null)
merged=$(find build/app/intermediates -path '*/merged_manifest/release/*' -name AndroidManifest.xml -print -quit 2>/dev/null)
bin=$(ls build/app/outputs/bundle/release/app-release.aab 2>/dev/null || ls build/app/outputs/flutter-apk/app-release.apk 2>/dev/null)
if [ -z "$report" ] || [ -z "$merged" ]; then
  echo "::warning::權限報告：找不到 merged manifest 或 merger report，略過"; exit 0
fi
python3 "$(dirname "$0")/permission_report.py" "$report" "$merged" $bin | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"

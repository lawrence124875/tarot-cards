#!/usr/bin/env bash
# 把私人 repo tarot-content 的內容複製進 App 資產（只在 CI 執行）。
# ⚠️ 本 repo 公開、Actions 紀錄任何人都看得到：這裡只印數量，不印檔名或內容。
set -euo pipefail
src="${1:?用法：import_content.sh <tarot-content 路徑>}"

# 語言資料夾：新增語言時加在這裡，並同步 build_android.yml 的 sparse-checkout 與 pubspec.yaml assets。
# 每個語言：00.json–77.json（每張牌）、spreads.json、atmosphere.json、lessons.json。
LANGS="zh-Hant en zh-Hans ja ko vi es pt-BR id th ar"
summary=""
for lang in $LANGS; do
  mkdir -p "assets/content/$lang"
  n=0
  for f in "$src/$lang"/[0-9][0-9].json; do
    [ -e "$f" ] || continue
    cp "$f" "assets/content/$lang/"
    n=$((n + 1))
  done
  for f in spreads atmosphere lessons; do
    [ -e "$src/$lang/$f.json" ] && cp "$src/$lang/$f.json" "assets/content/$lang/"
  done
  summary="$summary $lang=$n"
done

# 牌面組：decks/decks.json（清單）＋ decks/<id>/deck.json 與 00.webp–77.webp（缺圖的牌面組 App 不顯示）。
mkdir -p assets/decks
decks=""
if [ -f "$src/decks/decks.json" ]; then
  cp "$src/decks/decks.json" assets/decks/
  for d in "$src"/decks/*/; do
    id=$(basename "$d")
    mkdir -p "assets/decks/$id"
    [ -f "$d/deck.json" ] && cp "$d/deck.json" "assets/decks/$id/"
    n=0
    for f in "$d"[0-9][0-9].webp "$d"back.webp; do
      [ -e "$f" ] || continue
      cp "$f" "assets/decks/$id/"
      n=$((n + 1))
    done
    decks="$decks $id=$n"
  done
fi

echo "已匯入解讀（${summary# }）、牌面組（${decks# }）"

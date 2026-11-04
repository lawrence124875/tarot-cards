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

# 雷諾曼：lenormand/<語言>/cards.json、spreads.json、lessons.json（只有 zh-Hant、zh-Hans、en），
# lenormand/deck/01.webp–36.webp、back.webp。
len=""
if [ -d "$src/lenormand" ]; then
  for lang in zh-Hant zh-Hans en; do
    mkdir -p "assets/lenormand/$lang"
    n=0
    for f in "$src/lenormand/$lang"/*.json; do
      [ -e "$f" ] || continue
      cp "$f" "assets/lenormand/$lang/"
      n=$((n + 1))
    done
    len="$len $lang=$n"
  done
  mkdir -p assets/lenormand/deck
  n=0
  for f in "$src"/lenormand/deck/[0-9][0-9].webp "$src/lenormand/deck/back.webp"; do
    [ -e "$f" ] || continue
    cp "$f" assets/lenormand/deck/
    n=$((n + 1))
  done
  len="$len deck=$n"
fi

# 交叉解讀：cross/scores.json（預設表＋overrides 合併後）、cross/<語言>/templates.json。
cross=0
if [ -f "$src/cross/scores.json" ]; then
  mkdir -p assets/cross
  cp "$src/cross/scores.json" assets/cross/
  cross=1
  for lang in zh-Hant zh-Hans en; do
    if [ -f "$src/cross/$lang/templates.json" ]; then
      mkdir -p "assets/cross/$lang"
      cp "$src/cross/$lang/templates.json" "assets/cross/$lang/"
      cross=$((cross + 1))
    fi
  done
fi

# App 圖示與牌背原圖（patch_android.sh／patch_ios.sh 會用到）。
if [ -d "$src/branding" ]; then
  rm -rf branding
  cp -r "$src/branding" branding
fi

echo "已匯入解讀（${summary# }）、牌面組（${decks# }）、雷諾曼（${len# }）、交叉 ${cross} 檔"

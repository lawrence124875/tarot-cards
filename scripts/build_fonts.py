#!/usr/bin/env python3
"""CI 用：把思源黑體／宋體（Noto Sans TC／Noto Serif TC，OFL）切成 App 用的子集。

HANDOFF §6.2、§15。完整字型每個 12–17 MB，只保留需要的字：
  1. Big5 常用字（第一字面 5,401 字）——使用者輸入「想問的事」、回顧時用得到
  2. 實際用到的字：assets/content/**/*.json（解讀內容）＋ lib/**/*.dart、lib/l10n/*.arb（介面文字）
  3. 英數、標點、全形符號
不在子集中的字（罕用字）會由系統字體自動補上，不會變成方框。

⚠️ 公開 repo 的 Actions 紀錄任何人都看得到：只印字數與檔案大小，不印字元。

用法：python3 scripts/build_fonts.py <下載的可變字型資料夾> <輸出資料夾 assets/fonts>
"""
import pathlib
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

# (來源可變字型, 字族, 字重)；輸出檔名為「字族-字重.ttf」，須與 pubspec.yaml 一致
# 程式目前沒有指定粗體：Material 按鈕與小標用 500，其餘 400；
# 若日後要粗體，Flutter 會以 400 合成（或在這裡加 700 並同步改 pubspec.yaml）。
WEIGHTS = [
    ("NotoSansTC[wght].ttf", "NotoSansTC", 400),
    ("NotoSansTC[wght].ttf", "NotoSansTC", 500),
    ("NotoSerifTC[wght].ttf", "NotoSerifTC", 400),
]
# 簡中補字（2026-10-05，HANDOFF §15）：theme.dart 以 fontFamilyFallback 接在 TC 後面，
# 只收「需要的字」中 TC 沒有的（GB2312 一級字 3,755 字＋實際用到的字），同一套思源設計，字形一致。
SC_WEIGHTS = [
    ("NotoSansSC[wght].ttf", "NotoSansSC", 400, "NotoSansTC[wght].ttf"),
    ("NotoSansSC[wght].ttf", "NotoSansSC", 500, "NotoSansTC[wght].ttf"),
    ("NotoSerifSC[wght].ttf", "NotoSerifSC", 400, "NotoSerifTC[wght].ttf"),
]

# 日文介面的主字型（2026-10-05，HANDOFF §15）：theme.dart 的 AppFonts.japanese 以 JP 為主、TC／SC 為 fallback。
# 收 JIS 第一水準漢字（2,965 字）＋假名、全形符號＋日文內容與介面實際用到的字＋英數標點。
JP_WEIGHTS = [
    ("NotoSansJP[wght].ttf", "NotoSansJP", 400),
    ("NotoSansJP[wght].ttf", "NotoSansJP", 500),
    ("NotoSerifJP[wght].ttf", "NotoSerifJP", 400),
]


def jis_level1() -> set[str]:
    """JIS X 0208 非漢字（第 1–8 區：符號、全形英數、假名）＋第一水準漢字（第 16–47 區），以 EUC-JP 解碼。"""
    out = set()
    for hi in list(range(0xA1, 0xA9)) + list(range(0xB0, 0xD0)):
        for lo in range(0xA1, 0xFF):
            try:
                out.add(bytes([hi, lo]).decode("euc_jp"))
            except UnicodeDecodeError:
                pass
    return out


def used_chars_ja(root: pathlib.Path) -> set[str]:
    chars = set()
    for pattern in ("assets/content/ja/*.json", "lib/l10n/app_ja.arb"):
        for f in root.glob(pattern):
            chars.update(f.read_text(encoding="utf-8"))
    return chars

# 韓文介面的主字型（2026-10-05，HANDOFF §15）：theme.dart 的 AppFonts.korean 以 KR 為主、TC／SC 為 fallback。
# 收 KS X 1001 非漢字（符號、相容字母）＋常用韓文音節 2,350 字＋韓文內容與介面實際用到的字（含括號內漢字）＋英數標點。
KR_WEIGHTS = [
    ("NotoSansKR[wght].ttf", "NotoSansKR", 400),
    ("NotoSansKR[wght].ttf", "NotoSansKR", 500),
    ("NotoSerifKR[wght].ttf", "NotoSerifKR", 400),
]


# 泰文介面的主字型（2026-10-06，HANDOFF §15）：theme.dart 的 AppFonts.thai 以 Noto Sans/Serif Thai 為主、TC／SC 為 fallback。
# 原檔已很小（約 0.2–0.3 MB，含泰文、拉丁字母與標點），只固定字重與寬度（wdth 100），不另做子集。
TH_WEIGHTS = [
    ("NotoSansThai[wdth,wght].ttf", "NotoSansThai", 400),
    ("NotoSansThai[wdth,wght].ttf", "NotoSansThai", 500),
    ("NotoSerifThai[wdth,wght].ttf", "NotoSerifThai", 400),
]
# 阿拉伯文介面的主字型（2026-10-07）：theme.dart 的 AppFonts.arabic 以 Noto Sans Arabic（介面）／Noto Naskh Arabic（內文）為主。
# 同泰文只固定字重、不做子集（阿拉伯字母的連寫與字形變化靠 GSUB／GPOS，保留全部字形）。
AR_WEIGHTS = [
    ("NotoSansArabic[wdth,wght].ttf", "NotoSansArabic", 400),
    ("NotoSansArabic[wdth,wght].ttf", "NotoSansArabic", 500),
    ("NotoNaskhArabic[wght].ttf", "NotoNaskhArabic", 400),
]


def ksx1001_hangul() -> set[str]:
    """KS X 1001 第 1–12 區（符號、韓文相容字母）＋第 16–40 區（韓文音節 2,350 字），以 EUC-KR 解碼。"""
    out = set()
    for hi in list(range(0xA1, 0xAD)) + list(range(0xB0, 0xC9)):
        for lo in range(0xA1, 0xFF):
            try:
                out.add(bytes([hi, lo]).decode("euc_kr"))
            except UnicodeDecodeError:
                pass
    return out


def used_chars_ko(root: pathlib.Path) -> set[str]:
    chars = set()
    for pattern in ("assets/content/ko/*.json", "lib/l10n/app_ko.arb"):
        for f in root.glob(pattern):
            chars.update(f.read_text(encoding="utf-8"))
    return chars


def gb2312_level1() -> set[str]:
    """GB2312 一級常用漢字（0xB0A1–0xD7F9）——簡中使用者輸入「想問的事」用得到。"""
    out = set()
    for hi in range(0xB0, 0xD8):
        for lo in range(0xA1, 0xFF):
            try:
                out.add(bytes([hi, lo]).decode("gb2312"))
            except UnicodeDecodeError:
                pass
    return out


def big5_common() -> set[str]:
    """Big5 第一字面常用字（0xA440–0xC67E）。"""
    out = set()
    for hi in range(0xA4, 0xC7):
        for lo in list(range(0x40, 0x7F)) + list(range(0xA1, 0xFF)):
            code = (hi << 8) | lo
            if code < 0xA440 or code > 0xC67E:
                continue
            try:
                out.add(bytes([hi, lo]).decode("big5"))
            except UnicodeDecodeError:
                pass
    return out


def used_chars(root: pathlib.Path) -> set[str]:
    chars = set()
    for pattern in ("assets/content/**/*.json", "lib/**/*.dart", "lib/**/*.arb"):
        for f in root.glob(pattern):
            chars.update(f.read_text(encoding="utf-8"))
    return chars


def main() -> None:
    src = pathlib.Path(sys.argv[1])
    out = pathlib.Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    root = pathlib.Path(__file__).resolve().parent.parent

    chars = big5_common() | used_chars(root)
    ranges = [(0x20, 0x7E), (0xA0, 0xFF), (0x2000, 0x206F), (0x3000, 0x303F), (0xFF00, 0xFFEF)]
    for a, b in ranges:
        chars.update(chr(c) for c in range(a, b + 1))
    # 越南文（2026-10-05，HANDOFF §15）：用 TC 的拉丁字形，收全部越南字母（使用者輸入「想問的事」用得到）：
    # Latin Extended-A（ă đ ĩ ũ）、ơ ư、Latin Extended Additional（ạ…ỹ）、組合附加符號（部分輸入法送分解形式）。
    for a, b in [(0x100, 0x17F), (0x1A0, 0x1B0), (0x300, 0x323), (0x1EA0, 0x1EF9)]:
        chars.update(chr(c) for c in range(a, b + 1))
    codepoints = {ord(c) for c in chars if ord(c) >= 0x20}
    print(f"子集字數：{len(codepoints)}")

    cache: dict[str, TTFont] = {}
    for fname, family, wght in WEIGHTS:
        if fname not in cache:
            cache[fname] = TTFont(src / fname)
        font = instancer.instantiateVariableFont(cache[fname], {"wght": wght}, inplace=False)
        opts = subset.Options()
        opts.layout_features = ["*"]  # 保留直排、全形標點等 OpenType 功能
        opts.name_IDs = ["*"]
        opts.notdef_outline = True
        opts.hinting = False  # 手機高解析度不需要 hinting，可再省空間
        sub = subset.Subsetter(opts)
        sub.populate(unicodes=codepoints)
        sub.subset(font)
        path = out / f"{family}-{wght}.ttf"
        font.save(path)
        print(f"{path.name}：{path.stat().st_size / 1e6:.2f} MB")

    wanted = {ord(c) for c in gb2312_level1() | used_chars(root) if ord(c) >= 0x3400}
    for fname, family, wght, tc in SC_WEIGHTS:
        if not (src / fname).exists():
            raise SystemExit(f"缺少 {fname}")
        if tc not in cache:
            cache[tc] = TTFont(src / tc)
        missing = wanted - set(cache[tc].getBestCmap())
        if fname not in cache:
            cache[fname] = TTFont(src / fname)
        font = instancer.instantiateVariableFont(cache[fname], {"wght": wght}, inplace=False)
        opts = subset.Options()
        opts.layout_features = ["*"]
        opts.name_IDs = ["*"]
        opts.notdef_outline = True
        opts.hinting = False
        sub = subset.Subsetter(opts)
        sub.populate(unicodes=missing)
        sub.subset(font)
        path = out / f"{family}-{wght}.ttf"
        font.save(path)
        print(f"{path.name}：補 {len(missing)} 字，{path.stat().st_size / 1e6:.2f} MB")

    jp = jis_level1() | used_chars_ja(root)
    jp.update(chr(c) for c in range(0x3040, 0x3100))  # 平假名、片假名全部
    subset_primary(src, out, cache, JP_WEIGHTS, jp, ranges)
    subset_primary(src, out, cache, KR_WEIGHTS, ksx1001_hangul() | used_chars_ko(root), ranges)
    instance_only(src, out, cache, TH_WEIGHTS)
    instance_only(src, out, cache, AR_WEIGHTS)


def instance_only(src, out, cache, weights) -> None:
    """泰文、阿拉伯文：整套字型只固定字重（有 wdth 軸時取 100），保留全部字形與 OpenType 功能（泰文上下標記、阿拉伯文連寫靠 GSUB／GPOS）。"""
    for fname, family, wght in weights:
        if not (src / fname).exists():
            raise SystemExit(f"缺少 {fname}")
        if fname not in cache:
            cache[fname] = TTFont(src / fname)
        axes = {a.axisTag for a in cache[fname]["fvar"].axes}
        limits = {"wght": wght, **({"wdth": 100} if "wdth" in axes else {})}
        font = instancer.instantiateVariableFont(cache[fname], limits, inplace=False)
        path = out / f"{family}-{wght}.ttf"
        font.save(path)
        print(f"{path.name}：{path.stat().st_size / 1e6:.2f} MB")


def subset_primary(src, out, cache, weights, chars: set[str], ranges) -> None:
    """日文、韓文的主字型：整組字直接子集（不是只補 TC 缺的字）。"""
    chars = set(chars)
    for a, b in ranges:
        chars.update(chr(c) for c in range(a, b + 1))
    codepoints = {ord(c) for c in chars if ord(c) >= 0x20}
    for fname, family, wght in weights:
        if not (src / fname).exists():
            raise SystemExit(f"缺少 {fname}")
        if fname not in cache:
            cache[fname] = TTFont(src / fname)
        font = instancer.instantiateVariableFont(cache[fname], {"wght": wght}, inplace=False)
        opts = subset.Options()
        opts.layout_features = ["*"]
        opts.name_IDs = ["*"]
        opts.notdef_outline = True
        opts.hinting = False
        sub = subset.Subsetter(opts)
        sub.populate(unicodes=codepoints)
        sub.subset(font)
        path = out / f"{family}-{wght}.ttf"
        font.save(path)
        print(f"{path.name}：{len(codepoints)} 字，{path.stat().st_size / 1e6:.2f} MB")


if __name__ == "__main__":
    main()

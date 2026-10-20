"""桌面圖示與牌背：由 Lawrence 提供的圖（branding/source/icon-art.jpg）產生，圖案完整保留不裁切。
執行：python3 branding/make_icon.py <牌面組資料夾…>（在 repo 根目錄；牌背輸出到各資料夾的 back.webp）。

2026-10-19 Lawrence：桌面圖與牌背要保留完整圖。只去掉原圖外圍的淺灰展示底與圓角方塊的立體邊，
金框連同框內全部圖案都保留；牌背上下多出的高度用圖片上下緣的顏色漸層延伸補滿。"""
import os
import math
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
NAVY = (23, 30, 51)  # 與 lib/shared/widgets/card_back.dart 的 kBackEdge 相同
GOLD = (214, 172, 104)
# 原圖 2048×2048：深藍圓角方塊在 x 304–1745、y 318–1744（量過），四角圓弧外是淺灰展示底
TILE = (304, 318, 1746, 1745)

src = Image.open(os.path.join(HERE, 'source', 'icon-art.jpg')).convert('RGB')
tile = np.asarray(src.crop(TILE)).astype(np.float32)
h, w, _ = tile.shape
# 金框外只有底色：圓角外的淺灰展示底與方塊邊的立體光，改成該列方塊本身的底色（取該列較暗像素的中位數）；
# 金框與框內圖案一點都不動
m = Image.new('L', (w, h), 0)
ImageDraw.Draw(m).rounded_rectangle((50, 50, w - 51, h - 51), radius=int(w * 0.15), fill=255)
# 太陽光芒在頂端中央超出金框，那一塊保留原圖
frame = np.asarray(m) > 128  # 金框以內：用來取每列底色
ImageDraw.Draw(m).rectangle((int(w * 0.3), 30, int(w * 0.7), 60), fill=255)
inside = np.asarray(m) > 128
lum = tile.mean(axis=2)
rows = [y for y in range(h) if inside[y].any()]
for y in range(h):
    yy = min(max(y, rows[0]), rows[-1])
    yy = yy if (inside[yy] & (lum[yy] < 90)).any() else rows[len(rows) // 2]  # 最上、最下幾列整列都在邊外，沿用最近一列的底色
    ok = inside[yy] & (lum[yy] < 90)
    base = np.median(tile[yy][ok], axis=0)
    tile[y, ~inside[y]] = base
# 補成正方形：上下各補幾列，沿用最上／最下一列的顏色
pad = w - h
top_pad, bot_pad = pad // 2, pad - pad // 2
sq = np.concatenate([np.repeat(tile[:1], top_pad, 0), tile, np.repeat(tile[-1:], bot_pad, 0)], 0)
art = Image.fromarray(sq.clip(0, 255).astype(np.uint8))
n = art.size[0]

# 桌面圖示（2026-10-20 Lawrence 重做的圖 branding/source/icon-2026-10-20.jpg，2000×2000、深藍底滿版）：
# 金色圓框連同框內圖案在 x 338–1709、y 331–1638（量過），以框的中心裁正方形，外圍不夠就延伸邊緣底色
ICON = Image.open(os.path.join(HERE, 'source', 'icon-2026-10-20.jpg')).convert('RGB')
CX, CY, DIAM = (338 + 1709) / 2, (331 + 1638) / 2, 1709 - 338
PAD = 600
icon_src = Image.fromarray(np.pad(np.asarray(ICON), ((PAD, PAD), (PAD, PAD), (0, 0)), mode='edge'))


def icon_crop(ratio):
    """圓框直徑佔輸出邊長 ratio 的正方形。"""
    half = DIAM / ratio / 2
    return icon_src.crop((round(CX + PAD - half), round(CY + PAD - half), round(CX + PAD + half), round(CY + PAD + half)))


res = os.path.join(HERE, 'android', 'res')
dens = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
legacy = icon_crop(0.86)
# 自適應圖示：108dp 畫布、可見範圍最小是直徑 72dp 的圓；圓框縮到 66dp，裁成圓形或圓角方形都不會切到
adaptive = icon_crop(66 / 108)
for d, k in dens.items():
    out = os.path.join(res, f'mipmap-{d}')
    legacy.resize((round(48 * k),) * 2, Image.LANCZOS).save(os.path.join(out, 'ic_launcher.png'))
    adaptive.resize((round(108 * k),) * 2, Image.LANCZOS).save(os.path.join(out, 'ic_launcher_foreground.png'))
icon_crop(0.86).resize((1024, 1024), Image.LANCZOS).save(os.path.join(HERE, 'icon-1024.png'))


def back_card():
    """牌背 720×1241（比例 0.58＝App 的 kCardAspect）：整張圖滿寬放中間，上方用圖片最上緣的顏色、
    下方用最下緣的顏色逐欄往外延伸（越靠牌邊稍暗一點），點綴與原圖同色的小星，外圍一道金色細框。"""
    W, H = 720, 1241
    a = np.asarray(art.resize((W, W), Image.LANCZOS)).astype(np.float32)
    top = (H - W) // 2
    bot = H - W - top
    # 用最外 6 列的平均當延伸色，避開單列雜點
    et, eb = a[:6].mean(axis=0), a[-6:].mean(axis=0)
    ft = (0.82 + 0.18 * np.linspace(0, 1, top))[:, None, None]
    fb = (0.82 + 0.18 * np.linspace(1, 0, bot))[:, None, None]
    out = np.concatenate([et[None] * ft, a, eb[None] * fb], 0)
    back = Image.fromarray(out.clip(0, 255).astype(np.uint8))
    d = ImageDraw.Draw(back)
    rnd = random.Random(1909)

    def star(cx, cy, r, alpha):
        col = tuple(round(NAVY[i] + (GOLD[i] - NAVY[i]) * alpha) for i in range(3))
        pts = []
        for k in range(8):
            rr = r if k % 2 == 0 else r * 0.3
            ang = k * math.pi / 4 - math.pi / 2
            pts.append((cx + rr * math.cos(ang), cy + rr * math.sin(ang)))
        d.polygon(pts, fill=col)

    for y0, y1 in ((36, top - 20), (top + W + 20, H - 36)):
        for _ in range(12):
            star(rnd.uniform(44, W - 44), rnd.uniform(y0, y1), rnd.uniform(2, 5.5), rnd.uniform(0.35, 0.85))
    # 上下各一顆較大的星，呼應圖中太陽下方的星
    star(W / 2, top / 2, 18, 0.95)
    star(W / 2, H - bot / 2, 18, 0.95)
    d.rounded_rectangle((10, 10, W - 11, H - 11), radius=22, outline=GOLD, width=3)
    return back


back = back_card()
for deck in sys.argv[1:]:
    back.save(os.path.join(deck, 'back.webp'), quality=90)
if not sys.argv[1:]:
    back.save(os.path.join(HERE, 'back-preview.png'))

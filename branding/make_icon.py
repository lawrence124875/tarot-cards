"""桌面圖示與牌背：由 Lawrence 提供的圖產生，圖案完整保留不裁切。
執行：python3 branding/make_icon.py <牌面組資料夾…>（在 repo 根目錄；牌背輸出到各資料夾的 back.webp）。"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))

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
    """牌背 720×1241（比例 0.58＝App 的 kCardAspect）：2026-10-20 Lawrence 重做的牌背圖
    （branding/source/back-2026-10-20.jpg，1600×2656）整張縮到滿寬、不裁切，上下差的幾列延伸圖片邊緣的底色。"""
    W, H = 720, 1241
    src = Image.open(os.path.join(HERE, 'source', 'back-2026-10-20.jpg')).convert('RGB')
    h = round(src.size[1] * W / src.size[0])
    a = np.asarray(src.resize((W, h), Image.LANCZOS))
    top = (H - h) // 2
    return Image.fromarray(np.pad(a, ((top, H - h - top), (0, 0), (0, 0)), mode='edge'))


back = back_card()
for deck in sys.argv[1:]:
    back.save(os.path.join(deck, 'back.webp'), quality=90)
if not sys.argv[1:]:
    back.save(os.path.join(HERE, 'back-preview.png'))

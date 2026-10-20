"""桌面圖示與牌背：由 Lawrence 提供的圖產生，圖案完整保留不裁切。
執行：python3 branding/make_icon.py <牌面組資料夾…>（在 repo 根目錄；牌背輸出到各資料夾的 back.webp）。"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))

# 桌面圖示（2026-10-20 Lawrence 選的圖 branding/source/icon-2026-10-20b.jpg，2000×2000）：
# 原圖是淺灰底上一塊帶陰影的深藍圓角方塊，方塊在 x 302–1745、y 303–1744（量過）。
# 只取方塊，圓角外與立體邊改成該列方塊本身的底色，方塊內圖案一點都不動。
ICON = Image.open(os.path.join(HERE, 'source', 'icon-2026-10-20b.jpg')).convert('RGB')
TX0, TY0 = 302, 303
tile = np.asarray(ICON.crop((TX0, TY0, 1746, 1745))).astype(np.float32)
th, tw, _ = tile.shape
# 方塊底色是上淺下深的漸層：取方塊左右內側（避開圖案）的每列中位數、平滑後當底色，
# 再用羽化遮罩把圓角外與立體邊換成這個底色，接縫看不出來
cols = np.concatenate([tile[:, 110:180], tile[:, tw - 180:tw - 110]], axis=1)
bg = np.median(cols, axis=1)
bg[:90], bg[th - 75:] = bg[90], bg[th - 76]  # 外圈是灰底與立體邊，沿用最近的內側底色
k = np.ones(61) / 61
bg = np.stack([np.convolve(np.pad(bg[:, c], 30, mode='edge'), k, mode='valid') for c in range(3)], axis=1)
m = Image.new('L', (tw, th), 0)
ImageDraw.Draw(m).rounded_rectangle((85, 85, tw - 86, th - 86), radius=int(tw * 0.15), fill=255)
# 太陽光芒在頂端中央離邊較近，那一塊保留原圖
ImageDraw.Draw(m).rectangle((int(tw * 0.38), 45, int(tw * 0.62), 120), fill=255)
w = (np.asarray(m.filter(ImageFilter.GaussianBlur(12))) / 255.0)[:, :, None]
tile = tile * w + bg[:, None, :] * (1 - w)
tile = tile.clip(0, 255).astype(np.uint8)
# 圖案（太陽到無限符號、麥穗）在原圖 x 444–1594、y 359–1626，中心 (1019, 992)；離中心最遠的實心圖案約 750px
CX, CY, REACH = 1019 - TX0, 992 - TY0, 750
PAD = 800
icon_src = Image.fromarray(np.pad(tile, ((PAD, PAD), (PAD, PAD), (0, 0)), mode='edge'))


def icon_crop(side):
    """以圖案中心裁邊長 side（原圖像素）的正方形，超出方塊的部分延伸邊緣底色。"""
    x, y = CX + PAD - side / 2, CY + PAD - side / 2
    return icon_src.crop((round(x), round(y), round(x + side), round(y + side)))


res = os.path.join(HERE, 'android', 'res')
dens = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
legacy = icon_crop(tw)
# 自適應圖示：108dp 畫布、可見範圍最小是直徑 72dp 的圓；圖案縮到直徑 66dp 的圓內，裁成圓形或圓角方形都不會切到
adaptive = icon_crop(REACH * 2 * 108 / 66)
for d, k in dens.items():
    out = os.path.join(res, f'mipmap-{d}')
    legacy.resize((round(48 * k),) * 2, Image.LANCZOS).save(os.path.join(out, 'ic_launcher.png'))
    adaptive.resize((round(108 * k),) * 2, Image.LANCZOS).save(os.path.join(out, 'ic_launcher_foreground.png'))
icon_crop(tw).resize((1024, 1024), Image.LANCZOS).save(os.path.join(HERE, 'icon-1024.png'))


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

"""桌面圖示與牌背：由 Lawrence 提供的圖（branding/source/icon-art.jpg）裁切產生。
執行：python3 branding/make_icon.py <牌面組資料夾…>（在 repo 根目錄；牌背輸出到各資料夾的 back.webp）。"""
import os
import sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
NAVY = (23, 30, 51)
GOLD = (214, 172, 104)
# 原圖 2048×2048：深藍圓角方塊約在 (303,319)–(1745,1744)；金框內約內縮 75px（取 80px，邊緣 90px 漸淡）
TILE = (306, 312, 1742, 1748)
INSET = 80

src = Image.open(os.path.join(HERE, 'source', 'icon-art.jpg')).convert('RGB')
tile = src.crop(TILE)
n = tile.size[0]
# 圓角外的淺灰底改成深藍，成為完整方形
mask = Image.new('L', tile.size, 0)
ImageDraw.Draw(mask).rounded_rectangle((3, 3, n - 4, n - 4), radius=int(n * 0.13), fill=255)
square = Image.new('RGB', tile.size, NAVY)
square.paste(tile, (0, 0), mask)
inner = tile.crop((INSET, INSET, n - INSET, n - INSET))
# 邊緣 90px 漸淡到深藍，貼到任何深藍底上都不會看到方框
m = inner.size[0]
fade = Image.new('L', inner.size, 0)
fd = ImageDraw.Draw(fade)
for i in range(90):
    fd.rectangle((i, i, m - 1 - i, m - 1 - i), outline=round(255 * (i + 1) / 90))
fd.rectangle((90, 90, m - 91, m - 91), fill=255)
art = Image.new('RGB', inner.size, NAVY)
art.paste(inner, (0, 0), fade)
inner = art
# 桌面方形圖示：深藍底、金色細框，中央是圖
square = Image.new('RGB', (n, n), NAVY)
sd = ImageDraw.Draw(square)
sd.rounded_rectangle((60, 60, n - 61, n - 61), radius=110, outline=GOLD, width=10)
square.paste(inner.resize((n - 200,) * 2, Image.LANCZOS), (100, 100))

res = os.path.join(HERE, 'android', 'res')
dens = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
for d, k in dens.items():
    out = os.path.join(res, f'mipmap-{d}')
    square.resize((round(48 * k),) * 2, Image.LANCZOS).save(os.path.join(out, 'ic_launcher.png'))
    # 自適應圖示：108dp 畫布，金框內的圖放在中央 66dp 安全區
    fg = Image.new('RGBA', (round(108 * k),) * 2, NAVY + (255,))
    s = round(70 * k)
    fg.paste(inner.resize((s, s), Image.LANCZOS), ((fg.size[0] - s) // 2,) * 2)
    fg.save(os.path.join(out, 'ic_launcher_foreground.png'))
square.resize((1024, 1024), Image.LANCZOS).save(os.path.join(HERE, 'icon-1024.png'))

# 牌背 720×1252：深藍底、雙金框，中央放金框內的圖
for deck in sys.argv[1:]:
    W, H = 720, 1252
    back = Image.new('RGB', (W, H), NAVY)
    d = ImageDraw.Draw(back)
    d.rounded_rectangle((18, 18, W - 19, H - 19), radius=28, outline=GOLD, width=4)
    d.rounded_rectangle((34, 34, W - 35, H - 35), radius=20, outline=GOLD, width=1)
    s = 600
    back.paste(inner.resize((s, s), Image.LANCZOS), ((W - s) // 2, (H - s) // 2))
    back.save(os.path.join(deck, 'back.webp'), quality=88)

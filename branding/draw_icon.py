"""桌面圖示與通知小圖示：暮光紫底上一張金色細框的牌，牌中央一輪太陽、上方一顆小星。
象徵「光、豐盛、療癒、喜悅」。執行：python3 branding/draw_icon.py（在 repo 根目錄）。"""
import math
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
TWILIGHT = (0x4A, 0x3E, 0x73); GOLD = (0xF3, 0xC6, 0x6E); RICE = (0xE0, 0x78, 0x4C)
SCALE = 0.66  # 牌高 ÷ 可見範圍


def star(d, cx, cy, r, col):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.42
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts, fill=col)


def card(d, cx, cy, h, col=GOLD, sun=GOLD, inner=RICE):
    w = h * 0.62; lw = max(1, h * 0.035)
    d.rounded_rectangle((cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2), radius=h * 0.07, outline=col, width=int(lw))
    # 太陽：圓＋十二道光芒
    sy = cy + h * 0.06; sr = w * 0.2
    for i in range(12):
        a = i * math.pi / 6
        r1, r2 = sr * 1.35, sr * (1.85 if i % 2 == 0 else 1.6)
        d.line((cx + r1 * math.cos(a), sy + r1 * math.sin(a), cx + r2 * math.cos(a), sy + r2 * math.sin(a)),
               fill=sun, width=int(lw * 0.9))
    d.ellipse((cx - sr, sy - sr, cx + sr, sy + sr), fill=inner)
    star(d, cx, cy - h * 0.3, w * 0.1, sun)


def foreground(S):
    """自適應圖示前景（108dp 畫布，可見範圍約中央 72dp），透明底。"""
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    card(ImageDraw.Draw(im), S / 2, S / 2, S * (72 / 108) * SCALE)
    return im


def legacy(S):
    """傳統圖示與上架大圖：圓角方形暮光紫底＋牌。"""
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, S - 1, S - 1), radius=S * 0.22, fill=TWILIGHT)
    card(d, S / 2, S / 2, S * SCALE)
    return im


def status(S):
    """通知小圖示（Android 只看透明度）：白色單色。"""
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    w = (255, 255, 255, 255)
    card(ImageDraw.Draw(im), S / 2, S / 2, S * 0.9, col=w, sun=w, inner=w)
    return im


def hi(fn, px):
    return fn(px * 4).resize((px, px), Image.LANCZOS)


res = os.path.join(HERE, 'android', 'res')
for dens, fg_px, lg_px, st_px in [('mdpi', 108, 48, 24), ('hdpi', 162, 72, 36), ('xhdpi', 216, 96, 48),
                                  ('xxhdpi', 324, 144, 72), ('xxxhdpi', 432, 192, 96)]:
    hi(foreground, fg_px).save(os.path.join(res, f'mipmap-{dens}', 'ic_launcher_foreground.png'))
    hi(legacy, lg_px).save(os.path.join(res, f'mipmap-{dens}', 'ic_launcher.png'))
    os.makedirs(os.path.join(res, f'drawable-{dens}'), exist_ok=True)
    hi(status, st_px).save(os.path.join(res, f'drawable-{dens}', 'ic_stat_tarot.png'))
hi(legacy, 1024).save(os.path.join(HERE, 'icon-1024.png'))
print('done')

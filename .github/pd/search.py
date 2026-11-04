"""暫時用：下載三套 BnF（Commons 公有領域）雷諾曼牌組縮圖，做成索引圖供挑選。"""
import io, json, os, re, time, urllib.request, urllib.parse, urllib.error
from PIL import Image, ImageDraw

API = "https://commons.wikimedia.org/w/api.php?"
UA = {"User-Agent": "AuraSpicaTarotBot/1.0 (https://github.com/lawrence124875/tarot-cards; research)"}
def fetch(url, raw=False):
    for attempt in range(6):
        time.sleep(1.5)
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
                return r.read() if raw else json.load(r)
        except urllib.error.HTTPError as e:
            if e.code != 429: raise
            time.sleep(int(e.headers.get("Retry-After") or 20) + 5 * attempt)

DECKS = {"A_petit_1895": "btv1b10529584r", "B_petit_1875": "btv1b10522499m", "C_wahrsage_1875": "btv1b105433047"}
os.makedirs("out", exist_ok=True)
summary = []
for name, bid in DECKS.items():
    files, cont = [], {}
    for _ in range(5):
        d = fetch(API + urllib.parse.urlencode({"action": "query", "generator": "search", "gsrsearch": f'intitle:"{bid}"', "gsrnamespace": 6, "gsrlimit": 50,
              "prop": "imageinfo", "iiprop": "url", "iiurlwidth": 220, "format": "json", **cont}))
        for pg in d.get("query", {}).get("pages", {}).values():
            m = re.search(r"\((\d+) of (\d+)\)", pg["title"])
            if m: files.append((int(m.group(1)), pg["title"], pg["imageinfo"][0]["thumburl"], pg["imageinfo"][0]["url"]))
        if "gsroffset" not in d.get("continue", {}): break
        cont = {"gsroffset": d["continue"]["gsroffset"], "continue": d["continue"].get("continue", "")}
    files.sort()
    json.dump(files, open(f"out/{name}.json", "w"), ensure_ascii=False, indent=0)
    cols, tw, th = 10, 110, 170
    rows = (len(files) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * tw, rows * (th + 16)), "white")
    dr = ImageDraw.Draw(sheet)
    for k, (n, t, thumb, full) in enumerate(files):
        try:
            im = Image.open(io.BytesIO(fetch(thumb, raw=True))).convert("RGB")
            im.thumbnail((tw - 6, th - 6))
            x, y = (k % cols) * tw, (k // cols) * (th + 16)
            sheet.paste(im, (x + 3, y + 3)); dr.text((x + 4, y + th), str(n), fill="black")
        except Exception as e:
            pass
    sheet.save(f"out/{name}.jpg", quality=80)
    summary.append(f"- {name} {bid}: {len(files)} files")
open(os.environ["GITHUB_STEP_SUMMARY"], "a").write("\n".join(summary) + "\n")
print("\n".join(summary))

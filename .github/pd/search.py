"""暫時用：統計 Commons 上雷諾曼牌組的檔案數、授權與來源，只輸出摘要。"""
import json, os, re, urllib.request, urllib.parse
from collections import defaultdict

API = "https://commons.wikimedia.org/w/api.php?"
def get(params):
    req = urllib.request.Request(API + urllib.parse.urlencode(params), headers={"User-Agent": "tarot-pd-search/1.0 (github actions)"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)

out = []
def p(s): out.append(s); print(s)

groups = defaultdict(list)
for q in ['"Petit Lenormand"', '"Wahrsagekarten des Kartenschlägerin"', '"Jeu divinatoire de Marie-Anne Le Normand"', 'Lenormand Wahrsage', 'Lenormand cartomancie jeu']:
    cont = {}
    for _page in range(10):
        d = get({"action": "query", "generator": "search", "gsrsearch": q, "gsrnamespace": 6, "gsrlimit": 50,
                 "prop": "imageinfo", "iiprop": "extmetadata|size", "iiextmetadatafilter": "LicenseShortName|Credit|DateTimeOriginal|ImageDescription",
                 "format": "json", **cont})
        for pg in d.get("query", {}).get("pages", {}).values():
            t = pg["title"][5:]
            key = re.sub(r"[\s\-_(]*\(?\d+( of \d+)?\)?\.\w+$", "", t)
            key = re.sub(r"\s*\d+\s*$", "", key)[:90]
            ii = (pg.get("imageinfo") or [{}])[0]; m = ii.get("extmetadata", {})
            groups[key].append((t, m.get("LicenseShortName", {}).get("value", ""), re.sub("<[^>]+>", "", m.get("Credit", {}).get("value", ""))[:120],
                                re.sub("<[^>]+>", "", m.get("DateTimeOriginal", {}).get("value", ""))[:40], ii.get("width"), ii.get("height")))
        if "gsroffset" not in d.get("continue", {}): break
        cont = {"gsroffset": d["continue"]["gsroffset"], "continue": d["continue"].get("continue", "")}

for k, v in sorted(groups.items(), key=lambda x: -len(x[1])):
    if len(v) < 3 and "Lenormand" not in k and "Normand" not in k: continue
    lic = sorted({x[1] for x in v}); cred = sorted({x[2] for x in v})[:2]; dates = sorted({x[3] for x in v})[:2]
    sizes = sorted({f"{x[4]}x{x[5]}" for x in v})[:3]
    p(f"- [{len(v)}] {k} | lic={lic} | date={dates} | size={sizes} | credit={cred}")
    p("    e.g. " + " ; ".join(x[0] for x in v[:3]))

with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as f: f.write("\n".join(out) + "\n")

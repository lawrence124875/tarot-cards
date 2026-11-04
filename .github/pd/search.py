"""暫時用：搜尋公有領域雷諾曼牌圖來源，只輸出摘要到 Actions summary。"""
import json, os, urllib.request, urllib.parse

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "tarot-pd-search/1.0"})
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.load(r)

out = []
def p(s): out.append(s); print(s)

p("## Wellcome")
try:
    d = get("https://api.wellcomecollection.org/catalogue/v2/works?query=lenormand&pageSize=50&include=items")
    for w in d["results"]:
        lic = set(); man = ""
        for it in w.get("items", []):
            for loc in it.get("locations", []):
                if loc.get("license"): lic.add(loc["license"]["id"])
                if "iiif" in loc.get("url", "") and "presentation" in loc.get("url", ""): man = loc["url"]
        n = ""
        if man:
            try:
                m = get(man); n = len(m.get("items", m.get("sequences", [{}])[0].get("canvases", [])))
            except Exception as e: n = f"err {e}"
        p(f"- {w['id']} | {w['title'][:80]} | {w.get('physicalDescription','')[:60]} | lic={','.join(lic)} | canvases={n} | {man}")
except Exception as e: p(f"err {e}")

p("## Met")
try:
    d = get("https://collectionapi.metmuseum.org/public/collection/v1/search?hasImages=true&q=lenormand")
    for oid in (d.get("objectIDs") or [])[:30]:
        o = get(f"https://collectionapi.metmuseum.org/public/collection/v1/objects/{oid}")
        p(f"- {oid} | {o['title'][:70]} | {o.get('objectDate')} | PD={o.get('isPublicDomain')} | extra={len(o.get('additionalImages',[]))}")
except Exception as e: p(f"err {e}")

p("## Commons")
api = "https://commons.wikimedia.org/w/api.php?"
try:
    for q in ["Lenormand cards", "Lenormand Wahrsagekarten", "Petit Lenormand", "Spiel der Hoffnung Hechtel", "Lenormand Dondorf"]:
        d = get(api + urllib.parse.urlencode({"action": "query", "list": "search", "srsearch": q, "srnamespace": 6, "srlimit": 50, "format": "json"}))
        p(f"- '{q}': {d['query']['searchinfo']['totalhits']} hits; " + " / ".join(x['title'][5:60] for x in d['query']['search'][:15]))
    d = get(api + urllib.parse.urlencode({"action": "query", "list": "categorymembers", "cmtitle": "Category:Lenormand cards", "cmlimit": 200, "format": "json"}))
    p("- Category:Lenormand cards: " + " / ".join(x['title'] for x in d['query']['categorymembers']))
    d = get(api + urllib.parse.urlencode({"action": "query", "list": "categorymembers", "cmtitle": "Category:Grand Jeu de Lenormand", "cmlimit": 200, "format": "json"}))
    p(f"- Grand Jeu: {len(d['query']['categorymembers'])} members")
except Exception as e: p(f"err {e}")

p("## Internet Archive")
try:
    d = get("https://archive.org/advancedsearch.php?" + urllib.parse.urlencode({"q": "lenormand AND (cards OR karten OR cartes)", "fl[]": ["identifier", "title", "date", "licenseurl", "mediatype"], "rows": 40, "output": "json"}, doseq=True))
    for x in d["response"]["docs"]:
        p(f"- {x['identifier']} | {str(x.get('title'))[:70]} | {x.get('date','')} | {x.get('mediatype')} | {x.get('licenseurl','')}")
except Exception as e: p(f"err {e}")

p("## LoC")
try:
    d = get("https://www.loc.gov/pictures/search/?q=lenormand&fo=json")
    for x in d.get("results", [])[:20]: p(f"- {x.get('title','')[:80]} | {x.get('links',{}).get('item')}")
    d = get("https://www.loc.gov/search/?q=lenormand+fortune+cards&fo=json&c=30")
    for x in d.get("results", [])[:20]: p(f"- {str(x.get('title',''))[:80]} | {x.get('date')} | {x.get('url')}")
except Exception as e: p(f"err {e}")

with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as f: f.write("\n".join(out) + "\n")

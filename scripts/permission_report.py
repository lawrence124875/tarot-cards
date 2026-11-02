#!/usr/bin/env python3
"""權限報告：讀 merged manifest 與 manifest-merger report，列出每個權限與來源 SDK、targetSdk／minSdk。
輸出 Markdown（給 $GITHUB_STEP_SUMMARY）與 ::notice::。只印權限與套件名稱，不印任何金鑰。
用法：python3 scripts/permission_report.py <merger-report.txt> <merged AndroidManifest.xml> [aab/apk]
通常由 scripts/permission_report.sh 呼叫。升 targetSdk（例如 37）前後都要跑一次。"""
import os, re, sys
report, merged, aab = sys.argv[1], sys.argv[2], (sys.argv[3] if len(sys.argv) > 3 else '')
A = '{http://schemas.android.com/apk/res/android}'
import xml.etree.ElementTree as ET
root = ET.parse(merged).getroot()
sdk = root.find('uses-sdk')
print('## 基本資料')
print(f"- minSdk: {sdk.get(A+'minSdkVersion') if sdk is not None else '?'} / targetSdk: {sdk.get(A+'targetSdkVersion') if sdk is not None else '?'}")
if aab and os.path.exists(aab):
    print(f"- {os.path.basename(aab)}: {os.path.getsize(aab)/1e6:.1f} MB")
# 來源：merger report 中 uses-permission#X 之後的 ADDED from / MERGED from 行
src = {}
cur = None
for line in open(report, encoding='utf-8', errors='replace'):
    m = re.match(r'uses-permission(?:-sdk-23)?#(\S+)', line)
    if m:
        cur = m.group(1); src.setdefault(cur, set()); continue
    if cur and re.match(r'\S', line) and not line.startswith(('ADDED', 'MERGED', 'INJECTED')):
        cur = None
    if cur:
        m2 = re.search(r'(?:ADDED|MERGED) from (\S+)', line)
        if m2:
            p = m2.group(1)
            g = re.search(r'\[([^\]]+)\]', p)
            if g: name = g.group(1)
            elif 'src/main/AndroidManifest' in p and '/app/' in p: name = 'App 本身（patch_android.sh）'
            else:
                g = re.search(r'/([^/]+)/(?:intermediates|src)/', p)
                name = ('Flutter 外掛 ' + g.group(1)) if g else p.split('/')[-1]
            src[cur].add(name)
print('\n## merged manifest 權限')
perms = []
for e in root.iter():
    if e.tag in ('uses-permission', 'uses-permission-sdk-23'):
        n = e.get(A+'name'); mx = e.get(A+'maxSdkVersion')
        perms.append(n)
        s = '、'.join(sorted(src.get(n, []))) or '?'
        print(f"- {n}{' (maxSdk '+mx+')' if mx else ''} ← {s}")
        print(f"::notice::PERM {n}{' max'+mx if mx else ''} <- {s}", file=sys.stderr)
watch = ['ACCESS_FINE_LOCATION','ACCESS_COARSE_LOCATION','ACCESS_BACKGROUND_LOCATION','READ_CONTACTS','WRITE_CONTACTS','GET_ACCOUNTS',
         'NEARBY_WIFI_DEVICES','ACCESS_LOCAL_NETWORK','READ_CALL_LOG','WRITE_CALL_LOG','READ_SMS','RECEIVE_SMS','SEND_SMS',
         'MANAGE_EXTERNAL_STORAGE','READ_EXTERNAL_STORAGE','WRITE_EXTERNAL_STORAGE','READ_MEDIA_IMAGES','READ_MEDIA_VIDEO','QUERY_ALL_PACKAGES',
         'SCHEDULE_EXACT_ALARM','USE_EXACT_ALARM','FOREGROUND_SERVICE_MEDIA_PLAYBACK']
print('\n## 政策關注權限')
for w in watch:
    hit = [p for p in perms if p.endswith('.'+w)]
    print(f"- {w}: {'有 ← ' + '、'.join(sorted(src.get(hit[0], []))) if hit else '無'}")
svc = [e.get(A+'permission') for e in root.iter('service') if e.get(A+'permission')]
acc = [p for p in svc if 'ACCESSIBILITY' in p]
print(f"- BIND_ACCESSIBILITY_SERVICE（服務）: {'有' if acc else '無'}")
print(f"::notice::SDK target={sdk.get(A+'targetSdkVersion') if sdk is not None else '?'} min={sdk.get(A+'minSdkVersion') if sdk is not None else '?'} accessibility={'yes' if acc else 'no'} perms={len(perms)}", file=sys.stderr)
if not perms: sys.exit('::error::權限清單是空的，manifest 路徑可能不對')

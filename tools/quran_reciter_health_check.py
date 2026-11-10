#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Health-check: Quran.com recitations + attractive mp3quran reciters."""
import json, urllib.request, sys
UA={'User-Agent':'Mozilla/5.0'}
def get(url):
    import ssl
    ctx=ssl._create_unverified_context()
    req=urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=15) as r:
        return r.status, r.read()
# Quran.com recitations
try:
    s,body=get('https://api.quran.com/api/v4/resources/recitations?language=ar')
    data=json.loads(body)
    print(f"Quran.com recitations: {len(data.get('recitations',[]))}")
    for rec in data.get('recitations',[])[:5]:
        print(rec['id'], rec['reciter_name'], rec.get('style'))
    # check segments for first reciter
    rid=data['recitations'][0]['id']
    s2,b2=get(f'https://api.quran.com/api/v4/quran/recitations/{rid}/by_ayah/2:255?segments=true')
    j=json.loads(b2)
    print("segments sample keys:", list(j.keys())[:5])
    af=j.get('audio_file') or {}
    print("segments count:", len(af.get('segments') or []))
except Exception as e:
    print("Quran.com fail:", e)

# mp3quran attractive
import time
for name, qid in [('Nasser Alqatami','ar.nasser'),('Yasser','ar.yasser_aldosari'),('Haitham','ar.haitham_aldokhin')]:
    try:
        from urllib.parse import quote
        url=f'https://cdn.islamic.network/quran/audio/128/{qid}/262.mp3'
        req=urllib.request.Request(url, headers=UA, method='HEAD')
        with urllib.request.urlopen(req, timeout=10) as r:
            print(f"{name} islamic.network HEAD {r.status} len={r.headers.get('Content-Length')}")
    except Exception as e:
        print(f"{name} fail:", e)

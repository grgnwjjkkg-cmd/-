#!/usr/bin/env python3
"""Poly Haven（CC0）の実写スキャン素材をダウンロードする。
使い方: python3 tools/fetch_polyhaven.py
  models  → Game/assets/ph/<id>/<id>.gltf（＋bin・画像）
  textures→ Game/assets/tex/<id>_{diff,nor,rough}.jpg
  hdris   → Game/assets/hdri/<id>.hdr
"""
import json, os, urllib.request

UA = {'User-Agent': 'kemet-asset-fetch/1.0'}

ROOT = os.path.join(os.path.dirname(__file__), '..', 'Game', 'assets')
MODELS = ['sand_rocks_small_01', 'stone_01', 'namaqualand_boulder_02', 'namaqualand_rocks_01', 'rock_face_01',
          'treasure_chest', 'ceramic_vase_02', 'ceramic_vase_03', 'wooden_crate_01', 'moon_rock_03']
TEXTURES = ['aerial_sand', 'rock_wall_07']
HDRIS = ['goegap']

def get(url, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path): return
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA)) as r, open(path, 'wb') as o: o.write(r.read())

def api(kind, id):
    with urllib.request.urlopen(urllib.request.Request(f'https://api.polyhaven.com/{kind}/{id}', headers=UA)) as r: return json.load(r)

for m in MODELS:
    f = api('files', m)['gltf']['1k']['gltf']
    base = os.path.join(ROOT, 'ph', m)
    get(f['url'], os.path.join(base, f"{m}.gltf"))
    for rel, inc in f.get('include', {}).items():
        get(inc['url'], os.path.join(base, rel))
    print('model', m)
for t in TEXTURES:
    f = api('files', t)
    for k, n in [('Diffuse', 'diff'), ('nor_gl', 'nor'), ('Rough', 'rough')]:
        get(f[k]['2k']['jpg']['url'], os.path.join(ROOT, 'tex', f'{t}_{n}.jpg'))
    print('texture', t)
for h in HDRIS:
    get(api('files', h)['hdri']['2k']['hdr']['url'], os.path.join(ROOT, 'hdri', f'{h}.hdr'))
    print('hdri', h)

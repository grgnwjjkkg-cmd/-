#!/usr/bin/env python3
"""Poly Haven（CC0）の実写スキャン素材をダウンロードする。
使い方: python3 tools/fetch_polyhaven.py
  models  → Game/assets/ph/<id>/<id>.gltf（＋bin・画像）
  textures→ Game/assets/tex/<id>_{diff,nor,rough}.jpg
  hdris   → Game/assets/hdri/<id>.hdr
"""
import json, os, sys, urllib.request

UA = {'User-Agent': 'kemet-asset-fetch/1.0'}

ROOT = os.path.join(os.path.dirname(__file__), '..', 'Game', 'assets')
MODELS = ['sand_rocks_small_01', 'stone_01', 'namaqualand_boulder_02', 'namaqualand_rocks_01', 'rock_face_01',
          'treasure_chest', 'ceramic_vase_02', 'ceramic_vase_03', 'wooden_crate_01', 'moon_rock_03']
TEXTURES = ['large_sandstone_blocks_01', 'sandstone_blocks_08', 'red_sandstone_pavement', 'aerial_sand', 'rock_wall_07', 'rock_face_02', 'coast_sand_01', 'clay_plaster', 'beige_wall_001', 'brown_planks_09', 'granite_wall', 'cliff_side']
HDRIS = ['goegap']

def get(url, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path): return
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA)) as r, open(path, 'wb') as o: o.write(r.read())

def api(kind, id):
    with urllib.request.urlopen(urllib.request.Request(f'https://api.polyhaven.com/{kind}/{id}', headers=UA)) as r: return json.load(r)

ONLY = sys.argv[1:]  # 例: textures hdris
for m in (MODELS if not ONLY or 'models' in ONLY else []):
    f = api('files', m)['gltf']['1k']['gltf']
    base = os.path.join(ROOT, 'ph', m)
    get(f['url'], os.path.join(base, f"{m}.gltf"))
    for rel, inc in f.get('include', {}).items():
        get(inc['url'], os.path.join(base, rel))
    print('model', m)
for t in (TEXTURES if not ONLY or 'textures' in ONLY else []):
    f = api('files', t)
    for k, n in [('Diffuse', 'diff'), ('nor_gl', 'nor'), ('Rough', 'rough')]:
        get(f[k]['2k']['jpg']['url'], os.path.join(ROOT, 'tex', f'{t}_{n}.jpg'))
    print('texture', t)
for h in (HDRIS if not ONLY or 'hdris' in ONLY else []):
    get(api('files', h)['hdri']['2k']['hdr']['url'], os.path.join(ROOT, 'hdri', f'{h}.hdr'))
    print('hdri', h)

#!/usr/bin/env python3
"""ベイクしたライトマップ（PNG）を JPEG にして軽くし、meta.json を書き換える。
使い方: python3 tools/bake/compress.py Game/assets/levels/necropolis [quality]
"""
import json, os, sys
from PIL import Image

d = sys.argv[1]
q = int(sys.argv[2]) if len(sys.argv) > 2 else 92
meta_path = os.path.join(d, 'meta.json')
meta = json.load(open(meta_path))
for g, info in meta['groups'].items():
    src = os.path.join(d, info['lightmap'])
    if not src.endswith('.png') or not os.path.exists(src):
        continue
    dst = src[:-4] + '.jpg'
    Image.open(src).convert('RGB').save(dst, quality=q, subsampling=0)
    os.remove(src)
    info['lightmap'] = os.path.basename(dst)
    print(g, os.path.getsize(dst) // 1024, 'KB')
json.dump(meta, open(meta_path, 'w'), ensure_ascii=False)

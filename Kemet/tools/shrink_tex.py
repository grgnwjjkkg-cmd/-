#!/usr/bin/env python3
"""アプリを軽くするため、実写テクスチャを縮める（見た目はほぼ同じ）。
模様（_diff）は 2048px・画質82、凹凸（_nor）とざらつき（_rough）は光の計算にしか使わないので 1024px。
使い方（Kemet/ で）: python3 tools/shrink_tex.py
"""
import os
from PIL import Image
D = os.path.join(os.path.dirname(__file__), '..', 'Game', 'assets', 'tex')
before = after = 0
for f in sorted(os.listdir(D)):
    if not f.endswith('.jpg'): continue
    p = os.path.join(D, f); before += os.path.getsize(p)
    im = Image.open(p)
    size, q = (2048, 82) if f.endswith('_diff.jpg') else (1024, 85)
    if im.width > size: im = im.resize((size, size * im.height // im.width), Image.LANCZOS)
    im.convert('RGB').save(p, quality=q, optimize=True)
    after += os.path.getsize(p)
print(f'{before // 1024 // 1024}MB -> {after // 1024 // 1024}MB')

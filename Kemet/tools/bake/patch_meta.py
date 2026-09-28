#!/usr/bin/env python3
"""光を計算し直さずに、meta.json の出入口・出てくる場所だけを台本（tools/bake/<地図>.py）と同じにする。
使い方（Kemet/ で）: python3 tools/bake/patch_meta.py necropolis
"""
import ast, json, os, sys
name = sys.argv[1]
src = open(f'tools/bake/{name}.py').read()
path = f'Game/assets/levels/{name}/meta.json'
meta = json.load(open(path))
import math
for node in ast.parse(src).body:
    if isinstance(node, ast.Assign) and isinstance(node.targets[0], ast.Subscript):
        t = node.targets[0]
        if getattr(t.value, 'id', '') == 'M' and isinstance(t.slice, ast.Constant) and t.slice.value in ('exits', 'spawns'):
            meta[t.slice.value] = eval(compile(ast.Expression(node.value), name, 'eval'), {'math': math})
json.dump(meta, open(path, 'w'), ensure_ascii=False)
print('patched', path, meta['exits'], list(meta['spawns']))

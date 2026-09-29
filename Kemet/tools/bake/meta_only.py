"""光を計算し直さずに、台本（tools/bake/<地図>.py）から meta.json の遊びの情報（当たり判定・足場・出入口など）だけを作り直す。
ライトマップの情報（groups）は今のものをそのまま使う。
使い方（Kemet/ で）: blender -b --python tools/bake/meta_only.py -- <地図>
"""
import sys, os, json
sys.path.insert(0, os.path.dirname(__file__))
import lib
name = sys.argv[sys.argv.index('--') + 1]
path = os.path.join(os.path.dirname(__file__), f'{name}.py')


def write_meta(self):
    old = json.load(open(os.path.join(self.out, 'meta.json')))
    self.meta['groups'] = old['groups']
    json.dump(self.meta, open(os.path.join(self.out, 'meta.json'), 'w'), ensure_ascii=False)
    print('meta written', self.out, len(self.meta['colliders']['boxes']), 'boxes', len(self.meta.get('platforms', [])), 'platforms', flush=True)


lib.Level.bake_and_export = write_meta
sys.argv = [sys.argv[0], '--python', path, '--', '16']
exec(open(path).read(), {'__name__': '__main__', '__file__': path})

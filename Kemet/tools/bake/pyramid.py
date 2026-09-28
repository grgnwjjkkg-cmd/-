"""大ピラミッドの中：盗掘者の穴 → 分かれ道 → 上り通路 → 大回廊（高さ17m、段々にせまくなる天井）→ 前室（封印の扉）→ 王の間。
わき道：女王の間（切妻の天井）とその奥の隠し部屋、地下の未完成の間。
遊び方：石板を3つ見つける → 封印が開く → 王の間の秘宝を取る → 崩れる前に外へ脱出。
使い方（Kemet/ で）:
  blender -b --python tools/bake/pyramid.py -- [samples]
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from lib import Level, B

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
SAMPLES = int(argv[0]) if argv else 160
random.seed(21)
L = Level('pyramid', SAMPLES)

L.material('lime', 'sandstone_blocks_08', (1.0, 0.93, 0.8), scale=2.2)          # 白い石灰岩の石組み
L.material('blocks', 'large_sandstone_blocks_01', (0.92, 0.82, 0.66), scale=3)
L.material('pave', 'red_sandstone_pavement', (0.8, 0.72, 0.6), scale=3)
L.material('granite', 'granite_wall', (0.66, 0.38, 0.33), scale=5)             # 王の間の赤い花こう岩
L.material('rock', 'cliff_side', (0.72, 0.6, 0.48), scale=3.5)                  # 掘っただけの岩
L.material('dark', 'sandstone_blocks_08', (0.02, 0.015, 0.01), scale=3)
L.emission('daylight', (1.0, 0.9, 0.72), 6.0)
L.emission('glow', (1.0, 0.55, 0.2), 8.0)
L.emission('goldglow', (1.0, 0.75, 0.3), 3.0)

L.group('tunnel', 2048)
L.group('gallery', 2048)
L.group('king', 2048)


def room(group, x0, x1, z0, z1, h, mat='lime', ceil='lime', floor='pave', doors=(), door_h=4.4, ceiling=True, walls='nsew'):
    """四角い部屋。doors=[('n'|'s'|'e'|'w', 中心, 幅)]"""
    t = 1.0
    L.box(group, floor, ((x0 + x1) / 2, -0.15, (z0 + z1) / 2), (x1 - x0, 0.3, z1 - z0), collide=False)
    if ceiling: L.box(group, ceil, ((x0 + x1) / 2, h + 0.25, (z0 + z1) / 2), (x1 - x0 + 2 * t, 0.5, z1 - z0 + 2 * t), collide=False)
    for side in walls:
        gaps = sorted([(c - w / 2, c + w / 2) for s_, c, w in doors if s_ == side])
        if side in 'ns':
            a, b = x0 - t, x1 + t; zc = z0 - t / 2 if side == 'n' else z1 + t / 2
            cur = a
            for g0, g1 in gaps + [(b, b)]:
                if g0 > cur: L.box(group, mat, ((cur + g0) / 2, h / 2, zc), (g0 - cur, h, t))
                if g1 < b and g0 < b and h > door_h: L.box(group, mat, ((g0 + g1) / 2, (h + door_h) / 2, zc), (g1 - g0, h - door_h, t), collide=False)
                cur = g1
        else:
            a, b = z0, z1; xc = x1 + t / 2 if side == 'e' else x0 - t / 2
            cur = a
            for g0, g1 in gaps + [(b, b)]:
                if g0 > cur: L.box(group, mat, (xc, h / 2, (cur + g0) / 2), (t, h, g0 - cur))
                if g1 < b and g0 < b and h > door_h: L.box(group, mat, (xc, (h + door_h) / 2, (g0 + g1) / 2), (t, h - door_h, g1 - g0), collide=False)
                cur = g1


def rough(group, x0, x1, z0, z1, h, seed):
    """掘っただけの岩肌：壁ぎわと天井に岩のかたまり"""
    rnd = random.Random(seed)
    for i in range(int((x1 - x0) * (z1 - z0) / 18)):
        side = rnd.choice('nsew')
        s = rnd.uniform(0.5, 1.0) * min(1.0, (min(x1 - x0, z1 - z0)) / 6 + 0.4)
        if side in 'ns': x = rnd.uniform(x0, x1); z = z0 - s * 0.35 if side == 'n' else z1 + s * 0.35
        else: z = rnd.uniform(z0, z1); x = x0 - s * 0.35 if side == 'w' else x1 + s * 0.35
        L.rock(group, 'rock', (x, rnd.uniform(s * 0.5, h - s * 0.5), z), (s, s * 0.8, s), seed=seed * 100 + i, rough=0.4, subdiv=2)   # 壁にうまった岩


# ============================================================ 盗掘者の穴と分かれ道
room('tunnel', -1.8, 1.8, 10, 42, 4.2, mat='rock', ceil='rock', floor='rock', doors=[('s', 0, 3.6)], door_h=4.0, walls='sew')
rough('tunnel', -1.8, 1.8, 10, 42, 4.2, 1)
L.box('tunnel', 'daylight', (0, 2.2, 43.4), (3.6, 4.4, 0.1), collide=False)       # 外の光
L.box('tunnel', 'rock', (0, 2.2, 44), (6, 5, 1))                                   # 入口の外（光の板のうしろ）
room('tunnel', -5, 5, -4, 10, 7, doors=[('s', 0, 3.6), ('n', 0, 3.2), ('w', 4, 3.2)])
for i, (x, z) in enumerate(((3.4, -2.2), (3.4, -0.2), (3.4, 1.8))):              # 上り通路をふさいでいた花こう岩の栓
    L.box('tunnel', 'granite', (x, 0.6, z), (2.0, 1.2, 1.8), rot=0.1 * i)

# 下り通路と地下の間（未完成で岩がむき出し）
room('tunnel', -30, -5, 2, 6, 4.2, mat='blocks', ceil='blocks', walls='ns')
room('tunnel', -52, -30, -12, 18, 5.5, mat='rock', ceil='rock', floor='rock', doors=[('e', 4, 3.6)], door_h=4.0)
rough('tunnel', -52, -30, -12, 18, 5.5, 2)
L.box('tunnel', 'dark', (-44, 0.02, 4), (3.2, 0.05, 3.2), collide=False)           # 底の見えない穴
for dx, dz in ((-1.9, 0), (1.9, 0), (0, -1.9), (0, 1.9)):
    L.box('tunnel', 'rock', (-44 + dx, 0.35, 4 + dz), (0.6 if dx else 3.8, 0.7, 3.8 if dx else 0.6))
L.meta['colliders']['boxes'].append([-46, -42, 2, 6])
for i in range(7):                                                                  # 床の岩のかたまり
    L.rock('tunnel', 'rock', (random.uniform(-50, -34), 0.4, random.uniform(-10, 16)), (1.4, 0.9, 1.2), seed=300 + i, collide=True)

# ============================================================ 上り通路と大回廊
room('gallery', -1.6, 1.6, -22, -4, 5, walls='ew')
GX, GZ0, GZ1, GH = 3.0, -74, -22, 17.0
L.box('gallery', 'pave', (0, -0.15, (GZ0 + GZ1) / 2), (2 * GX, 0.3, GZ1 - GZ0), collide=False)
# 壁：下 2.3m はまっすぐ、上は 7 段ずつ内側へせり出す（持ち送り）
for s in (-1, 1):
    doors = [(-26, 3.2)] if s > 0 else []
    z_parts = [(GZ0, GZ1)]
    for c, w in doors:
        z_parts = [(a, b) for a, b in [(GZ0, c - w / 2), (c + w / 2, GZ1)]]
    for a, b in z_parts:
        L.box('gallery', 'lime', (s * (GX + 0.5), 1.15, (a + b) / 2), (1.0, 2.3, b - a))
    if doors:
        c, w = doors[0]; L.box('gallery', 'lime', (s * (GX + 0.5), 3.4, c), (1.0, 2.2, w), collide=False)
    for k in range(7):
        y0 = 2.3 + k * 2.1; inset = (k + 1) * 0.28
        L.box('gallery', 'lime', (s * (GX + 0.5 - inset), y0 + 1.05, (GZ0 + GZ1) / 2), (1.0, 2.1, GZ1 - GZ0), collide=False)
    L.box('gallery', 'blocks', (s * (GX - 0.45), 0.3, (GZ0 + GZ1) / 2), (0.7, 0.6, GZ1 - GZ0 - 0.2))     # 両わきの低い台
L.box('gallery', 'lime', (0, GH + 0.25, (GZ0 + GZ1) / 2), (2 * GX, 0.5, GZ1 - GZ0), collide=False)       # 天井
for zc in (GZ1 + 0.5, GZ0 - 0.5):                                                   # 両はしの壁（入口のところは開ける）
    L.box('gallery', 'lime', (0, (GH + 4.6) / 2, zc), (2 * GX + 2, GH - 4.6, 1.0), collide=False)
    for s in (-1, 1): L.box('gallery', 'lime', (s * (GX - 0.4), 2.3, zc), (1.6, 4.6, 1.0))
L.meta['colliders']['boxes'] += [[-GX - 1, -GX + 0.8, GZ0, GZ1], [GX - 0.8, GX + 1, GZ0, -27.6], [GX - 0.8, GX + 1, -24.4, GZ1]]

# 女王の間への通路と、切妻の天井の女王の間
room('gallery', 3, 30, -27.6, -24.4, 4.4, doors=[('w', -26, 3.2), ('e', -26, 3.2)])
room('gallery', 30, 42, -32, -20, 7, ceiling=False, doors=[('w', -26, 3.2), ('e', -26, 2.4)])
bm = L.bm('gallery', 'lime')
xs, zs, y0, yr = (29, 43), (-33, -19), 7.0, 11.0
v = [bm.verts.new(B(x, y, z)) for x, y, z in ((xs[0], y0, zs[0]), (xs[1], y0, zs[0]), (xs[1], yr, -26), (xs[0], yr, -26),
                                             (xs[0], y0, zs[1]), (xs[1], y0, zs[1]))]
# 面は部屋の内側を向くように
bm.faces.new((v[1], v[2], v[3], v[0])); bm.faces.new((v[3], v[2], v[5], v[4]))
bm.faces.new((v[3], v[4], v[0])); bm.faces.new((v[5], v[2], v[1]))
# 東の壁のくぼみ（段々のニッチ）と、その奥の隠し通路
for k in range(4):
    L.box('gallery', 'lime', (42.3, 4.6 + k * 0.6, -26), (0.6, 0.6, 3.6 - k * 0.7), collide=False)
room('gallery', 42, 60, -27.2, -24.8, 3.2, mat='blocks', ceil='blocks', doors=[('w', -26, 2.4), ('e', -26, 2.4)], door_h=3.0)
room('gallery', 60, 74, -34, -18, 9, mat='blocks', ceil='lime', doors=[('w', -26, 2.4)], door_h=3.0)
L.box('gallery', 'goldglow', (73.4, 4.5, -26), (0.1, 5.0, 10.0), collide=False)   # 金色に光る壁画

# ============================================================ 前室と王の間（赤い花こう岩）
room('king', -2.6, 2.6, -80, -74, 7, mat='granite', ceil='granite', floor='granite', walls='ew')
room('king', -10, 10, -91, -80, 11, mat='granite', ceil='granite', floor='granite', doors=[('s', 0, 3.2)])
for x in range(-9, 11, 2):                                                          # 天井の花こう岩の梁
    L.box('king', 'granite', (x, 10.6, -85.5), (1.6, 0.8, 11), collide=False)
L.box('king', 'granite', (6, 0.55, -86), (2.4, 1.1, 1.2))                          # 石棺
L.box('king', 'dark', (6, 1.105, -86), (2.0, 0.02, 0.8), collide=False)
for x, z in ((-6, -80.4), (-6, -90.6)):                                             # 通気孔
    L.box('king', 'dark', (x, 1.4, z), (0.45, 0.45, 0.2), collide=False)
L.box('king', 'glow', (-6, 0.5, -86), (0.9, 0.2, 0.9), collide=False)              # 火鉢
L.box('king', 'granite', (-6, 0.25, -86), (1.1, 0.5, 1.1))

# ============================================================ 光（たいまつ）
T = [(-1.2, 2.6, 30), (1.2, 2.6, 18), (-4.2, 3.0, 2), (4.2, 3.0, 8), (-18, 2.8, 2.6), (-31, 3.0, 12), (-51, 3.0, -4), (-31, 3.0, -10),
     (-1.2, 3.0, -10), (-2.6, 3.2, -30), (2.6, 3.2, -40), (-2.6, 3.2, -52), (2.6, 3.2, -64), (-2.6, 3.2, -72),
     (14, 2.8, -24.8), (31, 3.2, -21), (41, 3.2, -31), (51, 2.4, -25.2), (61, 3.2, -19), (-2, 3.2, -75), (-9, 3.4, -81), (9, 3.4, -81)]
for p in T: L.point(p, 110)
L.point((-6, 1.4, -86), 300, (1.0, 0.5, 0.18), torch=False)
L.point((70, 4.5, -26), 250, (1.0, 0.78, 0.4), torch=False)
L.area((0, 2.2, 42.5), 3.0, 600, (1.0, 0.92, 0.78), (0, 0, -1))                 # 入口から差しこむ外の光

# ============================================================ ゲーム用
M = L.meta
M['regions'] = [
    {'name': 'pyr_tunnel', 'box': [-6, 6, -4, 44], 'kind': 'cave', 'music': 'tomb'},
    {'name': 'pyr_under', 'box': [-54, -6, -14, 20], 'kind': 'cave', 'music': 'tomb'},
    {'name': 'pyr_hall', 'box': [-12, 76, -95, -4], 'kind': 'indoor', 'music': 'tomb'},
]
M['spawns'] = {'default': {'x': 0, 'z': 38, 'face': math.pi}, 'giza': {'x': 0, 'z': 38, 'face': math.pi}}
M['exits'] = [{'x': 0, 'z': 41.2, 'r': 1.8, 'to': 'giza'}]
M['enemies'] = [{'type': 'mummy', 'x': 0, 'z': -40}, {'type': 'mummy', 'x': 1, 'z': -60}, {'type': 'mummy', 'x': 36, 'z': -26},
                {'type': 'mummy', 'x': -40, 'z': 0}, {'type': 'mummy', 'x': -46, 'z': 12}, {'type': 'jackal', 'x': 0, 'z': -86}]
M['chests'] = [{'x': 67, 'z': -30, 'ankh': 400}, {'x': -50, 'z': -9, 'ankh': 200}]
M['waters'] = []
M['beams'] = []
M['seal'] = {'x0': -1.6, 'x1': 1.6, 'z0': -80, 'z1': -79, 'h': 4.4}       # 封印の扉（石板3つで開く）
M['relic'] = {'x': 6, 'z': -86}                                             # 秘宝（石棺の上）

L.bake_and_export()

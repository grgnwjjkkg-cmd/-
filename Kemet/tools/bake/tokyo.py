"""夜の東京：時の門の先の現代。大きな交差点の真ん中に、エジプトの遺跡（オベリスクと小さなピラミッド）が地面を割って現れている。
まわりは窓の明かりのビル、色とりどりのネオン（実在の店名・ブランドは使わない）、街灯。
低いビルの屋上を跳びついで、高いビルの屋上へ上れる。出てくるのは遺跡からあふれた影の怪物だけ（人とは戦わない）。
使い方（Kemet/ で）:
  blender -b --python tools/bake/tokyo.py -- [samples]
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from lib import Level, B

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
SAMPLES = int(argv[0]) if argv else 160
random.seed(71)
L = Level('tokyo', SAMPLES)
STAND = os.path.join(os.path.dirname(__file__), 'models', 'statue_standing.obj')

L.material('asphalt', 'asphalt_02', (0.55, 0.55, 0.58), scale=6)
L.material('walk', 'concrete_wall_008', (0.72, 0.72, 0.74), scale=3)
L.material('facade', 'rectangular_facade_tiles', (0.8, 0.8, 0.82), scale=6)
L.material('facade2', 'concrete_tile_facade', (0.75, 0.74, 0.72), scale=5)
L.material('concrete', 'concrete_wall_008', (0.6, 0.6, 0.62), scale=4)
L.material('stone', 'sandstone_blocks_08', (0.95, 0.85, 0.7), scale=2.5)
L.material('blocks', 'large_sandstone_blocks_01', (0.9, 0.8, 0.66), scale=3)
L.material('paint', 'concrete_wall_008', (1.4, 1.4, 1.4), scale=4)    # 横断歩道の白線
L.emission('win', (1.0, 0.86, 0.6), 2.6)
L.emission('win2', (0.7, 0.85, 1.0), 2.2)
L.emission('neon1', (1.0, 0.2, 0.6), 9.0)
L.emission('neon2', (0.2, 0.9, 1.0), 9.0)
L.emission('neon3', (1.0, 0.75, 0.2), 8.0)
L.emission('lamp', (1.0, 0.92, 0.75), 12.0)
L.emission('gold', (1.0, 0.72, 0.3), 5.0)

L.group('street', 4096)
L.group('city', 4096)
L.group('far', 1024)
M = L.meta

# ---------- 道路・歩道・横断歩道 ----------
L.box('street', 'asphalt', (0, -0.1, 0), (160, 0.2, 160), collide=False)
for sx in (-1, 1):
    for sz in (-1, 1):
        L.box('street', 'walk', (sx * 50, 0.05, sz * 50), (68, 0.2, 68), collide=False)       # 4つのブロックの歩道
for i in range(12):   # 交差点の白線（四方向と、ななめ）
    for (x, z, w, d) in ((-10 + i * 1.8, 18, 0.9, 6), (-10 + i * 1.8, -18, 0.9, 6), (18, -10 + i * 1.8, 6, 0.9), (-18, -10 + i * 1.8, 6, 0.9)):
        L.box('street', 'paint', (x, 0.01, z), (w, 0.02, d), collide=False)

# ---------- 交差点の真ん中：地面を割って現れた遺跡 ----------
for i in range(14):
    a = i / 14 * math.tau; r = random.uniform(5, 9)
    L.rock('street', 'asphalt', (math.cos(a) * r, 0.3, math.sin(a) * r), (2.2, 0.8, 1.4), seed=i, rough=0.4, subdiv=1)   # めくれた道路
L.box('street', 'blocks', (0, 0.6, 0), (9, 1.2, 9))
L.tbox('street', 'stone', (0, 12, 0), (2.2, 22, 2.2), taper=0.6)               # オベリスク
bm = L.bm('street', 'gold')
v = [bm.verts.new(B(dx * 0.7, 23, dz * 0.7)) for dx, dz in ((-1, 1), (1, 1), (1, -1), (-1, -1))]
top = bm.verts.new(B(0, 24.6, 0))
for k in range(4): bm.faces.new((v[k], v[(k + 1) % 4], top))
for sx in (-1, 1):
    L.mesh_file('street', 'stone', STAND, (sx * 3.2, 1.2, 3.2), scale=3.4)

# ---------- ビル：窓の明かり、ネオン ----------
def building(x, z, w, d, h, mat, lit=0.55, seed=0):
    rnd = random.Random(seed)
    L.box('city', mat, (x, h / 2, z), (w, h, d))
    L.platform(x - w / 2, x + w / 2, z - d / 2, z + d / 2, h)                     # 屋上に乗れる
    # 窓（一部だけ明かりがついている）
    for side in ('n', 's', 'e', 'w'):
        n_col = int((w if side in 'ns' else d) / 2.6); n_row = int(h / 3.2)
        for c in range(n_col):
            for r in range(1, n_row):
                if rnd.random() > lit: continue
                off = -((w if side in 'ns' else d) / 2) + (c + 0.5) * ((w if side in 'ns' else d) / n_col)
                y = r * 3.2 + 1.2
                mat_w = 'win' if rnd.random() < 0.7 else 'win2'
                if side == 'n': L.box('city', mat_w, (x + off, y, z - d / 2 - 0.03), (1.3, 1.5, 0.05), collide=False)
                if side == 's': L.box('city', mat_w, (x + off, y, z + d / 2 + 0.03), (1.3, 1.5, 0.05), collide=False)
                if side == 'e': L.box('city', mat_w, (x + w / 2 + 0.03, y, z + off), (0.05, 1.5, 1.3), collide=False)
                if side == 'w': L.box('city', mat_w, (x - w / 2 - 0.03, y, z + off), (0.05, 1.5, 1.3), collide=False)


def neon(x, y, z, w, h, facing, mat):
    if facing in 'ns': L.box('city', mat, (x, y, z), (w, h, 0.15), collide=False)
    else: L.box('city', mat, (x, y, z), (0.15, h, w), collide=False)


# 高いビル（遠く・背景）
for sx in (-1, 1):
    for sz in (-1, 1):
        for i in range(3):
            bx, bz = sx * (30 + i * 16), sz * 72
            building(bx, bz, 14, 14, 40 + (i * 13 % 25), 'facade' if i % 2 else 'facade2', seed=sx * 10 + sz * 3 + i)
        building(sx * 72, sz * 34, 14, 26, 55 + (sz > 0) * 20, 'facade2', seed=sx * 7 + sz)
# 屋上を跳びついで上るビル（北西のブロック）：高さ 1.2m ずつ上がる
steps = [(-26, -26, 6, 6, 1.2), (-26, -34, 6, 6, 2.4), (-34, -34, 6, 6, 3.6), (-42, -34, 6, 8, 4.8), (-42, -44, 8, 8, 6.0)]
for i, (x, z, w, d, h) in enumerate(steps):
    building(x, z, w, d, h, 'concrete', lit=0.3, seed=100 + i)
L.box('city', 'walk', (-42, 6.1, -44), (8, 0.2, 8), collide=False)
# 手前の低い店（通りに面した側にネオン）
shops = [(-32, 30, 18, 10, 's', 'neon1'), (32, 30, 18, 10, 's', 'neon2'), (32, -30, 18, 10, 'n', 'neon3'), (-32, -30, 14, 10, 'n', 'neon2'), (-30, 44, 14, 10, 's', 'neon3')]
for i, (x, z, w, d, facing, mat) in enumerate(shops):
    h = 9 + (i % 3) * 2
    building(x, z, w, d, h, 'facade2', lit=0.7, seed=200 + i)
    fz = z + (d / 2 + 0.2 if facing == 's' else -d / 2 - 0.2)
    neon(x, 4.2, fz, w * 0.75, 1.2, 'n', mat)                    # 横長の看板
    neon(x - w / 2 + 1, h * 0.55, fz, 0.9, h * 0.6, 'n', mat)   # 縦長の看板
# 街灯
for x in range(-60, 61, 20):
    for z in (-14, 14):
        if abs(x) < 16: continue
        L.cyl('street', 'concrete', x, z, 0, 7, 0.12, 0.1, seg=10)
        L.box('street', 'lamp', (x, 7.1, z), (1.2, 0.2, 0.4), collide=False)
        L.point((x, 6.8, z), 260, (1.0, 0.88, 0.7), torch=False)
for (x, y, z, c) in ((-30, 5, 28, (1, 0.2, 0.6)), (30, 5, 28, (0.2, 0.9, 1)), (30, 5, -28, (1, 0.75, 0.2))):
    L.point((x, y, z), 500, c, torch=False)
L.point((0, 20, 0), 400, (1.0, 0.75, 0.35), torch=False)     # オベリスクの金の頂の光

# 遠くのビルの影（夜景）
for i in range(70):
    a = random.uniform(0, math.tau); r = random.uniform(180, 600)
    h = random.uniform(30, 160)
    L.box('far', 'win' if random.random() < 0.12 else 'concrete', (math.cos(a) * r, h / 2, math.sin(a) * r), (random.uniform(15, 40), h, random.uniform(15, 40)), collide=False)

# ---------- 光（夜：月の青い光） ----------
L.sky('goegap.hdr', strength=0.04, rotation=0)
L.sun(elevation=50, azimuth=120, energy=0.25, color=(0.6, 0.7, 1.0))

# ---------- ゲーム用 ----------
C = M['colliders']['boxes']
C += [[-85, -80, -85, 85], [80, 85, -85, 85], [-85, 85, -85, -80], [-85, -3, 80, 85], [3, 85, 80, 85]]
M['regions'] = [{'name': 'tokyo', 'box': [-3000, 3000, -3000, 3000], 'kind': 'night', 'music': 'tomb'}]
M['spawns'] = {'default': {'x': 0, 'z': 70, 'face': math.pi}, 'sky': {'x': 0, 'z': 70, 'face': math.pi}}
M['exits'] = [{'x': 0, 'z': 78, 'r': 2.6, 'to': 'sky'}]
M['enemies'] = [{'type': 'mummy', 'x': -10, 'z': 30}, {'type': 'mummy', 'x': 12, 'z': -30}, {'type': 'mummy', 'x': 30, 'z': 8},
                {'type': 'guardian', 'x': 0, 'z': -12}]
M['chests'] = [{'x': -42, 'z': -45, 'ankh': 800}, {'x': 44, 'z': 44, 'ankh': 300}]
M['waters'] = []
M['beams'] = []

L.bake_and_export()

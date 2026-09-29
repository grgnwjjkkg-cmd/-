"""星の都ネブト（宇宙都市）：時の門の先、はるか未来。地球を見下ろす宇宙に浮かぶ金属の都。
南の港（着く所）→ 橋 → 中央の広場（頭上に浮かぶ金のピラミッド）→ 西：浮かぶ足場を跳んで星見の台／東：光る炉の間／北：段々の足場を上って星の玉座。
重力が弱い（0.4倍）ので、高く遠くまで跳べる。足場の外はまっ暗な宇宙（落ちると戻される）。地球と星はゲーム側でかく。
使い方（Kemet/ で）:
  blender -b --python tools/bake/space.py -- [samples]
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from lib import Level, B

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
SAMPLES = int(argv[0]) if argv else 160
random.seed(81)
L = Level('space', SAMPLES)
STAND = os.path.join(os.path.dirname(__file__), 'models', 'statue_standing.obj')
COL = os.path.join(os.path.dirname(__file__), 'models', 'colossus.obj')

L.material('floor', 'metal_plate', (0.8, 0.8, 0.84), scale=3, rough=0.5)
L.material('floor2', 'metal_plate_02', (0.75, 0.74, 0.72), scale=3, rough=0.5)
L.material('panel', 'blue_metal_plate', (0.85, 0.88, 0.95), scale=4, rough=0.45)
L.material('hull', 'painted_metal_shutter', (0.7, 0.72, 0.78), scale=5, rough=0.55)
L.material('stone', 'sandstone_blocks_08', (1.0, 0.92, 0.78), scale=2.5)
L.material('goldm', 'metal_plate', (1.0, 0.76, 0.36), scale=3, rough=0.35)
L.emission('strip', (0.35, 0.85, 1.0), 6.0)
L.emission('gold', (1.0, 0.74, 0.3), 7.0)
L.emission('core', (0.5, 0.9, 1.0), 16.0)
L.emission('win', (0.9, 0.95, 1.0), 1.4)

L.group('deck', 4096)
L.group('city', 2048)
L.group('far', 1024)
M = L.meta


def hub(x0, x1, z0, z1, top=0.0, gaps=(), mat='floor', depth=10):
    """浮かぶ金属の床：ふちの低い手すりと光の線、下は逆さのピラミッド形の船体"""
    cx, cz, w, d = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0
    L.box('deck', mat, (cx, top - 0.3, cz), (w, 0.6, d), collide=False)
    L.platform(x0, x1, z0, z1, top)
    for side in 'nsew':
        g = sorted([(c - gw / 2, c + gw / 2) for s, c, gw in gaps if s == side])
        a, b = (x0, x1) if side in 'ns' else (z0, z1)
        cur = a
        for g0, g1 in g + [(b, b)]:
            if g0 > cur:
                if side in 'ns':
                    zc = z0 if side == 'n' else z1
                    L.box('deck', 'hull', ((cur + g0) / 2, top + 0.45, zc), (g0 - cur, 0.9, 0.4))
                    L.box('deck', 'strip', ((cur + g0) / 2, top + 0.92, zc), (g0 - cur, 0.06, 0.42), collide=False)
                else:
                    xc = x1 if side == 'e' else x0
                    L.box('deck', 'hull', (xc, top + 0.45, (cur + g0) / 2), (0.4, 0.9, g0 - cur))
                    L.box('deck', 'strip', (xc, top + 0.92, (cur + g0) / 2), (0.42, 0.06, g0 - cur), collide=False)
            cur = g1
    # 船体（下へすぼまる）
    L.cyl('deck', 'hull', cx, cz, top - 0.6 - depth, depth, 1.2, min(w, d) * 0.5, seg=4, collide=False)
    L.box('deck', 'strip', (cx, top - 0.62, cz), (w - 0.6, 0.05, d - 0.6), collide=False)   # 裏の光


def pad(x, z, top, s=4.2):
    """跳んで渡る小さな浮き足場"""
    L.box('deck', 'floor2', (x, top - 0.25, z), (s, 0.5, s), collide=False)
    L.box('deck', 'strip', (x, top - 0.52, z), (s * 0.7, 0.05, s * 0.7), collide=False)
    L.cyl('deck', 'hull', x, z, top - 3.5, 3.0, 0.4, s * 0.55, seg=4, collide=False)
    L.platform(x - s / 2, x + s / 2, z - s / 2, z + s / 2, top)


def bridge(x0, x1, z0, z1):
    L.box('deck', 'floor2', ((x0 + x1) / 2, -0.25, (z0 + z1) / 2), (x1 - x0, 0.5, z1 - z0), collide=False)
    L.platform(x0, x1, z0, z1, 0)
    along_x = (x1 - x0) > (z1 - z0)
    for s in (0, 1):
        if along_x:
            z = z0 if s == 0 else z1
            L.box('deck', 'hull', ((x0 + x1) / 2, 0.45, z), (x1 - x0, 0.9, 0.3))
            L.box('deck', 'strip', ((x0 + x1) / 2, 0.92, z), (x1 - x0, 0.06, 0.32), collide=False)
        else:
            x = x0 if s == 0 else x1
            L.box('deck', 'hull', (x, 0.45, (z0 + z1) / 2), (0.3, 0.9, z1 - z0))
            L.box('deck', 'strip', (x, 0.92, (z0 + z1) / 2), (0.32, 0.06, z1 - z0), collide=False)


# ---------- 南の港（着く所） ----------
hub(-12, 12, 48, 72, gaps=[('n', 0, 6)])
L.box('deck', 'strip', (0, 0.02, 67.5), (4, 0.02, 4), collide=False)     # 時の門の着地点
for sx in (-1, 1):
    L.box('city', 'panel', (sx * 9, 3, 60), (3, 6, 10))                   # 港の建物
    for z in (57, 60, 63):
        L.box('city', 'win', (sx * 7.45, 3.8, z), (0.05, 0.8, 1.8), collide=False)
bridge(-3, 3, 26, 48)

# ---------- 中央の広場：頭上に浮かぶ金のピラミッド ----------
hub(-24, 24, -22, 26, gaps=[('s', 0, 6), ('w', 0, 6), ('e', 0, 6), ('n', 0, 6)], depth=16)
L.box('deck', 'panel', (0, 0.02, 2), (18, 0.04, 18), collide=False)
for sx in (-1, 1):
    for sz in (-1, 1):
        L.tbox('city', 'stone', (sx * 18, 7, sz * 16 + 2), (1.6, 14, 1.6), taper=0.6)          # オベリスク
        L.box('city', 'gold', (sx * 18, 14.3, sz * 16 + 2), (0.9, 0.6, 0.9), collide=False)
    L.box('city', 'stone', (sx * 8, 0.8, -14), (3, 1.6, 3))
    L.mesh_file('city', 'stone', STAND, (sx * 8, 1.6, -14), scale=4.2)
# 浮かぶピラミッド（金属の面と、光る稜線）。影の輪が下の広場に落ちる
bm = L.bm('city', 'goldm')
H0, H1, R = 16, 34, 11
v = [bm.verts.new(B(dx * R, H0, 2 + dz * R)) for dx, dz in ((-1, 1), (1, 1), (1, -1), (-1, -1))]
top = bm.verts.new(B(0, H1, 2)); bot = bm.verts.new(B(0, H0 - 7, 2))
for k in range(4):
    bm.faces.new((v[k], v[(k + 1) % 4], top))
    bm.faces.new((v[(k + 1) % 4], v[k], bot))
for sx in (-1, 1):   # ふちの光の帯
    L.box('city', 'gold', (sx * R, H0, 2), (0.35, 0.35, 2 * R), collide=False)
    L.box('city', 'gold', (0, H0, 2 + sx * R), (2 * R, 0.35, 0.35), collide=False)
L.box('city', 'core', (0, H0 - 7.5, 2), (1.2, 1.2, 1.2), collide=False)
L.point((0, H0 - 9, 2), 2500, (0.6, 0.9, 1.0), torch=False)

# ---------- 西：浮き足場を跳んで星見の台へ ----------
for i, (x, z, t) in enumerate(((-31, 0, 0.0), (-38.5, -3, 1.2), (-46, 1, 2.4), (-53.5, -2, 1.6))):
    pad(x, z, t)
hub(-78, -60, -10, 10, top=1.0, gaps=[('e', 0, 5)])
L.cyl('city', 'panel', -72, 0, 1.0, 1.2, 3.2, 3.0, seg=24)                   # 星見の台座
L.cyl('city', 'strip', -72, 0, 2.2, 0.06, 3.1, 3.1, seg=24, collide=False)
L.tbox('city', 'hull', (-72, 5.5, 0), (0.8, 7, 0.8), taper=0.4, collide=False)   # 望遠鏡の柱
L.point((-72, 4, 0), 400, (0.4, 0.8, 1.0), torch=False)

# ---------- 東：光る炉の間 ----------
bridge(24, 44, -3, 3)
hub(44, 72, -14, 14, gaps=[('w', 0, 6)])
L.cyl('city', 'hull', 60, 0, 0, 1.0, 4.4, 4.2, seg=32)
L.cyl('city', 'core', 60, 0, 1.0, 9.0, 1.2, 1.2, seg=24, collide=False)        # 光の柱（炉）
for k in range(3):
    L.cyl('city', 'strip', 60, 0, 2.5 + k * 2.4, 0.15, 3.2, 3.2, seg=32, collide=False)
L.point((60, 5, 0), 3000, (0.5, 0.9, 1.0), torch=False)
for sz in (-1, 1):
    L.box('city', 'panel', (66, 2.5, sz * 10), (8, 5, 4))

# ---------- 北：段々の足場を上って星の玉座 ----------
for i, (x, z, t) in enumerate(((0, -28, 1.2), (4, -34.5, 2.6), (-2, -41, 4.0), (2, -47.5, 5.2))):
    pad(x, z, t)
hub(-14, 14, -80, -52, top=6.0, gaps=[('s', 1, 6)])
L.box('city', 'stone', (0, 7.0, -74), (8, 2, 5))
L.mesh_file('city', 'goldm', COL, (0, 8.0, -74), scale=8)                        # 星の玉座の座像
L.box('city', 'gold', (0, 6.03, -64), (5, 0.04, 14), collide=False)             # 光の道
for sx in (-1, 1):
    for z in (-58, -66):
        L.cyl('city', 'panel', sx * 10, z, 6, 9, 0.7, 0.6, seg=12)
        L.box('city', 'strip', (sx * 10, 15.2, z), (1.6, 0.3, 1.6), collide=False)
L.point((0, 12, -70), 1200, (1.0, 0.8, 0.5), torch=False)

# ---------- 遠くの都のかけら（背景） ----------
for i in range(28):
    a = random.uniform(0, math.tau); r = random.uniform(160, 520)
    x, z, y = math.cos(a) * r, math.sin(a) * r, random.uniform(-80, 90)
    s = random.uniform(10, 36)
    L.box('far', 'hull', (x, y, z), (s, s * random.uniform(0.2, 0.6), s * random.uniform(0.5, 1.2)), rot=a, collide=False)
    L.box('far', 'win', (x, y + s * 0.12, z), (s * 1.02, 0.6, s * 0.3), rot=a, collide=False)
for k in range(2):   # 大きな輪（遠くの駅）
    cx, cz, cy = (-320, -380)[k], (-420, 260)[k], (60, -40)[k]
    for i in range(24):
        a = i / 24 * math.tau
        L.box('far', 'hull', (cx + math.cos(a) * 90, cy + math.sin(a) * 90, cz), (24, 8, 10), collide=False)

# ---------- 光（宇宙：まっ白で強い太陽、空はまっ黒） ----------
L.sky('goegap.hdr', strength=0.015, rotation=0)
L.sun(elevation=28, azimuth=210, energy=5.0, color=(1.0, 0.97, 0.92), angle=0.5)
for p in [(0, 4, 56), (0, 4, 10), (-18, 4, -10), (18, 4, -10), (-66, 5, 0), (0, 10, -60)]:
    L.point(p, 350, (0.5, 0.8, 1.0), torch=False)

# ---------- ゲーム用 ----------
M['regions'] = [{'name': 'space', 'box': [-3000, 3000, -3000, 3000], 'kind': 'space', 'music': 'tomb'}]
M['spawns'] = {'default': {'x': 0, 'z': 62, 'face': math.pi}, 'sky': {'x': 0, 'z': 62, 'face': math.pi}}
M['exits'] = [{'x': 0, 'z': 67.5, 'r': 1.8, 'to': 'sky'}]
M['enemies'] = [{'type': 'mummy', 'x': -8, 'z': 8}, {'type': 'mummy', 'x': 10, 'z': -6}, {'type': 'guardian', 'x': 56, 'z': 6},
                {'type': 'bandit', 'x': -70, 'z': 5}, {'type': 'guardian', 'x': 0, 'z': -62}]
M['chests'] = [{'x': -75, 'z': -6, 'ankh': 650}, {'x': 68, 'z': 10, 'ankh': 450}, {'x': 8, 'z': -76, 'ankh': 1100}]
M['waters'] = []
M['beams'] = []
M['groundless'] = True     # 床の外は宇宙（落ちると戻される）
M['gravity'] = 0.4         # 重力が弱い：高く遠くへ跳べる
M['exposureMul'] = 1.0

L.bake_and_export()

"""天空都市ヘリオポリス：雲の上に浮かぶ島々を石の橋がつなぐ、太陽神ラーの都。
南の島（着く所）→ 中央の島（太陽神殿と光るオベリスク）→ 東：空中庭園／西：星見の台／北：ラーの玉座（巨大な座像）。
島のふちには低い石のへりがあり、落ちない。
使い方（Kemet/ で）:
  blender -b --python tools/bake/sky.py -- [samples]
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from lib import Level, B

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
SAMPLES = int(argv[0]) if argv else 160
random.seed(41)
L = Level('sky', SAMPLES)
COL = os.path.join(os.path.dirname(__file__), 'models', 'colossus.obj')
STAND = os.path.join(os.path.dirname(__file__), 'models', 'statue_standing.obj')

L.material('pave', 'red_sandstone_pavement', (0.95, 0.88, 0.78), scale=3)
L.material('white', 'sandstone_blocks_08', (1.0, 0.97, 0.9), scale=2.5)
L.material('blocks', 'large_sandstone_blocks_01', (1.0, 0.92, 0.8), scale=3)
L.material('rock', 'cliff_side', (0.85, 0.74, 0.62), scale=6)
L.material('gold', 'sandstone_blocks_08', (1.0, 0.78, 0.35), scale=2)
L.material('grass', 'aerial_sand', (0.35, 0.5, 0.22), scale=6)
L.emission('sun', (1.0, 0.8, 0.4), 12.0)
L.emission('cloud', (0.86, 0.9, 0.98), 1.1)

L.group('isles', 4096)
L.group('temple', 2048)
L.group('far', 1024)
C = L.meta['colliders']['boxes']


def isle(x0, x1, z0, z1, gaps=(), seed=0):
    """浮かぶ島：石の床、ふちの低いへり（gaps=[(辺, 中心, 幅)] は橋の口）、下にぶら下がる岩"""
    L.box('isles', 'pave', ((x0 + x1) / 2, -0.3, (z0 + z1) / 2), (x1 - x0, 0.6, z1 - z0), collide=False)
    for side in 'nsew':
        g = sorted([(c - w / 2, c + w / 2) for s, c, w in gaps if s == side])
        a, b = (x0, x1) if side in 'ns' else (z0, z1)
        cur = a
        for g0, g1 in g + [(b, b)]:
            if g0 > cur:
                if side in 'ns':
                    zc = z0 if side == 'n' else z1
                    L.box('isles', 'white', ((cur + g0) / 2, 0.45, zc), (g0 - cur, 0.9, 0.6))
                else:
                    xc = x1 if side == 'e' else x0
                    L.box('isles', 'white', (xc, 0.45, (cur + g0) / 2), (0.6, 0.9, g0 - cur))
            cur = g1
    # 下の岩（上の面は床の下で平らに切る）
    bm = L.bm('isles', 'rock')
    n0 = len(bm.verts)
    w, d = x1 - x0, z1 - z0
    L.rock('isles', 'rock', ((x0 + x1) / 2, -max(w, d) * 0.42, (z0 + z1) / 2), (w * 0.55, max(w, d) * 0.45, d * 0.55), seed=seed, rough=0.35)
    bm.verts.ensure_lookup_table()
    for v in bm.verts[n0:]:
        if v.co.z > -0.55: v.co.z = -0.55


def bridge(x0, x1, z0, z1):
    L.box('isles', 'white', ((x0 + x1) / 2, -0.25, (z0 + z1) / 2), (x1 - x0, 0.5, z1 - z0), collide=False)
    along_x = (x1 - x0) > (z1 - z0)
    for s in (0, 1):
        if along_x:
            z = z0 if s == 0 else z1
            L.box('isles', 'white', ((x0 + x1) / 2, 0.5, z), (x1 - x0, 1.0, 0.4))
        else:
            x = x0 if s == 0 else x1
            L.box('isles', 'white', (x, 0.5, (z0 + z1) / 2), (0.4, 1.0, z1 - z0))
    # 橋の下のアーチ
    n = int(max(x1 - x0, z1 - z0) / 6)
    for i in range(n + 1):
        t = i / max(1, n)
        cx, cz = (x0 + (x1 - x0) * t, (z0 + z1) / 2) if along_x else ((x0 + x1) / 2, z0 + (z1 - z0) * t)
        L.box('isles', 'white', (cx, -1.6, cz), (1.2 if along_x else x1 - x0, 2.4, z1 - z0 if along_x else 1.2), collide=False)


# ---------- 島と橋
isle(-12, 12, 40, 70, gaps=[('n', 0, 5)], seed=1)                                   # 南：着く島
bridge(-2.5, 2.5, 22, 40)
isle(-30, 30, -30, 22, gaps=[('s', 0, 5), ('e', -3.5, 5), ('w', -3.5, 5), ('n', 0, 5)], seed=2)   # 中央：太陽神殿
bridge(30, 52, -6, -1)
isle(52, 80, -20, 12, gaps=[('w', -3.5, 5)], seed=3)                                 # 東：空中庭園
bridge(-52, -30, -6, -1)
isle(-80, -52, -24, 16, gaps=[('e', -3.5, 5)], seed=4)                               # 西：星見の台
bridge(-2.5, 2.5, -52, -30)
isle(-18, 18, -84, -52, gaps=[('s', 0, 5)], seed=5)                                  # 北：ラーの玉座

# ---------- 中央：太陽神殿（塔門、柱の列、光る金の頂のオベリスク）
for s in (-1, 1):
    L.tbox('temple', 'white', (s * 8, 7, 17), (9, 14, 4), taper=0.8)
    L.box('temple', 'gold', (s * 8, 14.3, 17), (7.4, 0.6, 3.3), collide=False)
L.box('temple', 'white', (0, 11, 17), (7, 3, 3), collide=False)
for z in range(-24, 12, 6):
    for s in (-1, 1):
        L.cyl('temple', 'white', s * 14, z, 0, 9, 0.9, 0.8)
        L.cyl('temple', 'gold', s * 14, z, 9, 1.2, 0.8, 1.3, collide=False)
        L.box('temple', 'white', (s * 14, 10.5, z), (2.8, 0.6, 2.8), collide=False)
L.box('temple', 'white', (-14, 11.1, -6), (2.8, 0.6, 36), collide=False)
L.box('temple', 'white', (14, 11.1, -6), (2.8, 0.6, 36), collide=False)
L.box('temple', 'blocks', (0, 0.6, -10), (8, 1.2, 8))                                 # オベリスクの台
L.tbox('temple', 'white', (0, 14, -10), (3, 26, 3), taper=0.62)                       # オベリスク
bm = L.bm('temple', 'sun')                                                              # 金に光る頂（ピラミディオン）
v = [bm.verts.new(B(dx * 0.95, 27, -10 + dz * 0.95)) for dx, dz in ((-1, 1), (1, 1), (1, -1), (-1, -1))]
top = bm.verts.new(B(0, 29.5, -10))
for k in range(4): bm.faces.new((v[k], v[(k + 1) % 4], top))

# ---------- 東：空中庭園（段々の花壇と池）
for i, (w, d) in enumerate(((20, 22), (14, 16), (8, 10))):
    L.box('isles', 'blocks', (66, 0.5 + i * 1.0, -4), (w, 1.0, d))
    L.box('isles', 'grass', (66, 1.02 + i * 1.0, -4), (w - 0.8, 0.05, d - 0.8), collide=False)

# ---------- 西：星見の台（立った石の輪）
for i in range(12):
    a = i / 12 * math.tau
    L.box('isles', 'white', (-66 + math.cos(a) * 10, 3.5, -4 + math.sin(a) * 10), (1.4, 7, 1.0), rot=a)
L.box('isles', 'blocks', (-66, 0.4, -4), (6, 0.8, 6))

# ---------- 神々の立ち像：着く島の両わきと、玉座の両わき
for sx in (-1, 1):
    for z in (48, 60):
        L.box('isles', 'blocks', (sx * 8.5, 0.6, z), (3.2, 1.2, 3.2))
        L.mesh_file('isles', 'white', STAND, (sx * 8.5, 1.2, z), rot=sx * math.pi / 2, scale=5.2)
    L.box('temple', 'blocks', (sx * 12.5, 0.8, -66), (4, 1.6, 4))
    L.mesh_file('temple', 'gold', STAND, (sx * 12.5, 1.6, -66), scale=7)

# ---------- 北：ラーの玉座（金色の巨大な座像）
L.box('temple', 'blocks', (0, 1.5, -76), (14, 3, 12))
L.mesh_file('temple', 'gold', COL, (0, 3.0, -74), scale=15)

# ---------- 遠く：雲の海と、ほかの浮かぶ島
L.box('far', 'cloud', (0, -60, 0), (5000, 1, 5000), collide=False)
for i in range(60):
    a = random.uniform(0, math.tau); r = random.uniform(160, 900)
    s = random.uniform(15, 60)
    L.rock('far', 'cloud', (math.cos(a) * r, -55 + random.uniform(-5, 10), math.sin(a) * r), (s * 1.8, s * 0.4, s * 1.3), seed=100 + i, rough=0.3, subdiv=2)
for i in range(9):
    a = random.uniform(0, math.tau); r = random.uniform(200, 500); s = random.uniform(12, 35)
    x, z = math.cos(a) * r, math.sin(a) * r
    L.box('far', 'pave', (x, random.uniform(-15, 25), z), (s, 1.2, s), collide=False)
    L.rock('far', 'rock', (x, -s * 0.5, z), (s * 0.5, s * 0.5, s * 0.5), seed=200 + i, rough=0.35, subdiv=2)

# ---------- 光（夕方の低い金色の日ざし）
L.sky('goegap.hdr', strength=0.9, rotation=math.radians(40))
L.sun(elevation=24, azimuth=40, energy=4.4, color=(1.0, 0.82, 0.6))

# ---------- ゲーム用
M = L.meta
M['regions'] = [{'name': 'sky', 'box': [-3000, 3000, -3000, 3000], 'kind': 'heaven', 'music': 'desert'}]
M['spawns'] = {'default': {'x': 0, 'z': 62, 'face': math.pi}, 'giza': {'x': 0, 'z': 62, 'face': math.pi}}
M['exits'] = [{'x': 0, 'z': 67.5, 'r': 1.8, 'to': 'giza'}]
M['enemies'] = [{'type': 'guardian', 'x': 0, 'z': -66}, {'type': 'mummy', 'x': 64, 'z': 6}, {'type': 'bandit', 'x': -64, 'z': -12}, {'type': 'bandit', 'x': -8, 'z': -18}]
M['chests'] = [{'x': 72, 'z': -14, 'ankh': 500}, {'x': -74, 'z': 10, 'ankh': 450}, {'x': 10, 'z': -80, 'ankh': 900}]
M['waters'] = []
M['beams'] = []

L.bake_and_export()

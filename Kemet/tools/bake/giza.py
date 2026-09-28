"""ギザの台地：段々に積まれた大ピラミッド（高さ150m）、ほかのピラミッド、石の墓（マスタバ）が並ぶ通り。
大ピラミッドの南の面のふもとに「盗掘者の穴」があり、中（pyramid）へ入れる。
使い方（Kemet/ で）:
  blender -b --python tools/bake/giza.py -- [samples]
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from lib import Level, B

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
SAMPLES = int(argv[0]) if argv else 160
random.seed(11)
L = Level('giza', SAMPLES)

L.material('sand', 'coast_sand_01', (1.0, 0.92, 0.78), scale=4)
L.material('bed', 'aerial_sand', (0.95, 0.84, 0.68), scale=18)
L.material('courses', 'large_sandstone_blocks_01', (0.95, 0.84, 0.66), scale=4)   # ピラミッドの石の段
L.material('casing', 'sandstone_blocks_08', (1.0, 0.94, 0.82), scale=6)            # 上に残る化粧石
L.material('blocks', 'large_sandstone_blocks_01', (0.9, 0.8, 0.64), scale=3)
L.material('stone', 'sandstone_blocks_08', (0.95, 0.86, 0.72), scale=2.5)
L.material('rock', 'cliff_side', (0.95, 0.82, 0.66), scale=5)
L.material('dark', 'sandstone_blocks_08', (0.02, 0.015, 0.01), scale=3)

L.group('pyr', 4096)
L.group('ground', 2048)
L.group('far', 1024)


# ---------- 地面：台地は平ら、外は砂丘と岩盤
def dune(x, z):
    k = max(0.0, min(1.0, (max(abs(x) - 75, z - 100, -40 - z) + 5) / 30))
    h = 2.4 * math.sin(x * 0.05 + 1) + 1.7 * math.sin(z * 0.07 + x * 0.02) + 0.6 * math.sin(x * 0.19 - z * 0.11) + 2.8
    return h * k - 0.03


L.terrain('ground', 'sand', -120, 120, -60, 150, 60, 52, dune)
L.terrain('far', 'bed', -1600, 1600, -1600, 1600, 64, 64,
          lambda x, z: dune(x, z) - 0.4 + 5 * min(1, max(0, (math.hypot(x, z) - 260) / 300)) * math.sin(x * 0.004 + 1) * math.sin(z * 0.005 + 2))


# ---------- 段々のピラミッド（石の段を1段ずつ積む。1段 1.25m）
def stepped(group, mat, cx, cz, base, height, course=1.25, casing_from=None, collide=True):
    """見える面だけで作る：各段の外側の4面と、段の上の縁（内側は見えないので作らない）"""
    bm = L.bm(group, mat)
    n = int(height / course)
    inset = base / 2 / n
    top = n if casing_from is None else casing_from
    for i in range(top):
        s0 = base / 2 - inset * i; s1 = s0 - inset
        y0, y1 = i * course, (i + 1) * course
        sq = lambda h, y: [bm.verts.new(B(cx + dx * h, y, cz + dz * h)) for dx, dz in ((-1, 1), (1, 1), (1, -1), (-1, -1))]
        lo, hi, inner = sq(s0, y0), sq(s0, y1), sq(s1, y1)
        for k in range(4):
            j = (k + 1) % 4
            bm.faces.new((lo[k], lo[j], hi[j], hi[k]))            # 段の側面
            bm.faces.new((hi[k], hi[j], inner[j], inner[k]))      # 段の上の縁
    if casing_from is not None:   # 上のほうは化粧石が残ってなめらか
        s0 = base / 2 - inset * top; y0 = top * course
        cb = L.bm(group, 'casing')
        v = [cb.verts.new(B(cx + dx * s0, y0, cz + dz * s0)) for dx, dz in ((-1, 1), (1, 1), (1, -1), (-1, -1))]
        apex = cb.verts.new(B(cx, height, cz))
        for k in range(4): cb.faces.new((v[k], v[(k + 1) % 4], apex))
    if collide: L.meta['colliders']['boxes'].append([cx - base / 2, cx + base / 2, cz - base / 2, cz + base / 2])


GP = dict(cx=0, cz=-160, base=240, h=150)           # 大ピラミッド：南の面は z=-40
stepped('pyr', 'courses', GP['cx'], GP['cz'], GP['base'], GP['h'])
stepped('far', 'courses', -250, -380, 215, 143, casing_from=88, collide=False)   # カフラー王（上に化粧石）
stepped('far', 'courses', -430, -560, 105, 65, collide=False)                    # メンカウラー王
for i, x in enumerate((150, 150, 150)):                            # 王妃の小ピラミッド
    stepped('ground', 'courses', x, -150 + i * 55, 44, 30, collide=False)

# 盗掘者の穴（大ピラミッドの南の面のふもと）：大きな石の三角の梁と、暗い入口
FZ = GP['cz'] + GP['base'] / 2                      # 南の面の z
L.box('pyr', 'dark', (0, 2.2, FZ + 0.06), (3.6, 4.4, 0.1), collide=False)
for sx in (-1, 1):
    L.box('pyr', 'stone', (sx * 2.5, 2.5, FZ + 0.6), (1.4, 5.0, 1.2))
    L.box('pyr', 'stone', (sx * 1.6, 6.3, FZ + 0.5), (3.6, 1.2, 1.4), rot=0.0, collide=False)
L.box('pyr', 'stone', (0, 5.4, FZ + 0.7), (6.4, 0.8, 1.6), collide=False)
L.box('pyr', 'stone', (0, 7.4, FZ + 0.4), (4.2, 1.0, 1.2), collide=False)
# 崩れた石が入口のまわりに
for i in range(16):
    x = random.uniform(-14, 14); s = random.uniform(0.5, 1.4)
    if abs(x) < 3.5: continue
    L.rock('ground', 'rock', (x, s * 0.35, FZ + random.uniform(1.2, 6)), (s * 1.4, s * 0.8, s), seed=i, collide=s > 1.0)

# ---------- マスタバ（貴族の石の墓）の並ぶ通り
def mastaba(x, z, w, d, h):
    L.tbox('ground', 'blocks', (x, h / 2, z), (w, h, d), taper=0.86)
    L.box('ground', 'dark', (x, 1.2, z + d / 2 * 0.93 + 0.02), (1.0, 2.4, 0.1), collide=False)       # 偽の扉
    L.box('ground', 'stone', (x, 2.6, z + d / 2 * 0.93 + 0.1), (2.0, 0.4, 0.3), collide=False)


for side in (-1, 1):
    for r, z in enumerate(range(-20, 80, 16)):
        for c in range(2):
            x = side * (22 + c * 16)
            if side > 0 and c == 1 and r in (1, 4): continue   # 通りのすき間（探索できる路地）
            mastaba(x, z, 11, 11 + (r % 2) * 2, 5.5 + ((r + c) % 3) * 0.8)

# 参道の両わきの石
for z in range(0, 90, 10):
    for sx in (-1, 1):
        L.box('ground', 'stone', (sx * 8, 1.2, z), (1.0, 2.4, 1.0))

# 太陽の門：2本のオベリスクと、上にわたした金の横木
for sx in (-1, 1):
    L.box('ground', 'stone', (sx * 3.2, 0.5, 60), (2.2, 1.0, 2.2))
    L.tbox('ground', 'stone', (sx * 3.2, 7, 60), (1.3, 12, 1.3), taper=0.6)
L.box('ground', 'casing', (0, 12.6, 60), (8.6, 0.8, 1.0), collide=False)

# ---------- 光（午後の低い日ざし：段の影が長く伸びる）
L.sky('goegap.hdr', strength=1.0, rotation=math.radians(40))
L.sun(elevation=30, azimuth=75, energy=4.2, color=(1.0, 0.88, 0.7))

# ---------- ゲーム用
M = L.meta
C = M['colliders']['boxes']
C += [[-80, -74, -60, 100], [74, 80, -60, 100], [-80, 80, 96, 102]]   # 台地の外へは出ない（南の道だけ開ける）
C.remove([-80, 80, 96, 102]); C += [[-80, -4, 96, 102], [4, 80, 96, 102]]
M['regions'] = [{'name': 'giza', 'box': [-1600, 1600, -1600, 1600], 'kind': 'outdoor', 'music': 'desert'}]
M['spawns'] = {'default': {'x': 0, 'z': 88, 'face': math.pi}, 'necropolis': {'x': 0, 'z': 88, 'face': math.pi},
               'pyramid': {'x': 0, 'z': FZ + 5, 'face': 0}, 'sky': {'x': 0, 'z': 55, 'face': math.pi}}
M['exits'] = [{'x': 0, 'z': 99, 'r': 3.2, 'to': 'necropolis'}, {'x': 0, 'z': FZ + 1.6, 'r': 2.2, 'to': 'pyramid'},
              {'x': 0, 'z': 60, 'r': 2.2, 'to': 'sky', 'requires': 'pyrEscaped'}]   # 太陽の門（秘宝を持ち帰ると開く）
M['enemies'] = [{'type': 'bandit', 'x': -30, 'z': 20}, {'type': 'bandit', 'x': 30, 'z': 44}, {'type': 'bandit', 'x': 46, 'z': -4}]
M['chests'] = [{'x': 46, 'z': 12, 'ankh': 180}, {'x': -46, 'z': 70, 'ankh': 160}]
M['waters'] = []
M['beams'] = []
M['exposureMul'] = 0.72   # 白い砂がまぶしすぎないように

L.bake_and_export()

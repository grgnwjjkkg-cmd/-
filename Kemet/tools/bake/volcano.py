"""炎の山（火の女神セクメトの山）：黒い玄武岩の台地、溶岩の川（跳んで越える）、段々の岩棚（跳んで上る）、
山の中腹に彫られたセクメト神殿（中は溶岩の光と、ときどき噴き出す炎）。
使い方（Kemet/ で）:
  blender -b --python tools/bake/volcano.py -- [samples]
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from lib import Level, B

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
SAMPLES = int(argv[0]) if argv else 160
random.seed(51)
L = Level('volcano', SAMPLES)
STAND = os.path.join(os.path.dirname(__file__), 'models', 'statue_standing.obj')

L.material('basalt', 'dark_rock', (0.55, 0.5, 0.48), scale=5)
L.material('basalt2', 'dark_rock_02', (0.6, 0.55, 0.52), scale=4)
L.material('ash', 'aerial_sand', (0.3, 0.28, 0.27), scale=10)
L.material('carved', 'granite_wall', (0.42, 0.34, 0.32), scale=4)
L.material('temple', 'sandstone_blocks_08', (0.5, 0.42, 0.38), scale=2.5)
L.emission('lava', (1.0, 0.36, 0.08), 14.0)
L.emission('crust', (0.8, 0.18, 0.04), 3.0)
L.emission('summit', (1.0, 0.42, 0.12), 30.0)

L.group('ground', 4096)
L.group('temple', 2048)
L.group('far', 1024)
M = L.meta
M['hazards'] = []


def ashland(x, z):
    k = max(0.0, min(1.0, max(abs(x) - 92, z - 84, -64 - z) / 30))   # 遊ぶ所は平ら、外は灰の丘
    if abs(x) < 14 and -99 < z < -60: k = 0.0                          # 山の中の神殿の床に丘が出ないように
    if abs(x) < 14 and -99 < z < -60: return -0.3
    return k * (6 * math.sin(x * 0.05 + 1) * math.sin(z * 0.04) + 5) + 0.25 * math.sin(x * 0.4) * math.sin(z * 0.35) * (1 - k) - 0.05


L.terrain('ground', 'ash', -130, 130, -150, 110, 80, 80, ashland)
L.terrain('far', 'ash', -1500, 1500, -1500, 1500, 48, 48, lambda x, z: ashland(x, z) - 0.6 + 12 * min(1, max(0, (math.hypot(x, z) - 200) / 300)) * math.sin(x * 0.006) * math.sin(z * 0.005 + 1))


# ---------- 溶岩の川（地面より少し低い光る帯。上に立つとやけど） ----------
def lava_river(pts, w):
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        cx, cz, ln = (x0 + x1) / 2, (z0 + z1) / 2, math.hypot(x1 - x0, z1 - z0)
        ang = math.atan2(x1 - x0, z1 - z0)
        L.box('ground', 'lava', (cx, 0.02, cz), (w, 0.1, ln + w), rot=ang, collide=False)
        for s in (-1, 1):   # 冷えて固まったふち
            ox, oz = math.cos(ang) * s * (w / 2 + 0.25), -math.sin(ang) * s * (w / 2 + 0.25)
            L.box('ground', 'crust', (cx + ox, 0.1, cz + oz), (0.5, 0.2, ln + w), rot=ang, collide=False)
        M['hazards'].append({'kind': 'lava', 'seg': [x0, z0, x1, z1], 'w': w, 'y': 0.4, 'dmg': 18})   # 帯の上に立つとやけど


lava_river([(-90, 40), (-40, 30), (0, 34), (40, 26), (90, 32)], 3.0)      # 1本目（跳んで越える）
lava_river([(-90, -8), (-50, -4), (-10, -10), (30, -4), (90, -12)], 3.2)   # 2本目
for i, (x, z) in enumerate(((-20, 10), (18, 14), (-34, -24), (28, -26))):   # 溶岩のたまり
    L.cyl('ground', 'lava', x, z, -0.05, 0.1, 3.2, 3.2, collide=False)
    L.cyl('ground', 'crust', x, z, -0.05, 0.25, 3.8, 3.6, collide=False)
    M['hazards'].append({'kind': 'lava', 'box': [x - 3, x + 3, z - 3, z + 3], 'y': 0.4, 'dmg': 18})
    L.point((x, 1.5, z), 900, (1.0, 0.4, 0.1), torch=False)

# ---------- 玄武岩の柱と岩棚（跳んで上る） ----------
for i in range(40):   # 六角柱の玄武岩（柱状節理）
    x, z = random.uniform(-70, 70), random.uniform(-60, 60)
    if abs(x) < 8 or any(abs(z - zz) < 6 for zz in (32, -6)): continue
    h = random.uniform(1.5, 7)
    L.cyl('ground', 'basalt2', x, z, 0, h, 1.1, 1.0, seg=6)
for (x0, x1, z0, z1, top) in ((-24, -10, -44, -34, 1.2), (-10, 4, -52, -42, 2.4), (4, 16, -60, -50, 3.6)):   # 神殿へ上る段
    L.box('ground', 'basalt', ((x0 + x1) / 2, top / 2, (z0 + z1) / 2), (x1 - x0, top, z1 - z0), collide=False)
    L.platform(x0, x1, z0, z1, top)

# ---------- 山と神殿（中腹に彫られた入口） ----------
L.cyl('far', 'basalt', 0, -460, -2, 260, 200, 34, seg=48, collide=False)     # 遠くの火山（ふもとの半径200m・高さ260m）
L.cyl('far', 'summit', 0, -460, 256, 5, 34, 32, seg=48, collide=False)      # 光る火口
for i in range(9):                                                           # 山肌を流れ落ちる溶岩（山の斜面にそって）
    a = math.radians(-50 + i * 12.5)
    x0, z0 = math.sin(a) * 36, -460 + math.cos(a) * 36
    x1, z1 = math.sin(a) * 196, -460 + math.cos(a) * 196
    bm = L.bm('far', 'lava'); w = 2.5
    ox, oz = math.cos(a) * w, -math.sin(a) * w
    v = [bm.verts.new(B(*p)) for p in ((x0 - ox, 255, z0 - oz), (x0 + ox, 255, z0 + oz), (x1 + ox * 2.5, 2, z1 + oz * 2.5), (x1 - ox * 2.5, 2, z1 - oz * 2.5))]
    for q in v: q.co += (q.co - B(0, q.co.z, -460)).normalized() * 0.6
    bm.faces.new(v)
L.cliff('ground', 'basalt', -90, 90, -64, lambda x: 34 + 8 * math.sin(x * 0.05) + 3 * math.sin(x * 0.17), step=1.2, seed=7, holes=[(-5, 5, 13)])
L.box('temple', 'carved', (0, 11, -63.6), (20, 22, 1.6), collide=False)       # 神殿の正面（岩に彫った壁）
for sx in (-1, 1):
    L.box('temple', 'carved', (sx * 7.5, 1.0, -61), (4, 2, 4))
    L.mesh_file('temple', 'carved', STAND, (sx * 7.5, 2.0, -61), scale=8)      # 女神の立ち像
L.box('temple', 'lava', (0, 15.5, -62.7), (6, 0.5, 0.2), collide=False)        # 入口の上に燃える帯
# 神殿の中の広間
L.box('temple', 'temple', (0, -0.1, -80), (22, 0.2, 30), collide=False)
L.box('temple', 'temple', (0, 12.2, -80), (24, 0.4, 32), collide=False)
for sx in (-1, 1):
    L.box('temple', 'temple', (sx * 11.5, 6, -80), (1, 12, 30))
    for z in (-70, -80, -90):
        L.cyl('temple', 'carved', sx * 6, z, 0, 12, 1.1, 1.0)
L.box('temple', 'temple', (0, 6, -95.5), (24, 12, 1))
L.box('temple', 'lava', (0, 0.05, -80), (3, 0.1, 22), collide=False)            # 床を流れる溶岩の溝（跳んで渡る）
M['hazards'].append({'kind': 'lava', 'box': [-1.5, 1.5, -91, -69], 'y': 0.4, 'dmg': 18})
L.box('temple', 'carved', (0, 1.2, -92), (4, 2.4, 2))                         # 祭壇
M['jets'] = [{'x': sx * 4, 'z': z, 'period': 3.2, 'offset': i * 0.8} for i, (sx, z) in enumerate(((-1, -72), (1, -78), (-1, -84), (1, -88)))]
for p in [(-10, 4, -70), (10, 4, -70), (-10, 4, -88), (10, 4, -88)]: L.point(p, 150)
L.point((0, 1, -80), 800, (1.0, 0.4, 0.1), torch=False)

# ---------- 光（煙で赤くくすんだ夕方） ----------
L.sky('goegap.hdr', strength=0.35, rotation=math.radians(200))
L.sun(elevation=14, azimuth=20, energy=3.0, color=(1.0, 0.45, 0.25))

# ---------- ゲーム用 ----------
C = M['colliders']['boxes']
C += [[-95, -90, -70, 80], [90, 95, -70, 80], [-95, 95, 76, 82]]
C.remove([-95, 95, 76, 82]); C += [[-95, -4, 76, 82], [4, 95, 76, 82]]
M['regions'] = [
    {'name': 'volcano', 'box': [-2000, 2000, -64, 2000], 'kind': 'ember', 'music': 'desert'},
    {'name': 'sekhmet', 'box': [-12, 12, -96, -64], 'kind': 'indoor', 'music': 'tomb'},
]
M['spawns'] = {'default': {'x': 0, 'z': 70, 'face': math.pi}, 'sky': {'x': 0, 'z': 70, 'face': math.pi}}
M['exits'] = [{'x': 0, 'z': 78, 'r': 2.6, 'to': 'sky'}]
M['enemies'] = [{'type': 'mummy', 'x': -20, 'z': 20}, {'type': 'mummy', 'x': 22, 'z': 2}, {'type': 'bandit', 'x': -10, 'z': -30},
                {'type': 'mummy', 'x': 6, 'z': -76}, {'type': 'guardian', 'x': 0, 'z': -88}]
M['chests'] = [{'x': 10, 'z': -56, 'ankh': 400}, {'x': -8, 'z': -92, 'ankh': 700}]
M['waters'] = []
M['beams'] = []
M['exposureMul'] = 1.0

L.bake_and_export()

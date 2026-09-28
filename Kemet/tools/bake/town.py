"""町「メンネフェル」：北に神殿、中央に市場と井戸、東にナイルと船着き場、西に城壁と西門。
動かない建物だけを焼き付ける（ヤシ・屋台の布・壺・門の扉・川の水面はゲーム側で置く）。
使い方（Kemet/ で）:
  blender -b --python tools/bake/town.py -- [samples]
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from lib import Level

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
SAMPLES = int(argv[0]) if argv else 160
random.seed(5)
L = Level('town', SAMPLES)

L.material('sand', 'coast_sand_01', (1.0, 0.93, 0.8), scale=4)
L.material('pave', 'red_sandstone_pavement', (0.85, 0.78, 0.66), scale=3)
L.material('blocks', 'large_sandstone_blocks_01', scale=3)
L.material('stone', 'sandstone_blocks_08', scale=2.5)
L.material('plaster', 'clay_plaster', (1.0, 0.92, 0.8), scale=3)
L.material('whitewash', 'beige_wall_001', (1.0, 0.97, 0.9), scale=3)
L.material('rose', 'clay_plaster', (1.0, 0.8, 0.68), scale=3)
L.material('wood', 'brown_planks_09', (0.8, 0.7, 0.6), scale=2)
L.material('dark', 'sandstone_blocks_08', (0.08, 0.06, 0.05), scale=3)
L.material('pyr', 'sandstone_blocks_08', (1.0, 0.9, 0.75), scale=12)
L.material('cliff', 'rock_face_02', (0.95, 0.82, 0.66), scale=6)

L.group('ground', 4096)
L.group('city', 4096)
L.group('temple', 2048)
L.group('far', 1024)

# ---------- 地面 ----------
def dune(x, z):
    k = max(0.0, min(1.0, (max(abs(x + 3) - 60, abs(z + 10) - 75)) / 30))
    h = 2.6 * math.sin(x * 0.06 + 1) + 1.8 * math.sin(z * 0.08 + x * 0.03) + 3.0
    return h * k - 0.03
L.terrain('ground', 'sand', -110, 44, -120, 90, 60, 70, dune)
L.box('ground', 'pave', (0, 0.0, 0), (40, 0.1, 40), collide=False)           # 市場の石畳
L.box('ground', 'pave', (0, 0.0, -5), (8, 0.08, 90), collide=False)           # 大通り
L.box('ground', 'pave', (0, 0.02, -56), (26, 0.1, 30), collide=False)         # 神殿の中庭

# ---------- 城壁と西門 ----------
def wall(x1, z1, x2, z2, h=6, t=1.6, mat='plaster'):
    cx, cz, ln = (x1 + x2) / 2, (z1 + z2) / 2, math.hypot(x2 - x1, z2 - z1)
    if abs(x2 - x1) < 0.01:
        L.box('city', mat, (cx, h / 2, cz), (t, h, ln)); L.box('city', 'whitewash', (cx, h + 0.2, cz), (t + 0.3, 0.4, ln), collide=False)
    else:
        L.box('city', mat, (cx, h / 2, cz), (ln, h, t)); L.box('city', 'whitewash', (cx, h + 0.2, cz), (ln, 0.4, t + 0.3), collide=False)
wall(-50, -75, -50, -3.4); wall(-50, 3.4, -50, 55); wall(-50, 55, 36, 55); wall(-50, -75, 36, -75)
for s in (-1, 1):
    L.box('city', 'blocks', (-50, 4, s * 5.4), (4, 8, 4))
    L.box('city', 'stone', (-50, 8.2, s * 5.4), (4.4, 0.4, 4.4), collide=False)
L.box('city', 'stone', (-50, 6.6, 0), (2.2, 1.2, 7.2), collide=False)     # 門の上の梁

# ---------- 神殿 ----------
tw, td, th = 11.2, 5, 14
for s in (-1, 1):
    L.tbox('temple', 'blocks', (s * (14 - tw / 2), th / 2, -38), (tw, th, td), taper=0.82)
    L.box('temple', 'stone', (s * (14 - tw / 2), th + 0.3, -38), (tw * 0.86, 0.6, td * 0.95), collide=False)
    L.box('temple', 'stone', (s * 3.2, 2.5, -38), (0.8, 5, 4))
L.box('temple', 'blocks', (0, 7.5, -38), (6.8, 5, 4), collide=False)
L.box('temple', 'stone', (0, 10.3, -38), (7.4, 0.8, 4.5), collide=False)
for x in (-9, 9):   # オベリスク
    L.tbox('temple', 'stone', (x, 7.1, -31), (1.2, 13, 1.2), taper=0.6)
    L.box('temple', 'stone', (x, 0.3, -31), (2.2, 0.6, 2.2))
for z in (-46, -52, -58, -64):
    for x in (-7, 7):
        L.cyl('temple', 'stone', x, z, 0, 8, 0.72, 0.64)
        L.cyl('temple', 'stone', x, z, 8, 1.4, 0.64, 1.2, collide=False)
        L.box('temple', 'stone', (x, 9.6, z), (2.5, 0.4, 2.5), collide=False)
for x1, z1, x2, z2 in ((-13, -41, -13, -70), (13, -41, 13, -70), (-13, -70, 13, -70)):
    cx, cz, ln = (x1 + x2) / 2, (z1 + z2) / 2, math.hypot(x2 - x1, z2 - z1)
    if abs(x2 - x1) < 0.01: L.box('temple', 'blocks', (cx, 3.5, cz), (1.2, 7, ln))
    else: L.box('temple', 'blocks', (cx, 3.5, cz), (ln, 7, 1.2))
L.box('temple', 'stone', (0, 0.6, -66), (3, 1.2, 2))                     # 祭壇
L.box('temple', 'stone', (6, 0.2, -27), (3, 0.4, 3), collide=False)      # 神託の壺の台

# ---------- 井戸・家・船着き場 ----------
L.cyl('city', 'stone', 0, 0, 0, 0.9, 1.4, 1.3); L.cyl('city', 'stone', 0, 0, 0.9, 0.12, 1.45, 1.45, collide=False)

def house(x, z, w, d, h, rot=0.0, mat='plaster', upper=False):
    swap = abs(math.sin(rot)) > 0.5
    L.box('city', mat, (x, h / 2, z), (w, h, d), rot=rot)
    L.box('city', 'whitewash', (x, h + 0.17, z), (w + 0.3, 0.35, d + 0.3), rot=rot, collide=False)
    fx, fz = math.sin(rot), math.cos(rot)   # 正面の向き（ローカル +z）
    L.box('city', 'dark', (x + fx * (d / 2 + 0.02), 1.05, z + fz * (d / 2 + 0.02)), (1.1, 2.1, 0.1), rot=rot, collide=False)
    L.box('city', 'wood', (x + fx * (d / 2 + 0.05), 2.2, z + fz * (d / 2 + 0.05)), (1.5, 0.18, 0.12), rot=rot, collide=False)
    if w > 4:
        sx, sz = math.cos(rot), -math.sin(rot)
        for k in (-1, 1):
            L.box('city', 'dark', (x + fx * (d / 2 + 0.02) + sx * k * w / 3, h * 0.62, z + fz * (d / 2 + 0.02) + sz * k * w / 3), (0.6, 0.6, 0.1), rot=rot, collide=False)
    if upper:
        L.box('city', mat, (x, h + 1.2, z), (w * 0.55, 2.4, d * 0.6), rot=rot, collide=False)
        L.box('city', 'whitewash', (x, h + 2.5, z), (w * 0.55 + 0.25, 0.3, d * 0.6 + 0.25), rot=rot, collide=False)

houses = [
    (-26, 32, 8, 7, 4, 0, 'plaster', True), (-26, 18, 7, 6, 3.6, 0, 'plaster', False), (-28, 4, 9, 8, 4.2, math.pi / 2, 'plaster', False),
    (-26, -12, 8, 7, 4, 0, 'whitewash', True), (-34, -30, 10, 8, 4.5, 0, 'plaster', False), (-38, 20, 7, 7, 3.8, 0, 'rose', False),
    (26, 32, 8, 7, 4, 0, 'whitewash', False), (24, 18, 7, 6, 3.6, 0, 'plaster', True), (26, -18, 8, 8, 4.2, math.pi, 'plaster', False),
    (27, -32, 9, 7, 4, math.pi, 'rose', False), (-12, 38, 7, 6, 3.6, math.pi, 'plaster', True), (12, 40, 7, 7, 3.8, math.pi, 'plaster', False),
    (-40, -52, 12, 10, 5, 0, 'plaster', True), (-26, -60, 8, 8, 4, 0, 'whitewash', False), (28, -52, 10, 8, 4.2, 0, 'rose', True),
    (-38, 42, 9, 8, 4, 0, 'plaster', False), (-18, 48, 8, 5, 3.6, math.pi, 'plaster', False), (-26, -22, 7, 6, 4.4, math.pi / 2, 'blocks', False),
]
for h in houses: house(*h)

L.box('city', 'wood', (42, 0.2, 1), (8, 0.35, 5), collide=False)          # 船着き場
for x, z in ((38.5, -1.2), (38.5, 3.2), (45.5, -1.2), (45.5, 3.2)):
    L.cyl('city', 'wood', x, z, -0.5, 1.4, 0.15, 0.15, collide=False)
L.box('city', 'wood', (41, 0.25, 1.35), (0.9, 0.5, 0.9), collide=False)   # 漁師が座る木箱
L.box('ground', 'sand', (60, -0.8, 0), (40, 0.4, 260), collide=False)     # 川底

# ---------- 遠景 ----------
L.pyramid('far', 'pyr', -230, -60, 120, 77)
L.pyramid('far', 'pyr', -300, 60, 150, 96)
L.pyramid('far', 'pyr', -190, 120, 70, 45)
for i, z in enumerate(range(-120, 130, 14)):   # 対岸の崖
    L.rock('far', 'cliff', (150 + (i % 3) * 6, 6, z), (9, 12, 8), seed=200 + i, rough=0.3, subdiv=2)

# ---------- 光 ----------
L.sky('goegap.hdr', strength=1.0, rotation=math.radians(40))
L.sun(elevation=58, azimuth=320, energy=4.2, color=(1.0, 0.93, 0.8))

# ---------- ゲーム用 ----------
M = L.meta
C = M['colliders']['boxes']
C += [[44, 51, -120, 0 - 1.5], [44, 51, 3.5, 120], [46, 47, -1.5, 3.5],        # 川に入れない
      [-60, 60, 57, 63], [-60, 60, -83, -77], [-59, -53, -100, 100]]           # 町の外に出ない
M['gateBlock'] = [-48.5, -47.5, -3.5, 3.5]
M['regions'] = [
    {'name': 'town', 'box': [-120, 140, -130, 130], 'kind': 'outdoor', 'music': 'town'},
]
M['spawns'] = {'default': {'x': 0, 'z': 30, 'face': math.pi}, 'necropolis': {'x': -44, 'z': 0, 'face': math.pi / 2}}
M['exits'] = [{'x': -53, 'z': 0, 'r': 3, 'to': 'necropolis', 'requires': 'gateOpen'}]
M['enemies'] = []
M['chests'] = []
M['waters'] = []
M['beams'] = []

L.bake_and_export()

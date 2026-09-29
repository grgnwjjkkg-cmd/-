"""凍った北の果て（氷の神殿）：雪原、すべる凍った湖（ところどころ割れて冷たい水）、氷の崖、
氷の柱に閉じこめられたエジプトの神殿。空にはオーロラ（ゲーム側でかく）、雪が降る。
使い方（Kemet/ で）:
  blender -b --python tools/bake/ice.py -- [samples]
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from lib import Level, B

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
SAMPLES = int(argv[0]) if argv else 160
random.seed(61)
L = Level('ice', SAMPLES)
STAND = os.path.join(os.path.dirname(__file__), 'models', 'statue_standing.obj')
COL = os.path.join(os.path.dirname(__file__), 'models', 'colossus.obj')

L.material('snow', 'snow_02', (0.95, 0.97, 1.0), scale=4)
L.material('snowfield', 'snow_field_aerial', (0.92, 0.95, 1.0), scale=14)
L.material('ice', 'snow_02', (0.62, 0.82, 0.98), scale=2.5)            # 青い氷
L.material('lakeice', 'snow_02', (0.55, 0.72, 0.86), scale=8)
L.material('cliff', 'snow_02', (0.72, 0.82, 0.95), scale=7)   # 雪と氷におおわれた崖
L.material('stone', 'sandstone_blocks_08', (0.7, 0.72, 0.76), scale=2.5)
L.material('blocks', 'large_sandstone_blocks_01', (0.66, 0.68, 0.72), scale=3)
L.material('water', 'snow_02', (0.02, 0.05, 0.08), scale=4)
L.emission('glow', (0.45, 0.85, 1.0), 5.0)

L.group('ground', 4096)
L.group('temple', 2048)
L.group('far', 1024)
M = L.meta
M['hazards'] = []
M['slippery'] = []


def drifts(x, z):
    if abs(x) < 14 and -97 < z < -60: return -0.3                      # 崖の中の神殿の床に雪の丘が出ないように
    k = max(0.0, min(1.0, max(abs(x) - 86, z - 84, -70 - z) / 26))
    return k * (5 + 4 * math.sin(x * 0.05) * math.sin(z * 0.06 + 1)) + 0.3 * math.sin(x * 0.21 + z * 0.13) * (1 - k) + 0.1


L.terrain('ground', 'snow', -120, 120, -110, 120, 80, 80, drifts)
L.terrain('far', 'snowfield', -1500, 1500, -1500, 1500, 48, 48, lambda x, z: drifts(x, z) - 0.6 + 30 * min(1, max(0, (math.hypot(x, z) - 250) / 400)) * (0.5 + 0.5 * math.sin(x * 0.004) * math.sin(z * 0.006)))

# ---------- 凍った湖（すべる）と、割れた穴（冷たい水） ----------
L.box('ground', 'lakeice', (0, -0.03, 22), (90, 0.1, 30), collide=False)
M['slippery'].append([-45, 45, 7, 37])
for i, (x, z, r) in enumerate(((-22, 18, 3.2), (6, 28, 2.6), (24, 14, 3.4), (-6, 12, 2.2), (34, 30, 2.4))):
    L.cyl('ground', 'water', x, z, 0.025, 0.02, r, r, seg=20, collide=False)
    L.cyl('ground', 'ice', x, z, -0.02, 0.12, r + 0.4, r + 0.3, seg=20, collide=False)
    M['hazards'].append({'kind': 'cold', 'circle': [x, z, r - 0.3], 'y': 0.5, 'dmg': 12})
for i in range(18):   # 湖の上の氷のかけら
    x, z = random.uniform(-40, 40), random.uniform(9, 35)
    s = random.uniform(0.4, 1.2)
    L.rock('ground', 'ice', (x, s * 0.2, z), (s * 1.4, s * 0.5, s), seed=i, rough=0.25, subdiv=1)

# ---------- 氷の柱（結晶） ----------
for i in range(34):
    x, z = random.uniform(-80, 80), random.uniform(-40, 75)
    if abs(x) < 9 or (abs(x) < 46 and 5 < z < 39): continue
    h = random.uniform(3, 14)
    L.tbox('ground', 'ice', (x, h / 2, z), (random.uniform(1, 2.2), h, random.uniform(1, 2.2)), taper=random.uniform(0.1, 0.35))

# ---------- 北：氷の崖と、氷に閉じこめられた神殿 ----------
L.cliff('ground', 'cliff', -90, 90, -64, lambda x: 30 + 7 * math.sin(x * 0.06 + 2) + 3 * math.sin(x * 0.19), step=1.2, seed=9, holes=[(-5, 5, 12)])
for sx in (-1, 1):
    L.tbox('temple', 'blocks', (sx * 9, 9, -60), (10, 18, 4), taper=0.82)                    # 塔門
    L.box('temple', 'ice', (sx * 9, 9, -57.4), (11, 18.5, 1.2), collide=False)               # 表をおおう氷
    L.box('temple', 'stone', (sx * 16.5, 1.2, -52), (4, 2.4, 4))
    L.mesh_file('temple', 'stone', COL, (sx * 16.5, 2.4, -52), scale=7)                       # 座像
    L.tbox('temple', 'ice', (sx * 16.5, 7, -51.5), (6.5, 13, 6.5), taper=0.6, collide=False)  # 座像を包む氷
L.box('temple', 'blocks', (0, 14, -60), (8, 8, 4), collide=False)
# 神殿の中（氷の広間）
L.box('temple', 'lakeice', (0, -0.05, -78), (22, 0.1, 30), collide=False)
M['slippery'].append([-11, 11, -93, -63])
L.box('temple', 'ice', (0, 14.2, -78), (24, 0.4, 32), collide=False)
for sx in (-1, 1):
    L.box('temple', 'ice', (sx * 11.5, 7, -78), (1, 14, 30))
    for z in (-68, -78, -88):
        L.cyl('temple', 'stone', sx * 6, z, 0, 14, 1.0, 0.9)
        L.tbox('temple', 'ice', (sx * 6, 3, z), (2.8, 6, 2.8), taper=0.5, collide=False)
L.box('temple', 'ice', (0, 7, -93.5), (24, 14, 1))
L.box('temple', 'stone', (0, 1.2, -90), (4, 2.4, 2))
L.mesh_file('temple', 'stone', STAND, (0, 2.4, -91), scale=4.5)
L.box('temple', 'glow', (0, 6, -92.9), (5, 5, 0.1), collide=False)                      # 氷の奥で光る文字
for p in [(-10, 5, -68), (10, 5, -68), (-10, 5, -88), (10, 5, -88)]: L.point(p, 160, (0.55, 0.85, 1.0), torch=False)

# ---------- 光（白く冷たい、低い日ざし） ----------
L.sky('goegap.hdr', strength=0.5, rotation=math.radians(120))
L.sun(elevation=16, azimuth=300, energy=3.2, color=(0.85, 0.92, 1.0))

# ---------- ゲーム用 ----------
C = M['colliders']['boxes']
C += [[-95, -90, -70, 80], [90, 95, -70, 80], [-95, -4, 78, 84], [4, 95, 78, 84]]
M['regions'] = [
    {'name': 'ice', 'box': [-2000, 2000, -64, 2000], 'kind': 'frost', 'music': 'desert'},
    {'name': 'icetemple', 'box': [-12, 12, -94, -64], 'kind': 'indoor', 'music': 'tomb'},
]
M['spawns'] = {'default': {'x': 0, 'z': 70, 'face': math.pi}, 'sky': {'x': 0, 'z': 70, 'face': math.pi}}
M['exits'] = [{'x': 0, 'z': 78, 'r': 2.6, 'to': 'sky'}]
M['enemies'] = [{'type': 'mummy', 'x': -18, 'z': 52}, {'type': 'mummy', 'x': 20, 'z': 46}, {'type': 'mummy', 'x': 0, 'z': -30},
                {'type': 'bandit', 'x': -24, 'z': -20}, {'type': 'guardian', 'x': 0, 'z': -84}]
M['chests'] = [{'x': 40, 'z': -40, 'ankh': 450}, {'x': 8, 'z': -90, 'ankh': 700}]
M['waters'] = []
M['beams'] = []

L.bake_and_export()

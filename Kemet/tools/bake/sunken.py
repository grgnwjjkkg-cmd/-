"""海中遺跡：ナイル河口の海に沈んだ神殿の町（ヘラクレイオンのような）。
倒れた巨像、崩れた柱の列、沈んだ神殿の土台、壺の散らばる海底。上から光の筋が差しこむ。
使い方（Kemet/ で）:
  blender -b --python tools/bake/sunken.py -- [samples]
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from lib import Level, B

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
SAMPLES = int(argv[0]) if argv else 160
random.seed(31)
L = Level('sunken', SAMPLES)
COL = os.path.join(os.path.dirname(__file__), 'models', 'colossus.obj')

L.material('sand', 'coast_sand_01', (0.78, 0.8, 0.72), scale=4)
L.material('rock', 'cliff_side', (0.62, 0.64, 0.58), scale=5)
L.material('stone', 'sandstone_blocks_08', (0.78, 0.76, 0.66), scale=2.5)
L.material('blocks', 'large_sandstone_blocks_01', (0.72, 0.72, 0.62), scale=3)
L.material('granite', 'granite_wall', (0.55, 0.4, 0.38), scale=4)
L.material('clay', 'clay_plaster', (0.7, 0.45, 0.3), scale=1.5)
L.emission('glow', (0.4, 0.8, 1.0), 4.0)

L.group('bed', 4096)
L.group('ruins', 2048)


# ---------- 海底：砂の波もようと、まわりの岩の斜面
def seabed(x, z):
    r = math.hypot(x, z + 10)
    rim = max(0.0, (r - 70) / 25) ** 1.6 * 14                      # 遠くは岩の斜面で上がっていく
    ripple = 0.08 * math.sin(x * 1.3 + z * 0.4) + 0.05 * math.sin(x * 0.7 - z * 1.1)
    dune = 0.6 * math.sin(x * 0.08 + 1) * math.sin(z * 0.06) + 0.4 * math.sin(z * 0.11 + x * 0.03)
    k = min(1.0, max(0.0, (r - 20) / 30))                            # まん中の遺跡のあたりは平ら
    return ripple + dune * k + rim - 0.02


L.terrain('bed', 'sand', -130, 130, -140, 110, 90, 90, seabed)
for i in range(46):   # 遠くの岩場
    a = i / 46 * math.tau + random.uniform(-0.05, 0.05); r = random.uniform(78, 100)
    x, z = math.cos(a) * r, math.sin(a) * r - 10
    s = random.uniform(4, 9)
    L.rock('bed', 'rock', (x, seabed(x, z) + s * 0.3, z), (s * 1.3, s, s * 1.1), seed=i, rough=0.4)

# ---------- 沈んだ神殿の土台と、立ったままの柱・倒れた柱
L.box('ruins', 'blocks', (0, 0.4, -40), (30, 0.8, 26), collide=False)
for zi, z in enumerate(range(-50, -28, 6)):
    for xi, x in enumerate((-10, -4, 4, 10)):
        h = [7.5, 2.2, 5.0, 0.8, 6.5, 3.0, 1.4, 7.0][(zi * 4 + xi) % 8]
        L.cyl('ruins', 'stone', x, z, 0.8, h, 0.9, 0.85)
        if h > 6: L.box('ruins', 'stone', (x, 0.8 + h + 0.25, z), (2.4, 0.5, 2.4), collide=False)
for i, (x, z, ang) in enumerate(((-17, -30, 0.3), (15, -52, 1.2), (8, -20, 2.4), (-22, -52, 0.9))):   # 倒れた柱
    L.cyl('ruins', 'stone', x, z, 0.85, 8.0, 0.85, 0.85, collide=False, lying=ang)
    L.meta['colliders']['circles'] += [[x + math.cos(ang) * d, z - math.sin(ang) * d, 1.0] for d in (-2.5, 0, 2.5)]
# 神殿の奥の壁と大きな石碑
L.box('ruins', 'blocks', (0, 3.5, -54), (30, 7, 2))
L.box('ruins', 'granite', (0, 4.2, -52.4), (5, 8.4, 1.0))                         # 石碑
L.box('ruins', 'glow', (0, 5.0, -51.85), (3.2, 4.0, 0.05), collide=False)        # 光る文字（ここで石板を読む）

# ---------- 倒れた巨像（あお向けに倒れて、半分砂にうもれている）と、首の取れた頭
L.mesh_file('ruins', 'granite', COL, (26, -1.8, 8), rot=math.radians(-35), scale=9, tilt=math.radians(-78))
L.meta['colliders']['circles'] += [[26 + math.sin(math.radians(-35)) * d, 8 + math.cos(math.radians(-35)) * d, 3.2] for d in (-8, -3, 2, 7)]
L.mesh_file('ruins', 'granite', COL, (-30, -1.2, 18), rot=math.radians(120), scale=6.5, roll=math.radians(84))
L.meta['colliders']['circles'] += [[-30, 18, 3.5], [-26, 21, 3]]

# ---------- 大通り（スフィンクス通りの土台）と、両わきの台座
for z in range(-20, 50, 9):
    for sx in (-1, 1):
        L.box('ruins', 'stone', (sx * 7, 0.7, z), (2.6, 1.4, 4.2))
        if (z // 9) % 3 == 0: L.box('ruins', 'stone', (sx * 7, 2.0, z - 0.6), (1.6, 1.2, 1.6), collide=False)
# 散らばった壺
for i in range(40):
    x, z = random.uniform(-40, 40), random.uniform(-30, 55)
    if abs(x) < 9 or (x > 15 and z < 20 and z > -5): continue
    lying = random.random() < 0.6
    L.cyl('ruins', 'clay', x, z, seabed(x, z) + (0.3 if lying else 0), 0.9, 0.3, 0.12, seg=16, collide=False, lying=(random.uniform(0, 6.28) if lying else None))

# ---------- 光：水面からの青い光（太陽は真上寄り、水の色）
L.sky('goegap.hdr', strength=0.25, rotation=0)
L.sun(elevation=72, azimuth=20, energy=2.6, color=(0.55, 0.85, 1.0))
L.point((0, 5.0, -50), 300, (0.4, 0.8, 1.0), torch=False)

# ---------- ゲーム用
M = L.meta
C = M['colliders']['boxes']
C += [[-90, 90, 68, 74], [-90, 90, -94, -88], [-94, -88, -94, 74], [88, 94, -94, 74]]   # 岩場より外へは行かない
M['regions'] = [{'name': 'sunken', 'box': [-200, 200, -200, 200], 'kind': 'underwater', 'music': 'tomb'}]
M['spawns'] = {'default': {'x': 0, 'z': 58, 'face': math.pi}, 'town': {'x': 0, 'z': 58, 'face': math.pi}}
M['exits'] = [{'x': 0, 'z': 64, 'r': 2.4, 'to': 'town'}]
M['enemies'] = [{'type': 'mummy', 'x': -6, 'z': -40}, {'type': 'mummy', 'x': 12, 'z': -34}, {'type': 'bandit', 'x': -20, 'z': 10}]
M['chests'] = [{'x': -34, 'z': 26, 'ankh': 260}, {'x': 0, 'z': -48, 'ankh': 320}]
M['waters'] = []
M['beams'] = [[-12, -36, 22], [6, -18, 22], [18, 6, 22], [-8, 22, 22], [30, -30, 22], [-26, -10, 22]]

L.bake_and_export()

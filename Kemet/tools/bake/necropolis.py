"""西岸の墓地：明るい砂漠の遺跡 → 崖の墓（暗い）→ 浸水した柱の広間 → 洞窟 → 盗賊団の間
使い方（Kemet/ で）:
  blender -b --python tools/bake/necropolis.py -- [samples]
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from lib import Level

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
SAMPLES = int(argv[0]) if argv else 192
random.seed(11)
L = Level('necropolis', SAMPLES)

# ---------- 材質 ----------
L.material('sand', 'coast_sand_01', (1.0, 0.93, 0.8), scale=4)
L.material('cliff', 'rock_face_02', (0.98, 0.84, 0.66), scale=6)
L.material('carved', 'sandstone_blocks_08', (1.0, 0.9, 0.76), scale=9)   # 岩から彫り出した像
L.material('rock', 'rock_face_02', (0.78, 0.66, 0.54), scale=4)
L.material('blocks', 'large_sandstone_blocks_01', scale=3)
L.material('stone', 'sandstone_blocks_08', scale=2.5)
L.material('pave', 'red_sandstone_pavement', (0.78, 0.7, 0.58), scale=3)
L.material('pyr', 'large_sandstone_blocks_01', (0.86, 0.72, 0.55), scale=5)
L.emission('glow', (1.0, 0.85, 0.6), 6)

L.group('ext', 4096)    # 屋外（砂漠・遺跡・崖）
L.group('far', 1024)    # 遠景（ピラミッド）
L.group('tomb', 2048)   # 墓（入口・前室・浸水した広間）
L.group('cave', 2048)   # 洞窟
L.group('lair', 1024)   # 盗賊団の間

# ============================================================
# 屋外：南（z=110）から北の崖（z=-6）へ
# ============================================================
def dune(x, z):
    # 通り道（|x|<32）は平ら、外側は砂丘
    k = min(1.0, max(0.0, (abs(x) - 32) / 26))
    k2 = min(1.0, max(0.0, (z - 112) / 20))
    k = max(k, k2)
    h = 2.6 * math.sin(x * 0.07 + 1) + 1.8 * math.sin(z * 0.09 + x * 0.03) + 0.7 * math.sin(x * 0.21 - z * 0.13) + 3.2
    return h * k - 0.02

L.terrain('ext', 'sand', -80, 80, -14, 140, 64, 62, dune)

# 崖（北の壁）：地層の段がある一枚の岩壁。入口（x=0）のところに穴
def cliff_h(x):
    return 27 + 5 * math.sin(x * 0.07 + 1) + 2.5 * math.sin(x * 0.19 + 2) + 1.2 * math.sin(x * 0.53)
L.cliff('ext', 'cliff', -84, 84, -5.4, cliff_h, step=1.0, seed=3, holes=[(-2.3, 2.3, 8.3)])
# ふもとの落石
for i, x in enumerate(range(-76, 80, 9)):
    if abs(x) < 16: continue
    s_ = 1.2 + (i * 37 % 5) * 0.5
    L.rock('ext', 'cliff', (x + (i % 3), s_ * 0.4, -5.2 - (i % 2)), (s_ * 1.6, s_, s_ * 1.2), seed=40 + i, rough=0.35)
L.meta['colliders']['boxes'] += [[-84, -2.2, -16, -5.0], [2.2, 84, -16, -5.0]]

# 墓の入口（崖に彫られた門）：人の9倍の高さの座像が両わきに座る
for sx in (-1, 1):
    L.box('ext', 'blocks', (sx * 4.2, 8, -4.6), (4.4, 16, 1.6))                     # 門の両わき
    X = sx * 10.5
    L.box('ext', 'blocks', (X, 1.5, -4.6), (8.4, 3, 9))                             # 座像の台
    L.mesh_file('ext', 'carved', os.path.join(os.path.dirname(__file__), 'models', 'colossus.obj'), (X, 3.0, -3.6), scale=11.5)
L.box('ext', 'blocks', (0, 12.5, -4.6), (4.4, 7, 1.8), collide=False)               # まぐさ石
L.box('ext', 'stone', (0, 16.4, -4.4), (30, 0.9, 2.6), collide=False)               # 軒
L.box('ext', 'blocks', (0, 20, -4.9), (30, 6.4, 1.4), collide=False)                # 上の壁

# 崩れた神殿（西側）：石の床、折れた柱、倒れた柱、低い壁
L.box('ext', 'pave', (-20, 0.12, 55), (22, 0.25, 30), collide=False)
for zi, z in enumerate(range(44, 68, 6)):
    for xi, x in enumerate((-28, -12)):
        h = [12.5, 4.4, 14.0, 6.2, 2.2, 9.6, 13.2, 3.4][(zi * 2 + xi) % 8]
        L.cyl('ext', 'stone', x, z, 0.25, h, 1.25, 1.15)
        if h > 12: L.cyl('ext', 'stone', x, z, 0.25 + h, 1.2, 1.15, 1.8, collide=False); L.box('ext', 'stone', (x, 0.25 + h + 1.5, z), (3.8, 0.6, 3.8), collide=False)
L.cyl('ext', 'stone', -19, 60, 1.15, 9.0, 1.15, 1.15, collide=False, lying=0.4)
L.meta['colliders']['circles'] += [[-22.8, 58.2, 1.2], [-19, 60, 1.2], [-15.2, 61.8, 1.2]]
L.box('ext', 'blocks', (-31, 2.2, 55), (1.6, 4.4, 26))
L.box('ext', 'blocks', (-24, 0.9, 41.5), (12, 1.8, 1.2))
L.box('ext', 'blocks', (-9.5, 0.6, 67), (1.2, 1.2, 10))
# 神殿の奥の小さな祠（宝箱）
L.box('ext', 'blocks', (-20, 1.8, 68.5), (7, 3.6, 1.2))
L.box('ext', 'blocks', (-23, 1.8, 66), (1, 3.6, 5))
L.box('ext', 'blocks', (-17, 1.8, 66), (1, 3.6, 5))
L.box('ext', 'stone', (-20, 3.8, 66), (7.4, 0.5, 5.6), collide=False)
# 倒れたオベリスクと石のかたまり
L.box('ext', 'stone', (14, 1.2, 34), (2.4, 2.4, 20), rot=0.5)
L.meta['colliders']['circles'] += [[9.2, 25.6, 1.6], [11.6, 29.8, 1.6], [14, 34, 1.6], [16.4, 38.2, 1.6], [18.8, 42.4, 1.6]]
for i in range(26):
    x = random.choice([-1, 1]) * random.uniform(9, 30); z = random.uniform(8, 100)
    s = random.uniform(0.5, 1.6)
    if -32 < x < -8 and 40 < z < 70: continue
    L.rock('ext', 'rock', (x, s * 0.35, z), (s * 1.3, s * 0.8, s), seed=i + 20, collide=s > 0.9)
# 道の両わきの石の目印
for z in range(10, 100, 12):
    for sx in (-1, 1):
        L.box('ext', 'stone', (sx * 6, 1.6, z), (1.2, 3.2, 1.2), rot=0.0)

# 遠景のピラミッド
L.pyramid('far', 'pyr', 70, -330, 360, 230)      # 崖の向こうの大ピラミッド（崖の上に頭が見える）
L.pyramid('far', 'pyr', -420, 20, 300, 190)
L.pyramid('far', 'pyr', 440, 110, 260, 165)
L.pyramid('far', 'pyr', -260, 420, 160, 100)
# 地平線までつづく砂漠（ピラミッドが宙に浮かないように）
L.terrain('far', 'sand', -1600, 1600, -1600, 1600, 64, 64, lambda x, z: dune(x, z) - 0.4 + 6 * min(1, max(0, (math.hypot(x, z - 60) - 180) / 250)) * math.sin(x * 0.004 + 1) * math.sin(z * 0.005 + 2))

# ============================================================
# 墓の中（暗い）：入口通路 → 前室 → 通路 → 浸水した柱の広間
# ============================================================
H = 6.0
def room(group, x0, x1, z0, z1, h=H, mat='blocks', ceil='stone', floor='pave', holes=(), doors=()):
    """四角い部屋。doors=[('n'|'s'|'e'|'w', 中心, 幅)] の壁を空ける。holes=天井の穴[(x,z)]"""
    t = 1.0
    L.box(group, floor, ((x0 + x1) / 2, -0.15, (z0 + z1) / 2), (x1 - x0, 0.3, z1 - z0), collide=False)
    # 天井（穴をあけるため 2m ごとのタイル）
    step = 2.0
    x = x0
    while x < x1 - 1e-6:
        z = z1
        while z > z0 + 1e-6:
            cx, cz = x + step / 2, z - step / 2
            if not any(abs(cx - hx) < 1.0 and abs(cz - hz) < 1.0 for hx, hz in holes):
                L.box(group, ceil, (cx, h + 0.25, cz), (step, 0.5, step), collide=False)
            z -= step
        x += step
    def wall(side):
        gaps = sorted([(c - w / 2, c + w / 2) for s_, c, w in doors if s_ == side])
        if side in 'ns':
            a, b = x0 - t, x1 + t; zc = z0 - t / 2 if side == 'n' else z1 + t / 2
            cur = a
            for g0, g1 in gaps + [(b, b)]:
                if g0 > cur: L.box(group, mat, ((cur + g0) / 2, h / 2, zc), (g0 - cur, h, t))
                if g1 < b and g0 < b: L.box(group, mat, ((g0 + g1) / 2, (h + 4.4) / 2, zc), (g1 - g0, h - 4.4, t), collide=False)
                cur = g1
        else:
            a, b = z0, z1; xc = x1 + t / 2 if side == 'e' else x0 - t / 2
            cur = a
            for g0, g1 in gaps + [(b, b)]:
                if g0 > cur: L.box(group, mat, (xc, h / 2, (cur + g0) / 2), (t, h, g0 - cur))
                if g1 < b and g0 < b: L.box(group, mat, (xc, (h + 4.4) / 2, (g0 + g1) / 2), (t, h - 4.4, g1 - g0), collide=False)
                cur = g1
    for side in 'nsew': wall(side)

# 入口通路（崖の中）
room('tomb', -1.8, 1.8, -18, -5.2, h=8, doors=[('s', 0, 3.6), ('n', 0, 3.6)])
# 前室
room('tomb', -6, 6, -30, -18, h=11, doors=[('s', 0, 3.6), ('n', 0, 3.2)])
L.box('tomb', 'stone', (-4.2, 0.5, -27), (1.4, 1.0, 2.6))                  # 石棺
L.box('tomb', 'blocks', (-4.2, 1.1, -27), (1.5, 0.25, 2.7), collide=False)
# 通路
room('tomb', -1.6, 1.6, -38, -30, h=8, doors=[('s', 0, 3.2), ('n', 0, 3.2)])
# 浸水した柱の広間（天井の穴から日の光）
HALL = (-9, 9, -80, -38)
room('tomb', *HALL, h=15, holes=[(-3, -48), (3, -60), (-2, -71)], doors=[('s', 0, 3.2), ('e', -60, 3.6)])
for z in (-44, -52, -60, -68, -76):
    for x in (-4.5, 4.5):
        L.cyl('tomb', 'stone', x, z, 0.0, 12.8, 1.35, 1.2)
        L.cyl('tomb', 'stone', x, z, 12.7, 1.6, 1.2, 1.8, collide=False)
        L.box('tomb', 'stone', (x, 14.6, z), (3.8, 0.8, 3.8), collide=False)
for z in (-50, -66):
    L.box('tomb', 'stone', (7.2, 0.5, z), (1.4, 1.0, 2.6))
    L.box('tomb', 'blocks', (7.2, 1.1, z), (1.5, 0.25, 2.7), collide=False)
# 崩れた石（壁ぎわ）
for i in range(14):
    s = random.uniform(0.3, 0.7)
    L.box('tomb', 'blocks', (random.choice([-1, 1]) * random.uniform(7.4, 8.5), s / 2 - 0.05, random.uniform(-78, -40)), (s * 1.3, s, s), rot=0.0, collide=False)

# ============================================================
# 洞窟：広間の東の口 → 東へ → 北へ（天井の割れ目から光、地底の池）→ 盗賊団の間へ
# ============================================================
def cave_segment(x0, x1, z0, z1, seed):
    """四角い通路のまわりに岩を並べて洞窟にする（当たり判定は四角で）"""
    w = 1.2
    for (a, b), side in (((x0, x1), 'ns'),) if False else ():
        pass
    L.box('cave', 'rock', ((x0 + x1) / 2, -0.15, (z0 + z1) / 2), (x1 - x0, 0.3, z1 - z0), collide=False)
    rnd = random.Random(seed)
    # 壁と天井の岩
    if x1 - x0 > z1 - z0:  # 東西の通路
        for x in range(int(x0), int(x1) + 1, 3):
            for zc in (z0 - 1.2, z1 + 1.2):
                L.rock('cave', 'rock', (x + rnd.uniform(-1, 1), 2.2, zc), (2.4, 3.2, 1.8), seed=seed * 50 + x + int(zc), rough=0.35)
            L.rock('cave', 'rock', (x, 5.4, (z0 + z1) / 2), (2.6, 1.4, (z1 - z0) / 2 + 1.5), seed=seed * 70 + x, rough=0.3)
    else:
        for z in range(int(z0), int(z1) + 1, 3):
            for xc in (x0 - 1.2, x1 + 1.2):
                L.rock('cave', 'rock', (xc, 2.2, z + rnd.uniform(-1, 1)), (1.8, 3.2, 2.4), seed=seed * 50 + z + int(xc), rough=0.35)
            L.rock('cave', 'rock', ((x0 + x1) / 2, 5.4, z), ((x1 - x0) / 2 + 1.5, 1.4, 2.6), seed=seed * 70 - z, rough=0.3)

cave_segment(10, 32, -62.5, -57.5, 1)       # 東へ
cave_segment(27.5, 34.5, -100, -62.5, 2)    # 北へ（広い）
cave_segment(34.5, 52, -97.5, -92.5, 3)     # 東へ（盗賊団の間へ）
# 洞窟の当たり判定（通路の外側）
C = L.meta['colliders']['boxes']
C += [[10, 27.5, -66, -62.5], [10, 34.5, -57.5, -54], [34.5, 40, -92.5, -57.5], [24, 27.5, -104, -62.5],
      [27.5, 52, -104, -100], [34.5, 52, -92.5, -88]]
# 地底の池と割れ目
L.rock('cave', 'rock', (31, 0.1, -86), (2.2, 0.35, 3.2), seed=301, rough=0.2)

# ============================================================
# 盗賊団の間（たいまつで明るめ）
# ============================================================
room('lair', 52, 76, -106, -84, h=12, doors=[('w', -95, 4.6)])
for x in (58, 70):
    for z in (-90, -100):
        L.cyl('lair', 'stone', x, z, 0, 11.9, 1.1, 1.0)
for i in range(16):
    L.cyl('lair', 'stone', 56 + (i % 8) * 2.4, -104 + (i // 8) * 1.3, 0, 0.9 + (i % 3) * 0.25, 0.35, 0.28, seg=16, collide=False)
L.meta['colliders']['boxes'].append([55, 74, -105.8, -102])
L.box('lair', 'glow', (64, 0.3, -95), (1.2, 0.2, 1.2), collide=False)  # 焚き火

# ============================================================
# 光
# ============================================================
L.sky('goegap.hdr', strength=1.0, rotation=math.radians(40))
L.sun(elevation=62, azimuth=340, energy=4.2, color=(1.0, 0.93, 0.8))
# たいまつ
for p in [(-1.3, 2.8, -12), (-5.2, 3.0, -20), (5.2, 3.0, -28), (0, 3.0, -35),
          (-8.2, 3.2, -44), (8.2, 3.2, -56), (-8.2, 3.2, -68), (8.2, 3.2, -78),
          (15, 2.6, -58), (31, 2.6, -66), (29, 2.4, -97), (45, 2.6, -95),
          (53, 3.2, -88), (75, 3.2, -88), (53, 3.2, -102), (75, 3.2, -102)]:
    L.point(p, 110)
L.point((64, 1.2, -95), 400, (1.0, 0.5, 0.18), torch=False)  # 焚き火
L.area((31, 7.5, -75), 1.6, 3000, (1.0, 0.92, 0.78), (0, -1, 0))  # 洞窟の天井の割れ目からの光

# ============================================================
# ゲーム用の情報
# ============================================================
M = L.meta
M['waters'] = [{'x0': -9, 'x1': 9, 'z0': -80, 'z1': -38, 'y': 0.12}, {'x0': 28.5, 'x1': 33.5, 'z0': -90, 'z1': -82, 'y': 0.18}]
M['beams'] = [[-3, -48, 15], [3, -60, 15], [-2, -71, 15], [31, -75, 6]]
M['regions'] = [
    {'name': 'desert', 'box': [-90, 90, -5, 150], 'kind': 'outdoor', 'music': 'desert'},
    {'name': 'tomb', 'box': [-12, 10, -82, -5], 'kind': 'indoor', 'music': 'tomb'},
    {'name': 'cave', 'box': [10, 52, -106, -54], 'kind': 'cave', 'music': 'tomb'},
    {'name': 'lair', 'box': [52, 80, -108, -82], 'kind': 'indoor', 'music': 'tomb'},
]
M['spawns'] = {'town': {'x': 0, 'z': 104, 'face': math.pi}, 'default': {'x': 0, 'z': 104, 'face': math.pi}, 'giza': {'x': -23, 'z': 96, 'face': math.pi / 2}}
M['exits'] = [{'x': 0, 'z': 112, 'r': 3.5, 'to': 'town'}, {'x': -28, 'z': 96, 'r': 3, 'to': 'giza'}]   # 西の道はギザの台地へ
M['enemies'] = [
    {'type': 'bandit', 'x': -18, 'z': 50}, {'type': 'bandit', 'x': 8, 'z': 26},
    {'type': 'mummy', 'x': 3, 'z': -24}, {'type': 'mummy', 'x': 0, 'z': -50},
    {'type': 'mummy', 'x': -3, 'z': -64}, {'type': 'mummy', 'x': 3, 'z': -74},
    {'type': 'mummy', 'x': 22, 'z': -60}, {'type': 'mummy', 'x': 31, 'z': -80},
    {'type': 'bandit', 'x': 60, 'z': -92}, {'type': 'bandit', 'x': 68, 'z': -98},
    {'type': 'jackal', 'x': 64, 'z': -100, 'boss': True},
]
M['chests'] = [{'x': -20, 'z': 66, 'ankh': 120}, {'x': 4, 'z': -20, 'ankh': 150}, {'x': 33.5, 'z': -93, 'ankh': 220}, {'x': 72, 'z': -104, 'ankh': 300}]
M['scarab'] = {'x': 64, 'z': -103}

L.meta['sink'] = [[-60, 110, -160, -4, -10]]   # 遠景の地面を地下の部屋の下へ沈める（ゲーム側）
L.bake_and_export()

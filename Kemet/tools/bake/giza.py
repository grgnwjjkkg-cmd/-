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

L.material('sand', 'coast_sand_01', (0.86, 0.77, 0.62), scale=4)
L.material('bed', 'aerial_sand', (0.95, 0.84, 0.68), scale=18)
L.material('courses', 'large_sandstone_blocks_01', (0.95, 0.84, 0.66), scale=4)   # ピラミッドの石の段
L.material('casing', 'sandstone_blocks_08', (1.0, 0.94, 0.82), scale=6)            # 上に残る化粧石
L.material('blocks', 'large_sandstone_blocks_01', (0.9, 0.8, 0.64), scale=3)
L.material('stone', 'sandstone_blocks_08', (0.95, 0.86, 0.72), scale=2.5)
L.material('rock', 'cliff_side', (0.95, 0.82, 0.66), scale=5)
L.material('dark', 'sandstone_blocks_08', (0.02, 0.015, 0.01), scale=3)

L.material('blk1', 'large_sandstone_blocks_01', (1.0, 0.86, 0.66), scale=1.8)   # 石1個ずつ（色のちがう石を混ぜる）
L.material('blk2', 'large_sandstone_blocks_01', (0.92, 0.79, 0.6), scale=2.1)
L.material('blk3', 'sandstone_blocks_08', (0.98, 0.86, 0.68), scale=1.6)
L.material('blk4', 'large_sandstone_blocks_01', (0.8, 0.68, 0.52), scale=1.8)
L.group('pyrnear', 4096)
L.group('pyr', 4096)
L.group('ground', 2048)
L.group('far', 1024)


# ---------- 地面：台地は平ら、外は砂丘と岩盤
def dune(x, z):
    k = max(0.0, min(1.0, (max(abs(x) - 75, z - 100, -70 - z) + 5) / 30))   # ピラミッドの前は平ら（下はピラミッドに隠れる）
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
DETAIL = 22                                          # 下から何段を、石1個ずつで作るか（近くで見える所）
BLOCK_MATS = ['blk1', 'blk1', 'blk2', 'blk2', 'blk3', 'blk4']


def block_skin(cx, cz, base, height, course=1.25, n_detail=DETAIL, hole=None):
    """下の段を本物のように石1個ずつで積む。石は長さ・奥行き・高さがばらばらで、角が風化して丸く欠け、ところどころ抜け落ちている。
    見える面だけ作る（前・上・両はし・欠けた角）。奥には段の芯があり、抜けた石の穴は暗くくぼむ。"""
    n = int(height / course); inset = base / 2 / n
    for i in range(n_detail):
        s0 = base / 2 - inset * i; y0 = i * course
        for side in range(4):
            a = side * math.pi / 2; ca, sa = math.cos(a), math.sin(a)
            def P(u, v, y):   # u：面にそった位置、v：内側への深さ → ゲーム座標
                x, z = u, s0 - v
                return B(cx + x * ca - z * sa, y, cz + x * sa + z * ca)
            u = -s0
            while u < s0 - 0.4:
                ln = min(random.uniform(1.2, 2.7), s0 - u)
                if ln < 0.5: break
                gap = random.uniform(0.02, 0.07)
                u0, u1 = u + gap, u + ln - gap
                u += ln
                mid = (u0 + u1) / 2
                if hole and side == 0 and abs(mid - hole[0]) < hole[1] and y0 < hole[2]: continue    # 盗掘者の穴
                if random.random() < (0.045 if i < 12 else 0.025): continue                          # 抜け落ちた石
                h = course * random.uniform(0.9, 0.99)
                y1 = y0 + h
                out = random.uniform(-0.14, 0.04)          # 前へ出たり引っこんだり
                dep = random.uniform(1.3, 2.1)
                ch = random.uniform(0.06, 0.32) if random.random() < 0.8 else random.uniform(0.35, 0.6)   # 上の角の欠け
                j = lambda: random.uniform(-0.04, 0.04)
                bm = L.bm('pyrnear', random.choice(BLOCK_MATS))
                v = lambda uu, vv, yy: bm.verts.new(P(uu + j(), vv, yy))
                fl0, fl1 = v(u0, out + j(), y0), v(u1, out + j(), y0)                              # 前・下
                fm0, fm1 = v(u0, out + j() + ch * 0.25, y1 - ch), v(u1, out + j() + ch * 0.25, y1 - ch)   # 前・欠けの下
                ft0, ft1 = v(u0 + ch * 0.2, out + ch + j(), y1), v(u1 - ch * 0.2, out + ch + j(), y1)   # 上・欠けの奥
                bt0, bt1 = v(u0, dep, y1), v(u1, dep, y1)                                          # 上・奥
                bb0, bb1 = v(u0, dep, y0), v(u1, dep, y0)
                ctr = P(mid, dep * 0.5, (y0 + y1) / 2)
                for f in ((fl0, fl1, fm1, fm0), (fm0, fm1, ft1, ft0), (ft0, ft1, bt1, bt0),
                          (fl0, fm0, ft0, bt0, bb0), (fl1, bb1, bt1, ft1, fm1)):
                    try: face = bm.faces.new(f)
                    except ValueError: continue
                    face.normal_update()
                    if face.normal.dot(face.calc_center_median() - ctr) < 0: face.normal_flip()   # 外向きにそろえる


# 芯：下の段は石の後ろ（1.6m 内側）、上は今までどおりの段
def core(cx, cz, base, height, course=1.25, n_detail=DETAIL):
    bm = L.bm('pyr', 'courses')
    n = int(height / course); inset = base / 2 / n
    for i in range(n):
        back = 1.6 if i < n_detail else 0.0
        s0 = base / 2 - inset * i - back; s1 = base / 2 - inset * (i + 1) - (1.6 if i + 1 < n_detail else 0.0)
        y0, y1 = i * course, (i + 1) * course
        sq = lambda hh, y: [bm.verts.new(B(cx + dx * hh, y, cz + dz * hh)) for dx, dz in ((-1, 1), (1, 1), (1, -1), (-1, -1))]
        lo, hi, inner = sq(s0, y0), sq(s0, y1), sq(max(s1, 0.01), y1)
        for k in range(4):
            q = (k + 1) % 4
            bm.faces.new((lo[k], lo[q], hi[q], hi[k]))
            if s1 != s0: bm.faces.new((hi[k], hi[q], inner[q], inner[k]))
    L.meta['colliders']['boxes'].append([cx - base / 2, cx + base / 2, cz - base / 2, cz + base / 2])


core(GP['cx'], GP['cz'], GP['base'], GP['h'])
block_skin(GP['cx'], GP['cz'], GP['base'], GP['h'], hole=(0, 3.4, 8.5))
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

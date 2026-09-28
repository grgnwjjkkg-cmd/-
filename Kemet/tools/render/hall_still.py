"""映画CG並みの計算（Cycles のパストレーシング）で、浸水した柱の広間を1枚描く見本。
使い方（Kemet/ で）:
  blender -b --python tools/render/hall_still.py -- [samples] [out.png] [width] [height]
"""
import bpy, bmesh, math, os, sys, random
from mathutils import Vector, noise

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
SAMPLES = int(argv[0]) if len(argv) > 0 else 256
OUT = argv[1] if len(argv) > 1 else '/tmp/hall_still.png'
W = int(argv[2]) if len(argv) > 2 else 1600
H = int(argv[3]) if len(argv) > 3 else 740
TEX = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'Game', 'assets', 'tex'))
random.seed(4)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.samples = SAMPLES
sc.cycles.use_denoising = True
sc.cycles.max_bounces = 8
sc.cycles.volume_bounces = 1
sc.render.resolution_x, sc.render.resolution_y = W, H
sc.view_settings.view_transform = 'AgX'
sc.view_settings.look = 'AgX - Medium High Contrast'
sc.view_settings.exposure = 0.6

# ---------- 材質 ----------
def pbr(name, tex_id, tint=(1, 1, 1), scale=3.0, rough_mul=1.0, disp=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes['Principled BSDF']
    tc = nt.nodes.new('ShaderNodeTexCoord'); mp = nt.nodes.new('ShaderNodeMapping')
    mp.inputs['Scale'].default_value = (1 / scale, 1 / scale, 1 / scale)
    nt.links.new(tc.outputs['Object'], mp.inputs['Vector'])
    def img(kind, color=True):
        t = nt.nodes.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(os.path.join(TEX, f'{tex_id}_{kind}.jpg'))
        t.projection = 'BOX'; t.projection_blend = 0.25
        if not color: t.image.colorspace_settings.name = 'Non-Color'
        nt.links.new(mp.outputs['Vector'], t.inputs['Vector'])
        return t
    d = img('diff'); r = img('rough', False); n = img('nor', False)
    mix = nt.nodes.new('ShaderNodeMixRGB'); mix.blend_type = 'MULTIPLY'; mix.inputs['Fac'].default_value = 1
    mix.inputs['Color2'].default_value = (*tint, 1)
    nt.links.new(d.outputs['Color'], mix.inputs['Color1']); nt.links.new(mix.outputs['Color'], b.inputs['Base Color'])
    rm = nt.nodes.new('ShaderNodeMath'); rm.operation = 'MULTIPLY'; rm.inputs[1].default_value = rough_mul
    nt.links.new(r.outputs['Color'], rm.inputs[0]); nt.links.new(rm.outputs['Value'], b.inputs['Roughness'])
    nm = nt.nodes.new('ShaderNodeNormalMap'); nm.inputs['Strength'].default_value = 1.2
    nt.links.new(n.outputs['Color'], nm.inputs['Color']); nt.links.new(nm.outputs['Normal'], b.inputs['Normal'])
    return m

M = {
    'wall': pbr('wall', 'large_sandstone_blocks_01', (0.95, 0.85, 0.72)),
    'pillar': pbr('pillar', 'sandstone_blocks_08', (0.92, 0.82, 0.68), 2.5),
    'floor': pbr('floor', 'red_sandstone_pavement', (0.7, 0.62, 0.52), 3, 0.6),
    'ceil': pbr('ceil', 'sandstone_blocks_08', (0.55, 0.48, 0.4)),
    'sand': pbr('sand', 'coast_sand_01', (0.9, 0.8, 0.64), 3),
    'rock': pbr('rock', 'rock_face_02', (0.8, 0.7, 0.58), 3),
}
water = bpy.data.materials.new('water'); water.use_nodes = True
wb = water.node_tree.nodes['Principled BSDF']
wb.inputs['Base Color'].default_value = (0.35, 0.42, 0.33, 1); wb.inputs['Roughness'].default_value = 0.03
wb.inputs['Transmission Weight'].default_value = 1.0; wb.inputs['IOR'].default_value = 1.33
# 水面のさざ波
wn = water.node_tree
nz = wn.nodes.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = 3.0; nz.inputs['Detail'].default_value = 4
bump = wn.nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = 0.08
wn.links.new(nz.outputs['Fac'], bump.inputs['Height']); wn.links.new(bump.outputs['Normal'], wb.inputs['Normal'])
# 濁った水の中
vol = wn.nodes.new('ShaderNodeVolumeAbsorption'); vol.inputs['Color'].default_value = (0.35, 0.45, 0.3, 1); vol.inputs['Density'].default_value = 1.2
wn.links.new(vol.outputs['Volume'], wn.nodes['Material Output'].inputs['Volume'])

# ---------- 形 ----------
objs = []
def obj_from(bm, name, mat, bevel=0.0, smooth=False):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); sc.collection.objects.link(o); me.materials.append(mat)
    for p in me.polygons: p.use_smooth = smooth
    if bevel:
        mod = o.modifiers.new('bevel', 'BEVEL'); mod.width = bevel; mod.segments = 2; mod.limit_method = 'ANGLE'
    return o

def box(mat, c, s, bevel=0.03, chip=0.0, name='box'):
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1)
    for v in bm.verts:
        v.co = Vector((c[0] + v.co.x * s[0], c[1] + v.co.y * s[1], c[2] + v.co.z * s[2]))
    o = obj_from(bm, name, M[mat], bevel)
    if chip:  # 欠け・摩耗：ノイズで少しゆがめる
        o.modifiers.new('sub', 'SUBSURF').levels = 2
        d = o.modifiers.new('disp', 'DISPLACE'); tx = bpy.data.textures.new('chip', 'VORONOI'); tx.noise_scale = 0.35
        d.texture = tx; d.strength = chip; d.mid_level = 0.9
    return o

def cyl(mat, x, y, z0, h, r1, r2, chip=0.05):
    bm = bmesh.new(); bmesh.ops.create_cone(bm, cap_ends=True, segments=48, radius1=r1, radius2=r2, depth=h)
    for v in bm.verts: v.co += Vector((x, y, z0 + h / 2))
    o = obj_from(bm, 'col', M[mat], 0.04, smooth=True)
    if chip:
        o.modifiers.new('sub', 'SUBSURF').levels = 1
        d = o.modifiers.new('disp', 'DISPLACE'); tx = bpy.data.textures.new('ch', 'CLOUDS'); tx.noise_scale = 0.4
        d.texture = tx; d.strength = chip
    return o

def mound(mat, c, r, h, seed):
    """砂だまり・がれきの山：つぶれた玉をノイズでゆがめる"""
    bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=4, radius=1)
    o = Vector((seed * 3.1, seed * 1.7, 0))
    for v in bm.verts:
        d = v.co.normalized(); k = 1 + 0.25 * noise.noise(d * 2 + o)
        v.co = Vector((c[0] + d.x * r[0] * k, c[1] + d.y * r[1] * k, c[2] + max(-0.2, d.z) * h * k))
    return obj_from(bm, 'mound', M[mat], smooth=True)

Wd, L, Ht = 18.0, 40.0, 7.0
Y0 = 2.0
box('floor', (0, Y0 - L / 2, -0.35), (Wd, L + 6, 0.5), bevel=0)
box('floor', (0, Y0 + 1.5, 0.3), (Wd, 3, 0.6), bevel=0.05)
for i in range(4): box('floor', (0, Y0 - 0.25 - i * 0.5, 0.5 - i * 0.15), (5, 0.5, 0.15 * (4 - i) + 0.02), bevel=0.02, chip=0.02)
for side in (-1, 1):
    # 壁は石の段ごとに少しずつずらして積む
    for row in range(7):
        for k in range(10):
            ln = random.uniform(3.2, 4.6); y = Y0 - k * 4.1 - random.uniform(0, 0.6)
            box('wall', (side * (Wd / 2 + 0.5 + random.uniform(-0.05, 0.05)), y - ln / 2, row + 0.5), (1.0, ln, 1.0), bevel=0.05, chip=0.03)
box('wall', (0, Y0 - L - 0.5, Ht / 2 - 0.5), (Wd + 2, 1, Ht + 1), bevel=0.03)
# 奥の出入口（光が漏れる）
em = bpy.data.materials.new('glow'); em.use_nodes = True
en = em.node_tree; en.nodes.remove(en.nodes['Principled BSDF'])
e = en.nodes.new('ShaderNodeEmission'); e.inputs['Color'].default_value = (1, 0.8, 0.55, 1); e.inputs['Strength'].default_value = 25
en.links.new(e.outputs['Emission'], en.nodes['Material Output'].inputs['Surface'])
dbm = bmesh.new(); bmesh.ops.create_cube(dbm, size=1)
for v in dbm.verts: v.co = Vector((v.co.x * 2.4, Y0 - L + 0.02 + v.co.y * 0.02, 1.8 + v.co.z * 3.6))
obj_from(dbm, 'door', em)
# 天井（光の差す穴を3つ）
holes = [(-2.0, -10.0), (3.0, -23.0), (-1.5, -32.0)]
y = Y0
while y > Y0 - L:
    x = -Wd / 2
    while x < Wd / 2:
        cx, cy = x + 1, y - 1
        if not any(abs(cx - hx) < 1.0 and abs(cy - hy) < 1.0 for hx, hy in holes):
            box('ceil', (cx, cy, Ht + 0.25 + random.uniform(-0.03, 0.03)), (2, 2, 0.5), bevel=0.04)
        x += 2
    y -= 2
# 柱
for yy in range(-4, -int(L) + 4, -7):
    for xx in (-4.5, 4.5):
        cyl('pillar', xx, yy, -0.1, Ht - 1.0, 0.95, 0.85)
        cyl('pillar', xx, yy, Ht - 1.1, 1.1, 0.85, 1.25, chip=0.03)
        box('pillar', (xx, yy, Ht - 0.05), (2.6, 2.6, 0.3), bevel=0.05)
# 石棺
box('pillar', (6.5, -16, 0.45), (1.4, 2.8, 1.1), bevel=0.06, chip=0.03)
box('wall', (6.5, -16, 1.1), (1.5, 2.9, 0.25), bevel=0.05)
# 壁ぎわの砂だまりと崩れた石
for i in range(16):
    side = random.choice([-1, 1]); yy = random.uniform(Y0 - L + 3, Y0 - 2)
    mound('sand', (side * (Wd / 2 - 0.4), yy, -0.1), (random.uniform(0.8, 1.6), random.uniform(1.5, 3.5), 1), random.uniform(0.25, 0.6), i)
for i in range(30):
    s = random.uniform(0.15, 0.55)
    box('wall', (random.choice([-1, 1]) * random.uniform(6.5, 8.6), random.uniform(Y0 - L + 3, Y0 - 3), s / 2 - 0.12),
        (s * 1.3, s, s * random.uniform(0.6, 1)), bevel=0.03, chip=0.05)
# 水面
wbm = bmesh.new(); bmesh.ops.create_grid(wbm, x_segments=1, y_segments=1, size=1)
for v in wbm.verts: v.co = Vector((v.co.x * Wd / 2, Y0 - L / 2 - 1 + v.co.y * (L / 2 - 1), 0.12))
wo = obj_from(wbm, 'water', water)
wo.modifiers.new('solid', 'SOLIDIFY').thickness = 0.5

# 空気中のもや（光の筋が見えるように）
fog = bpy.data.materials.new('fog'); fog.use_nodes = True
fn = fog.node_tree; fn.nodes.remove(fn.nodes['Principled BSDF'])
pv = fn.nodes.new('ShaderNodeVolumePrincipled'); pv.inputs['Density'].default_value = 0.018; pv.inputs['Color'].default_value = (1, 0.93, 0.82, 1)
fn.links.new(pv.outputs['Volume'], fn.nodes['Material Output'].inputs['Volume'])
fbm = bmesh.new(); bmesh.ops.create_cube(fbm, size=1)
for v in fbm.verts: v.co = Vector((v.co.x * (Wd - 0.2), Y0 - L / 2 + v.co.y * (L - 0.5), 3.6 + v.co.z * 6.9))
obj_from(fbm, 'fog', fog)

# ---------- 光 ----------
world = bpy.data.worlds.new('w'); sc.world = world; world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.5, 0.65, 0.95, 1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value = 1.5
sun = bpy.data.lights.new('sun', 'SUN'); sun.energy = 8; sun.angle = math.radians(1.2); sun.color = (1, 0.92, 0.78)
so = bpy.data.objects.new('sun', sun); sc.collection.objects.link(so); so.rotation_euler = (math.radians(14), math.radians(-7), 0)
for i, (x, y) in enumerate([(-8.3, -2), (8.3, -12), (-8.3, -22), (8.3, -32)]):
    t = bpy.data.lights.new('t', 'POINT'); t.energy = 140; t.color = (1, 0.52, 0.2); t.shadow_soft_size = 0.12
    to = bpy.data.objects.new('t', t); to.location = (x, y, 2.6); sc.collection.objects.link(to)
    fl = bpy.data.materials.new('fl'); fl.use_nodes = True; fn2 = fl.node_tree; fn2.nodes.remove(fn2.nodes['Principled BSDF'])
    ee = fn2.nodes.new('ShaderNodeEmission'); ee.inputs['Color'].default_value = (1, 0.55, 0.2, 1); ee.inputs['Strength'].default_value = 60
    fn2.links.new(ee.outputs['Emission'], fn2.nodes['Material Output'].inputs['Surface'])
    fb = bmesh.new(); bmesh.ops.create_cone(fb, cap_ends=True, segments=12, radius1=0.09, radius2=0.0, depth=0.3)
    for v in fb.verts: v.co += Vector((x, y, 2.75))
    obj_from(fb, 'flame', fl)

# ---------- カメラ ----------
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = 18; cam.data.sensor_width = 36
cam.location = (-0.6, 3.0, 1.9)
cam.rotation_euler = (math.radians(86), 0, math.radians(3))
cam.data.dof.use_dof = True; cam.data.dof.focus_distance = 9; cam.data.dof.aperture_fstop = 5.6

sc.render.filepath = OUT
sc.render.image_settings.file_format = 'PNG'
print('rendering', SAMPLES, W, H, flush=True)
bpy.ops.render.render(write_still=True)
print('saved', OUT, flush=True)

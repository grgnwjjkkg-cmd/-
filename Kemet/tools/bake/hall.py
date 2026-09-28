"""浸水した広間を Blender で組み立てて、光の跳ね返りを計算（ベイク）して書き出す。
使い方（Kemet/ で）:
  blender -b --python tools/bake/hall.py -- [samples] [lightmap_size]
出力:
  Game/assets/baked/hall.glb        … 形（UVが2組：模様用・ライトマップ用）
  Game/assets/baked/hall_light.hdr  … 光の計算結果（ライトマップ）
"""
import bpy, bmesh, math, os, sys, random

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
SAMPLES = int(argv[0]) if len(argv) > 0 else 128
LM_SIZE = int(argv[1]) if len(argv) > 1 else 2048
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'Game', 'assets'))
OUT = os.path.join(ROOT, 'baked')
os.makedirs(OUT, exist_ok=True)
random.seed(3)

# ---------- 初期化 ----------
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = SAMPLES
scene.cycles.max_bounces = 6
scene.cycles.diffuse_bounces = 4

# ---------- 材質（Poly Haven の実写テクスチャ） ----------
def material(name, tex_id, tint=(1, 1, 1)):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes['Principled BSDF']
    img = bpy.data.images.load(os.path.join(ROOT, 'tex', f'{tex_id}_diff.jpg'))
    tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = img
    uv = nt.nodes.new('ShaderNodeUVMap'); uv.uv_map = 'UVMap'
    nt.links.new(uv.outputs['UV'], tex.inputs['Vector'])
    mix = nt.nodes.new('ShaderNodeMixRGB'); mix.blend_type = 'MULTIPLY'; mix.inputs['Fac'].default_value = 1
    mix.inputs['Color2'].default_value = (*tint, 1)
    nt.links.new(tex.outputs['Color'], mix.inputs['Color1'])
    nt.links.new(mix.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value = 0.85
    # ベイク先（ライトマップ）を置いておく
    lm = nt.nodes.new('ShaderNodeTexImage'); lm.name = 'LIGHTMAP'
    nt.nodes.active = lm
    return m

MATS = {
    'wall': material('wall', 'large_sandstone_blocks_01'),
    'pillar': material('pillar', 'sandstone_blocks_08'),
    'floor': material('floor', 'red_sandstone_pavement', (0.72, 0.65, 0.54)),
    'ceil': material('ceil', 'sandstone_blocks_08', (0.6, 0.54, 0.45)),
}

# ---------- 形を作る（すべて1つのメッシュにまとめる） ----------
bm = bmesh.new()
mat_index = {k: i for i, k in enumerate(MATS)}

def box(cx, cy, cz, sx, sy, sz, mat):
    """Blender は Z が上。three.js へは (x, z, -y) に変換されて出る"""
    ret = bmesh.ops.create_cube(bm, size=1)
    for v in ret['verts']:
        v.co.x = cx + v.co.x * sx; v.co.y = cy + v.co.y * sy; v.co.z = cz + v.co.z * sz
    for f in {f for v in ret['verts'] for f in v.link_faces}:
        f.material_index = mat_index[mat]

def cylinder(cx, cy, z0, h, r1, r2, mat, seg=32):
    ret = bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r1, radius2=r2, depth=h)
    for v in ret['verts']:
        v.co.x += cx; v.co.y += cy; v.co.z += z0 + h / 2
    for f in {f for v in ret['verts'] for f in v.link_faces}:
        f.material_index = mat_index[mat]

W, L, H = 18.0, 40.0, 7.0   # 幅・奥行き・高さ（奥行きは -Y 方向 = three.js の -Z）
Y0 = 2.0                     # 手前の端
# 床（水の下）と手前の歩道・階段
box(0, Y0 - L / 2, -0.35, W, L, 0.5, 'floor')
box(0, Y0 + 1.5, 0.3, W, 3, 0.6, 'floor')
for i in range(4):
    box(0, Y0 - 0.25 - i * 0.5, 0.5 - i * 0.15, 5, 0.5, 0.15 * (4 - i) + 0.02, 'floor')
# 壁（石を少しずつずらして積む：平らすぎない壁）
for side in (-1, 1):
    box(side * (W / 2 + 0.5), Y0 - L / 2, H / 2 - 0.5, 1, L + 2, H + 1, 'wall')
    for k in range(40):
        y = Y0 - random.uniform(1, L - 1); z = random.uniform(0.2, H - 0.8)
        box(side * (W / 2 - 0.05), y, z, 0.25, random.uniform(0.8, 1.8), random.uniform(0.4, 0.9), 'wall')
box(0, Y0 - L - 0.5, H / 2 - 0.5, W + 2, 1, H + 1, 'wall')
box(0, Y0 + 3.5, H / 2 - 0.5, W + 2, 1, H + 1, 'wall')
# 奥の出入口（あいだを空ける）
# 天井：光が差し込む穴を3つ空けて並べる
holes = [(-2.0, -10.0), (3.0, -23.0), (-1.5, -32.0)]
step = 2.0
y = Y0
while y > Y0 - L:
    x = -W / 2
    while x < W / 2:
        cx, cy = x + step / 2, y - step / 2
        if not any(abs(cx - hx) < 1.0 and abs(cy - hy) < 1.0 for hx, hy in holes):
            box(cx, cy, H + 0.25, step, step, 0.5, 'ceil')
        x += step
    y -= step
# 太い柱（パピルス柱）
for yy in range(-4, -int(L) + 4, -7):
    for xx in (-4.5, 4.5):
        cylinder(xx, yy, -0.1, H - 1.0, 0.95, 0.85, 'pillar')
        cylinder(xx, yy, H - 1.1, 1.1, 0.85, 1.25, 'pillar')
        box(xx, yy, H - 0.05, 2.6, 2.6, 0.3, 'pillar')
# 石棺と崩れた石
box(6.5, -16, 0.45, 1.4, 2.8, 1.1, 'pillar')
box(6.5, -16, 1.1, 1.5, 2.9, 0.25, 'wall')
for _ in range(18):
    s = random.uniform(0.25, 0.7)
    box(random.choice([-1, 1]) * random.uniform(6, 8.4), random.uniform(Y0 - L + 3, Y0 - 3), s / 2 - 0.1, s * 1.3, s, s, 'wall')

mesh = bpy.data.meshes.new('hall')
bm.to_mesh(mesh); bm.free()
obj = bpy.data.objects.new('hall', mesh)
scene.collection.objects.link(obj)
for m in MATS.values(): mesh.materials.append(m)
bpy.context.view_layer.objects.active = obj
obj.select_set(True)

# UV1：模様（3mごとに繰り返す）
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.cube_project(cube_size=3.0)
# UV2：ライトマップ（重ならないように並べる）
bpy.ops.object.mode_set(mode='OBJECT')
mesh.uv_layers.new(name='Lightmap')
mesh.uv_layers.active = mesh.uv_layers['Lightmap']
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004)
bpy.ops.object.mode_set(mode='OBJECT')

# ---------- 光 ----------
world = bpy.data.worlds.new('world'); scene.world = world
world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.55, 0.7, 1.0, 1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value = 1.2
sun = bpy.data.lights.new('sun', 'SUN'); sun.energy = 9; sun.angle = math.radians(1.5); sun.color = (1.0, 0.93, 0.8)
sun_o = bpy.data.objects.new('sun', sun); scene.collection.objects.link(sun_o)
sun_o.rotation_euler = (math.radians(12), math.radians(-6), 0)
for i, (x, y) in enumerate([(-8.3, -2), (8.3, -12), (-8.3, -22), (8.3, -32)]):
    t = bpy.data.lights.new(f'torch{i}', 'POINT'); t.energy = 160; t.color = (1.0, 0.55, 0.22); t.shadow_soft_size = 0.15
    to = bpy.data.objects.new(f'torch{i}', t); to.location = (x, y, 2.6); scene.collection.objects.link(to)
# 奥の出入口からの明かり
d = bpy.data.lights.new('door', 'AREA'); d.energy = 900; d.size = 2.4; d.color = (1.0, 0.8, 0.55)
do = bpy.data.objects.new('door', d); do.location = (0, Y0 - L + 0.2, 1.8); do.rotation_euler = (math.radians(-90), 0, 0)
scene.collection.objects.link(do)

# ---------- ベイク ----------
img = bpy.data.images.new('hall_light', LM_SIZE, LM_SIZE, float_buffer=True)
for m in MATS.values():
    n = m.node_tree.nodes['LIGHTMAP']; n.image = img
    uvn = m.node_tree.nodes.new('ShaderNodeUVMap'); uvn.uv_map = 'Lightmap'
    m.node_tree.links.new(uvn.outputs['UV'], n.inputs['Vector'])
    m.node_tree.nodes.active = n
scene.render.bake.use_pass_direct = True
scene.render.bake.use_pass_indirect = True
scene.render.bake.use_pass_color = False
scene.render.bake.margin = 6
print('baking...', SAMPLES, LM_SIZE, flush=True)
bpy.ops.object.bake(type='DIFFUSE', uv_layer='Lightmap')
# ノイズ除去（Intel Open Image Denoise を合成ノードで）
scene.use_nodes = True
tree = scene.node_tree
for n in list(tree.nodes): tree.nodes.remove(n)
src = tree.nodes.new('CompositorNodeImage'); src.image = img
den = tree.nodes.new('CompositorNodeDenoise'); den.use_hdr = True; den.prefilter = 'ACCURATE'
out = tree.nodes.new('CompositorNodeComposite')
tree.links.new(src.outputs['Image'], den.inputs['Image'])
tree.links.new(den.outputs['Image'], out.inputs['Image'])
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); scene.collection.objects.link(cam); scene.camera = cam
scene.render.resolution_x = scene.render.resolution_y = LM_SIZE
scene.render.resolution_percentage = 100
scene.cycles.samples = 1
scene.render.image_settings.file_format = 'HDR'
scene.render.filepath = os.path.join(OUT, 'hall_light.hdr')
scene.view_settings.view_transform = 'Standard'
print('denoising...', flush=True)
bpy.ops.render.render(write_still=True)

# ---------- 書き出し ----------
for m in MATS.values():
    nt = m.node_tree
    nt.nodes.remove(nt.nodes['LIGHTMAP'])
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, 'hall.glb'), export_format='GLB', use_selection=True,
                          export_texcoords=True, export_normals=True, export_materials='PLACEHOLDER', export_yup=True)
print('done', flush=True)

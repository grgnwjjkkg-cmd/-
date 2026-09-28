"""MakeHuman（MPFB2, CC0）でリアルな人を作り、ゲームの骨（UAL のマネキン）に乗せかえて glb に書き出す。
使い方（Kemet/ で）:
  blender -b --python tools/chars/make_human.py -- <id>        例: hero
  （MPFB2 と makehuman_system_assets を Blender に入れておく。README 参照）
キャラの体つき・肌・髪・服は下の CHARS に書く。
"""
import bpy, bmesh, os, sys, math, random
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
from bl_ext.user_default.mpfb.services.humanservice import HumanService
from bl_ext.user_default.mpfb.services.locationservice import LocationService

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.join(HERE, '..', '..', 'Game', 'assets')
D = LocationService.get_user_data()

CHARS = {
    # 主人公：若い探検家。日焼けした肌、短い黒髪、白い腰布と青と金の首飾り
    'hero': dict(
        macro={"gender": 1.0, "age": 0.42, "muscle": 0.72, "weight": 0.42, "proportions": 0.85, "height": 0.62,
               "cupsize": 0.5, "firmness": 0.5, "race": {"african": 0.45, "caucasian": 0.35, "asian": 0.2}},
        skin='young_african_male', eyes='brown', brows='eyebrow001', hair='short02', hair_color=(0.16, 0.12, 0.1),
        kilt=dict(top=1.02, bottom=0.60, color=(0.93, 0.9, 0.82)), collar=dict(colors=[(0.1, 0.32, 0.62), (0.85, 0.66, 0.25), (0.06, 0.45, 0.42), (0.85, 0.66, 0.25)]),
        armbands=True, skin_tex=1024,
    ),
}

ID = sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else 'hero'
C = CHARS[ID]
OUT = os.path.join(GAME, 'chars', f'human_{ID}.glb')
TMP = os.path.join(HERE, '..', '..', 'build', 'chars'); os.makedirs(TMP, exist_ok=True)

# MPFB の骨の名前 → アニメの骨の名前（違うものだけ）
RENAME = {'head': 'Head', 'Root': 'root'}


def clear():
    for o in list(bpy.data.objects): bpy.data.objects.remove(o)


def activate(o):
    bpy.ops.object.mode_set(mode='OBJECT') if bpy.context.object and bpy.context.object.mode != 'OBJECT' else None
    for x in bpy.context.selected_objects: x.select_set(False)
    o.select_set(True); bpy.context.view_layer.objects.active = o


# ---------------------------------------------------------------- 1. 人を作る
clear()
body = HumanService.create_human(macro_detail_dict=C['macro'])
HumanService.add_builtin_rig(body, 'game_engine')
HumanService.set_character_skin(os.path.join(D, f"skins/{C['skin']}/{C['skin']}.mhmat"), body, skin_type='MAKESKIN')
parts = {}
for f, t in ((f"eyes/low-poly/low-poly.mhclo", 'Eyes'), (f"eyebrows/{C['brows']}/{C['brows']}.mhclo", 'Eyebrows'),
             ("eyelashes/eyelashes01/eyelashes01.mhclo", 'Eyelashes'), (f"hair/{C['hair']}/{C['hair']}.mhclo", 'Hair')):
    parts[t] = HumanService.add_mhclo_asset(os.path.join(D, f), body, asset_type=t, subdiv_levels=0, material_type='MAKESKIN')
rig = body.parent
meshes = [o for o in bpy.data.objects if o.type == 'MESH']

# 体の形（シェイプキー）と、補助の頂点（マスク）を確定させる
activate(body)
if body.data.shape_keys: bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
bpy.ops.object.modifier_apply(modifier='Hide helpers')
for o in meshes:
    if o.data.shape_keys:
        activate(o); bpy.ops.object.shape_key_remove(all=True, apply_mix=True)

# ---------------------------------------------------------------- 2. アニメの骨（UAL マネキン）の関節の位置を読む
def ual_joints():
    """anims.glb の骨の位置（世界座標, Blender の向き）を計算する"""
    import json, struct
    f = open(os.path.join(GAME, 'anims.glb'), 'rb').read()
    n = struct.unpack('<I', f[12:16])[0]; j = json.loads(f[20:20 + n])
    nodes = j['nodes']; parent = {c: i for i, nd in enumerate(nodes) for c in nd.get('children', [])}
    def local(nd):
        t = Vector(nd.get('translation', (0, 0, 0))); q = nd.get('rotation', (0, 0, 0, 1))
        from mathutils import Quaternion
        return Matrix.Translation(t) @ Quaternion((q[3], q[0], q[1], q[2])).to_matrix().to_4x4() @ Matrix.Diagonal((*nd.get('scale', (1, 1, 1)), 1))
    def world(i):
        m = local(nodes[i])
        while i in parent: i = parent[i]; m = local(nodes[i]) @ m
        return m
    out = {}
    for i, nd in enumerate(nodes):
        p = world(i).translation
        out[nd['name']] = Vector((p.x, -p.z, p.y))
    return out


UAL = ual_joints()
# 骨の向き＝その骨の関節から「次の関節」への向き
NEXT = {'clavicle': 'upperarm', 'upperarm': 'lowerarm', 'lowerarm': 'hand', 'hand': 'middle_01', 'thigh': 'calf', 'calf': 'foot', 'foot': 'ball'}
for f in ('thumb', 'index', 'middle', 'ring', 'pinky'):
    NEXT[f + '_01'] = f + '_02'; NEXT[f + '_02'] = f + '_03'


def next_joint(name, side):
    base = name[:-2]
    if base in NEXT: return NEXT[base] + side
    return None


# ---------------------------------------------------------------- 2b. 首飾りは自然に立った姿勢のまま作る（肩の形が自然なうちに）
bpy.context.view_layer.update()
bvh = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())


def surface(p, d):
    """p から d の方向へ体に当たる点"""
    hit = bvh.ray_cast(p, d)
    return hit[0]


def mat(name, color, rough=0.8, metal=0.0, img=None):
    m = bpy.data.materials.new(name); m.use_nodes = True
    bs = m.node_tree.nodes['Principled BSDF']
    bs.inputs['Base Color'].default_value = (*color, 1); bs.inputs['Roughness'].default_value = rough; bs.inputs['Metallic'].default_value = metal
    if img:
        tx = m.node_tree.nodes.new('ShaderNodeTexImage'); tx.image = img
        m.node_tree.links.new(tx.outputs['Color'], bs.inputs['Base Color'])
    return m


def ring_mesh(name, rings, closed=True):
    """rings: [[Vector,...], ...] を順につないだ筒"""
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    vs = [[bm.verts.new(p) for p in r] for r in rings]
    uv = bm.loops.layers.uv.new('UVMap')
    n = len(rings[0])
    for i in range(len(rings) - 1):
        for j in range(n if closed else n - 1):
            k = (j + 1) % n
            f = bm.faces.new((vs[i][j], vs[i][k], vs[i + 1][k], vs[i + 1][j]))
            for l, (a, b) in zip(f.loops, ((j, i), (j + 1, i), (j + 1, i + 1), (j, i + 1))):
                l[uv].uv = (a / n, b / (len(rings) - 1))
    bm.normal_update(); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(o)
    return o


def pleats(w, h, base, dark):
    """細かいひだの布（縦じま）"""
    img = bpy.data.images.new('pleats', w, h)
    px = []
    for y in range(h):
        for x in range(w):
            s = 0.5 + 0.5 * math.sin(x / w * math.pi * 2 * 48)
            k = 1 - dark * (s ** 3) - 0.04 * random.random()
            px += [base[0] * k, base[1] * k, base[2] * k, 1]
    img.pixels = px
    return img


def transfer_weights(o):
    for g in body.vertex_groups: o.vertex_groups.new(name=g.name)
    dt = o.modifiers.new('dt', 'DATA_TRANSFER'); dt.object = body
    dt.use_vert_data = True; dt.data_types_verts = {'VGROUP_WEIGHTS'}; dt.vert_mapping = 'POLYINTERP_NEAREST'
    dt.layers_vgroup_select_src = 'ALL'; dt.layers_vgroup_select_dst = 'NAME'
    activate(o); bpy.ops.object.modifier_apply(modifier='dt')


clothes = []
joints = {pb.name: (rig.matrix_world @ pb.head, rig.matrix_world @ pb.tail) for pb in rig.pose.bones}
if C.get('collar'):
    neck = joints['neck_01'][0]; n = 48; rings = []
    for ri in range(7):
        rr = 0.066 + ri * 0.016
        ring = []
        for j in range(n):
            a = j / n * math.tau
            d = Vector((math.sin(a) * 1.2, -math.cos(a) * 1.1, 0))
            aim = neck + d * rr + Vector((0, 0, -0.035 - 0.55 * (rr - 0.068)))
            p = aim + d.normalized() * 0.3 + Vector((0, 0, 0.12))
            hit = surface(p, (aim - p).normalized())
            nrm = (p - aim).normalized()
            ring.append((hit if hit else aim) + nrm * 0.008)
        rings.append(ring)
    collar = ring_mesh('Collar', rings)
    cols = C['collar']['colors']
    img = bpy.data.images.new('beads', 8, 64); px = []
    for y in range(64):
        c = cols[(y * len(cols)) // 64]; k = 0.75 + 0.25 * math.sin((y % (64 // len(cols))) / (64 / len(cols)) * math.pi)
        for x in range(8): px += [c[0] * k, c[1] * k, c[2] * k, 1]
    img.pixels = px
    collar.data.materials.append(mat('beads', (1, 1, 1), 0.35, 0.2, img=img))
    clothes.append(collar)
    o = collar
    transfer_weights(o)
    if o.name == 'Collar':   # 首飾りは腕に引っぱられないように（腕の分は同じ側の鎖骨へ）
        for side in ('l', 'r'):
            cl = o.vertex_groups[f'clavicle_{side}']
            for v in o.data.vertices:
                w = sum(g.weight for g in v.groups if ('arm' in o.vertex_groups[g.group].name or 'hand' in o.vertex_groups[g.group].name) and o.vertex_groups[g.group].name.endswith('_' + side))
                if w > 0:
                    base = next((g.weight for g in v.groups if g.group == cl.index), 0)
                    cl.add([v.index], base + w, 'REPLACE')
        for g in list(o.vertex_groups):
            if 'arm' in g.name or 'hand' in g.name: o.vertex_groups.remove(g)
    o.parent = rig; o.matrix_parent_inverse = rig.matrix_world.inverted()
    o.modifiers.new('Armature', 'ARMATURE').object = rig
    meshes.append(o)

# ---------------------------------------------------------------- 3. 人の腕や脚をアニメの骨と同じ形（T の字）に曲げて、それを基本の姿勢にする
activate(rig); bpy.ops.object.mode_set(mode='POSE')
RW = rig.matrix_world
for b in rig.data.bones:  # 親が先
    name = b.name
    if name[-2:] not in ('_l', '_r'): continue
    nx = next_joint(name, name[-2:])
    if not nx or nx not in rig.pose.bones or name not in UAL or nx not in UAL: continue
    bpy.context.view_layer.update()
    pb = rig.pose.bones[name]
    h = RW @ pb.head; c = RW @ rig.pose.bones[nx].head
    cur = (c - h).normalized(); want = (UAL[nx] - UAL[name]).normalized()
    q = cur.rotation_difference(want)
    M = Matrix.Translation(h) @ q.to_matrix().to_4x4() @ Matrix.Translation(-h)
    pb.matrix = RW.inverted() @ M @ RW @ pb.matrix
bpy.context.view_layer.update()
bpy.ops.object.mode_set(mode='OBJECT')
for o in meshes:
    activate(o)
    for m in list(o.modifiers):
        if m.type == 'ARMATURE': bpy.ops.object.modifier_apply(modifier=m.name)
activate(rig); bpy.ops.object.mode_set(mode='POSE'); bpy.ops.pose.armature_apply(selected=False); bpy.ops.object.mode_set(mode='OBJECT')
for old, new_ in RENAME.items():
    rig.data.bones[old].name = new_
    for o in meshes:
        g = o.vertex_groups.get(old)
        if g: g.name = new_
arm = rig
arm.name = 'Armature'
bpy.context.view_layer.update()
joints = {pb.name: (RW @ pb.head, RW @ pb.tail) for pb in rig.pose.bones}

# ---------------------------------------------------------------- 5. 服（腰布・首飾り・腕輪）
bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
bvh = BVHTree.FromObject(body, dg)




if C.get('kilt'):
    K = C['kilt']; n = 40; rings = []
    for yi in range(9):
        z = K['top'] + (K['bottom'] - K['top']) * yi / 8
        ring = []
        for j in range(n):
            a = j / n * math.tau
            d = Vector((math.sin(a), -math.cos(a), 0))
            hit = surface(Vector((0, 0, z)) + d * 0.6, -d)
            r = (hit - Vector((0, 0, z))).length if hit else 0.2
            ring.append(r)
        # 脚のすきまのへこみを埋める（となりの角度となめらかに）
        for _ in range(6):
            ring = [max(ring[j], (ring[j - 1] + ring[(j + 1) % n]) / 2) for j in range(n)]
        rings.append([Vector((0, 0, z)) + Vector((math.sin(j / n * math.tau), -math.cos(j / n * math.tau), 0)) * (ring[j] + 0.014 + 0.04 * (yi / 8) ** 1.3) for j in range(n)])
    # 上から下へ半径がちぢまないようにする（脚のすきまに入りこまない）
    for yi in range(1, 9):
        for j in range(n):
            c = Vector((0, 0, rings[yi][j].z)); pr = (rings[yi - 1][j] - Vector((0, 0, rings[yi - 1][j].z))).length
            v = rings[yi][j] - c
            if v.length < pr: rings[yi][j] = c + v.normalized() * pr
    kilt = ring_mesh('Kilt', rings)
    kilt.data.materials.append(mat('linen', (1, 1, 1), 0.9, img=pleats(256, 8, K['color'], 0.22)))
    kilt.data.materials[0].use_backface_culling = False
    bmb = bmesh.new(); bmb.from_mesh(body.data)
    hide = [v for v in bmb.verts if K['bottom'] + 0.08 < v.co.z < K['top'] - 0.03 and abs(v.co.x) < 0.3]
    bmesh.ops.delete(bmb, geom=hide, context='VERTS'); bmb.to_mesh(body.data); bmb.free()
    # 腰ひも
    belt = ring_mesh('Belt', [[p + (p - Vector((0, 0, p.z))).normalized() * 0.006 + Vector((0, 0, dz)) for p in rings[0]] for dz in (0.02, -0.035)])
    belt.data.materials.append(mat('belt', (0.55, 0.36, 0.18), 0.6))
    clothes += [kilt, belt]


if C.get('armbands'):
    gold = mat('gold', (0.9, 0.68, 0.3), 0.3, 1.0)
    for s in ('l', 'r'):
        h, t = joints[f'upperarm_{s}']
        c = h.lerp(t, 0.72); ax = (t - h).normalized()
        u = ax.orthogonal().normalized(); v = ax.cross(u)
        rings = []
        for k in (-0.018, 0.018):
            ring = []
            for j in range(24):
                a = j / 24 * math.tau; d = u * math.cos(a) + v * math.sin(a)
                hit = surface(c + ax * k + d * 0.2, -d)
                r = (hit - (c + ax * k)).length if hit else 0.05
                ring.append(c + ax * k + d * (r + 0.006))
            rings.append(ring)
        band = ring_mesh(f'Armband_{s}', rings); band.data.materials.append(gold); clothes.append(band)

# 服の重み（どの骨にくっついて動くか）を体から写す（腰布は下へいくほど脚に、左右はなめらかに）
def skirt_weights(o, top, bottom):
    for g in ('pelvis', 'thigh_l', 'thigh_r'): o.vertex_groups.get(g) or o.vertex_groups.new(name=g)
    for v in o.data.vertices:
        t = max(0.0, min(1.0, (top - v.co.z) / (top - bottom)))
        side = max(-1.0, min(1.0, v.co.x / 0.12))
        leg = 0.92 * t ** 1.1
        for g in o.vertex_groups: g.remove([v.index])
        o.vertex_groups['pelvis'].add([v.index], 1 - leg, 'REPLACE')
        if leg > 0:
            o.vertex_groups['thigh_l'].add([v.index], leg * (0.5 + side / 2), 'REPLACE')
            o.vertex_groups['thigh_r'].add([v.index], leg * (0.5 - side / 2), 'REPLACE')

skirts = [o for o in clothes if o.name in ('Kilt', 'Belt')]
for o in clothes:
    if o in skirts or o.name == 'Collar': continue
    transfer_weights(o)
for o in skirts: skirt_weights(o, C['kilt']['top'] + 0.05, C['kilt']['bottom'])
meshes += [o for o in clothes if o not in meshes]

# ---------------------------------------------------------------- 6. 骨に乗せる・材質を軽くする
for o in meshes:
    for g in o.vertex_groups:
        if g.name in RENAME: g.name = RENAME[g.name]
    for g in list(o.vertex_groups):   # 骨にない名前のグループは消す
        if g.name not in arm.data.bones: o.vertex_groups.remove(g)
    if o.parent is not arm: o.parent = arm; o.matrix_parent_inverse = arm.matrix_world.inverted()
    m = o.modifiers.new('Armature', 'ARMATURE'); m.object = arm


def first_image(m):
    def walk(nt):
        for n in nt.nodes:
            if n.type == 'TEX_IMAGE' and n.image and 'ump' not in (n.label or n.name): return n.image
            if n.type == 'GROUP':
                r = walk(n.node_tree)
                if r: return r
    return walk(m.node_tree)


def simple(o, size, rough=0.6, alpha=False, tint=None, name=None):
    """MakeHuman の材質を、ゲームで使える普通の材質（画像1枚）に置きかえる"""
    img = first_image(o.data.materials[0]).copy()
    if img.size[0] > size: img.scale(size, size)
    m = bpy.data.materials.new(name or o.name); m.use_nodes = True
    nt = m.node_tree; bs = nt.nodes['Principled BSDF']
    tx = nt.nodes.new('ShaderNodeTexImage'); tx.image = img
    if tint:
        mix = nt.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'; mix.inputs[0].default_value = 1
        nt.links.new(tx.outputs['Color'], mix.inputs[6]); mix.inputs[7].default_value = (*tint, 1)
        nt.links.new(mix.outputs[2], bs.inputs['Base Color'])
    else:
        nt.links.new(tx.outputs['Color'], bs.inputs['Base Color'])
    bs.inputs['Roughness'].default_value = rough
    if alpha:
        nt.links.new(tx.outputs['Alpha'], bs.inputs['Alpha']); m.blend_method = 'HASHED'
    o.data.materials.clear(); o.data.materials.append(m)


simple(body, C['skin_tex'], 0.55, name='skin')
simple(parts['Eyes'], 256, 0.1, name='eyes')
simple(parts['Eyebrows'], 256, 0.9, alpha=True, name='brows')
simple(parts['Eyelashes'], 256, 0.9, alpha=True, name='lashes')
simple(parts['Hair'], 512, 0.7, alpha=True, tint=C['hair_color'], name='hair')

arm['realHuman'] = 1

# ---------------------------------------------------------------- 7. 書き出し
for o in bpy.data.objects: o.select_set(o is arm or o in meshes)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True, export_animations=False,
                          export_extras=True, export_image_format='AUTO', export_jpeg_quality=85, export_apply=False,
                          export_skins=True, export_morph=False)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(TMP, f'{ID}.blend'))
print('WROTE', OUT, os.path.getsize(OUT) // 1024, 'KB')

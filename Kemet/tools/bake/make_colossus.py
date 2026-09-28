"""墓の入口の巨大な座像（アブ・シンベル神殿のような）の形を作る。
MakeHuman（MPFB2, CC0）の人を玉座に座らせ、頭巾（ネメス）・二重冠・あごひげ・腰布をつけて1つの形にする。
使い方（Kemet/ で）:
  blender -b --python tools/bake/make_colossus.py
できるもの: tools/bake/models/colossus.obj（身長 1 の人の大きさ。置くときに大きくする）
"""
import bpy, bmesh, os, sys, math
from mathutils import Vector, Matrix
from bl_ext.user_default.mpfb.services.humanservice import HumanService

HERE = os.path.dirname(os.path.abspath(__file__))
STANDING = '--' in sys.argv and 'standing' in sys.argv[sys.argv.index('--') + 1:]   # 立った像（胸の前で腕を組む、オシリス神の形）
OUT = os.path.join(HERE, 'models', 'statue_standing.obj' if STANDING else 'colossus.obj')

for o in list(bpy.data.objects): bpy.data.objects.remove(o)
macro = {"gender": 1.0, "age": 0.5, "muscle": 0.62, "weight": 0.55, "proportions": 0.9, "height": 0.5,
         "cupsize": 0.5, "firmness": 0.5, "race": {"african": 0.4, "caucasian": 0.3, "asian": 0.3}}
body = HumanService.create_human(macro_detail_dict=macro)
HumanService.add_builtin_rig(body, 'game_engine')
rig = body.parent


def activate(o):
    if bpy.context.object and bpy.context.object.mode != 'OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
    for x in bpy.context.selected_objects: x.select_set(False)
    o.select_set(True); bpy.context.view_layer.objects.active = o


activate(body)
if body.data.shape_keys: bpy.ops.object.shape_key_remove(all=True, apply_mix=True)

# ---------- 座らせる：骨を世界の向きで指定する（MPFB の人は -Y が前）
FWD, DOWN = Vector((0, -1, 0)), Vector((0, 0, -1))
POSE = {
    'thigh': lambda s: (FWD + Vector((s * 0.08, 0, 0.02))).normalized(),     # ももは前へ水平
    'calf': lambda s: (DOWN + Vector((0, -0.08, 0))).normalized(),           # すねは真下
    'foot': lambda s: (FWD + Vector((0, 0, -0.25))).normalized(),            # 足は前へ
    'upperarm': lambda s: (DOWN + Vector((s * 0.12, -0.35, 0))).normalized(),  # 腕はわきに沿って下へ
    'lowerarm': lambda s: (FWD + Vector((s * 0.03, 0, -0.42))).normalized(),   # ひじから先はももの上に
    'hand': lambda s: (FWD + Vector((0, 0, -0.35))).normalized(),              # 手はひざの上に平らに
}
if STANDING:
    POSE = {
        'thigh': lambda s: (DOWN + Vector((-s * 0.03, 0, 0))).normalized(),          # 足はそろえてまっすぐ
        'calf': lambda s: DOWN,
        'foot': lambda s: (FWD + Vector((0, 0, -0.3))).normalized(),
        'upperarm': lambda s: (DOWN + Vector((s * 0.05, -0.28, 0))).normalized(),     # 腕はわきにつけて
        'lowerarm': lambda s: Vector((-s * 0.75, -0.25, 0.62)).normalized(),         # ひじから先は胸の前で交差
        'hand': lambda s: Vector((-s * 0.6, -0.1, 0.8)).normalized(),                # 手は反対の肩へ
    }
# 指はそろえて伸ばす（手のひらを ももに置く）
for f in ('index', 'middle', 'ring', 'pinky'):
    for i in (1, 2):
        POSE[f'{f}_0{i}'] = lambda s: (FWD + Vector((0, 0, -0.45))).normalized()
for i in (1, 2):
    POSE[f'thumb_0{i}'] = lambda s: (FWD + Vector((-s * 0.35, 0, -0.35))).normalized()
NEXT = {'thigh': 'calf', 'calf': 'foot', 'foot': 'ball', 'upperarm': 'lowerarm', 'lowerarm': 'hand', 'hand': 'middle_01'}
for f in ('thumb', 'index', 'middle', 'ring', 'pinky'):
    NEXT[f + '_01'] = f + '_02'; NEXT[f + '_02'] = f + '_03'
activate(rig); bpy.ops.object.mode_set(mode='POSE')
RW = rig.matrix_world
for part in ['thigh', 'calf', 'foot', 'upperarm', 'lowerarm', 'hand'] + [f'{f}_0{i}' for f in ('thumb', 'index', 'middle', 'ring', 'pinky') for i in (1, 2)]:
    for side, s in (('l', 1), ('r', -1)):
        bpy.context.view_layer.update()
        pb = rig.pose.bones[f'{part}_{side}']; nx = rig.pose.bones[f'{NEXT[part]}_{side}']
        h = RW @ pb.head; cur = ((RW @ nx.head) - h).normalized()
        q = cur.rotation_difference(POSE[part](s))
        M = Matrix.Translation(h) @ q.to_matrix().to_4x4() @ Matrix.Translation(-h)
        pb.matrix = RW.inverted() @ M @ RW @ pb.matrix
bpy.context.view_layer.update()
J = {pb.name: (RW @ pb.head, RW @ pb.tail) for pb in rig.pose.bones}
bpy.ops.object.mode_set(mode='OBJECT')
activate(body)
for m in list(body.modifiers):
    if m.type in ('ARMATURE', 'MASK'): bpy.ops.object.modifier_apply(modifier=m.name)
body.parent = None; bpy.data.objects.remove(rig)
# 足の裏が台（高さ 0.04）にのるように体を下げる
drop = min(v.co.z for v in body.data.vertices) - 0.04
for v in body.data.vertices: v.co.z -= drop
J = {k: (a - Vector((0, 0, drop)), b - Vector((0, 0, drop))) for k, (a, b) in J.items()}
# 重さを減らす
dec = body.modifiers.new('dec', 'DECIMATE'); dec.ratio = 0.45; bpy.ops.object.modifier_apply(modifier='dec')

# ---------- 付けもの
bm = bmesh.new()


def box(c, s, taper=1.0, bevel=0.0):
    r = bmesh.ops.create_cube(bm, size=1)
    for v in r['verts']:
        k = taper if v.co.z > 0 else 1.0
        v.co = Vector((c[0] + v.co.x * s[0] * k, c[1] + v.co.y * s[1] * k, c[2] + v.co.z * s[2]))
    if bevel: bmesh.ops.bevel(bm, geom=list({e for v in r['verts'] for e in v.link_edges}), offset=bevel, segments=2, affect='EDGES')
    return r


def lathe(cx, cy, z0, prof, seg=40):
    """prof=[(半径, 高さ), ...] を回して作る（冠）"""
    rings = []
    for r, z in prof:
        rings.append([bm.verts.new((cx + r * math.cos(a), cy + r * math.sin(a), z0 + z)) for a in (i / seg * math.tau for i in range(seg))])
    for a, b in zip(rings, rings[1:]):
        for i in range(seg):
            f = bm.faces.new((a[i], a[(i + 1) % seg], b[(i + 1) % seg], b[i])); f.smooth = True
    top = bm.verts.new((cx, cy, z0 + prof[-1][1]))
    for i in range(seg): bm.faces.new((rings[-1][i], rings[-1][(i + 1) % seg], top)).smooth = True


head0, head1 = J['head']
neck = J['neck_01'][0]
hc = head0.lerp(head1, 0.5)                # 頭の中心あたり
top = head1.z + 0.012
sh_l, sh_r = J['upperarm_l'][0], J['upperarm_r'][0]
pelvis = J['pelvis'][0]
knee_l, knee_r = J['calf_l'][0], J['calf_r'][0]
seat = min(J['thigh_l'][0].z, J['thigh_r'][0].z) - 0.085   # おしりの下

# 頭巾（ネメス）：頭の上をおおう部分（おでこの線より上）
face_y = head0.y - 0.095            # 顔の前のあたり
brow = hc.z + 0.02                  # おでこの線
r = bmesh.ops.create_uvsphere(bm, u_segments=36, v_segments=18, radius=1)
cap = r['verts']
for v in cap:
    p = v.co.copy()
    v.co = Vector((hc.x + p.x * 0.1, hc.y + 0.008 + p.y * 0.112, brow + max(p.z, -0.2) * 0.115))
bmesh.ops.delete(bm, geom=[v for v in cap if v.co.z < brow - 0.012], context='VERTS')
for f in bm.faces: f.smooth = True


def hexa(pts):
    """8つの点（下の4つ・上の4つ）で閉じた形"""
    v = [bm.verts.new(p) for p in pts]
    for f in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
        bm.faces.new([v[i] for i in f])


sh_z = (sh_l.z + sh_r.z) / 2
chest_y = neck.y - 0.075
for s in (1, -1):
    # 耳の横で広がって肩へ落ちる布（顔の横を台形にかこむ）
    x0, x1 = s * 0.088, s * 0.1
    hexa([(hc.x + s * 0.17, face_y + 0.035, sh_z + 0.01), (hc.x + s * 0.17, hc.y + 0.1, sh_z + 0.01),
          (hc.x + s * 0.12, hc.y + 0.1, sh_z + 0.01), (hc.x + s * 0.12, face_y + 0.035, sh_z + 0.01),
          (hc.x + x1, face_y + 0.03, brow), (hc.x + x1, hc.y + 0.09, brow), (hc.x + x0, hc.y + 0.09, brow), (hc.x + x0, face_y + 0.03, brow)])
    # 胸の前にたれる布（ラペット）
    lx = hc.x + s * 0.115
    hexa([(lx - 0.035, chest_y - 0.01, sh_z - 0.17), (lx + 0.035, chest_y - 0.01, sh_z - 0.17),
          (lx + 0.035, chest_y + 0.02, sh_z - 0.17), (lx - 0.035, chest_y + 0.02, sh_z - 0.17),
          (lx - 0.03, face_y + 0.04, sh_z + 0.03), (lx + 0.03, face_y + 0.04, sh_z + 0.03),
          (lx + 0.03, face_y + 0.07, sh_z + 0.03), (lx - 0.03, face_y + 0.07, sh_z + 0.03)])
# 後ろにたれる布
box((hc.x, hc.y + 0.085, (brow + sh_z) / 2 - 0.02), (0.2, 0.05, brow - sh_z + 0.05), taper=0.7)
# 二重冠（下エジプトの赤冠＝低い筒、上エジプトの白冠＝細長いふくらみ）
ctop = brow + 0.105
lathe(hc.x, hc.y + 0.01, ctop - 0.03, [(0.085, 0), (0.088, 0.055), (0.08, 0.06), (0.06, 0.062), (0.062, 0.12), (0.058, 0.17), (0.047, 0.22), (0.03, 0.26), (0.034, 0.275), (0.02, 0.29)])
box((hc.x, hc.y + 0.075, ctop + 0.06), (0.09, 0.025, 0.13))
# あごひげ（王の付けひげ）
chin = Vector((hc.x, face_y + 0.015, head0.z - 0.02))
box((chin.x, chin.y, chin.z - 0.04), (0.032, 0.032, 0.085), taper=0.85)
# 腰布（すわった ももの上）
kz = max(J['thigh_l'][0].z, J['thigh_r'][0].z)
if STANDING:   # 立った像：足首までの長い衣と、足もとの台
    lathe(pelvis.x, pelvis.y + 0.01, 0.06, [(0.2, 0.0), (0.19, 0.3), (0.18, 0.6), (0.17, pelvis.z - 0.12), (0.16, pelvis.z + 0.02)], seg=40)
    box((pelvis.x, pelvis.y, 0.03), (0.5, 0.45, 0.06))

else:
    box((pelvis.x, (pelvis.y + (knee_l.y + knee_r.y) / 2) / 2 + 0.02, kz + 0.02), (0.4, abs(knee_l.y - pelvis.y) + 0.05, 0.14), bevel=0.02)
    box((pelvis.x, pelvis.y + 0.02, pelvis.z + 0.02), (0.36, 0.26, 0.14), bevel=0.02)
    box((pelvis.x, (knee_l.y + knee_r.y) / 2 + 0.02, kz - 0.2), (0.12, 0.03, 0.4), taper=0.8)   # 前のたれ布
    # 玉座：座る台と、背中の石板
    box((pelvis.x, pelvis.y + 0.03, seat / 2), (0.62, 0.62, seat))
    box((pelvis.x, pelvis.y + 0.3, sh_l.z / 2), (0.62, 0.14, sh_l.z + 0.02))
    # 足をのせる台
    box((pelvis.x, knee_l.y - 0.1, 0.02), (0.6, 0.5, 0.04))

me = bpy.data.meshes.new('extra'); bm.normal_update(); bm.to_mesh(me); bm.free()
extra = bpy.data.objects.new('extra', me); bpy.context.collection.objects.link(extra)
activate(body); extra.select_set(True); bpy.ops.object.join()
# 足もとを 0 に
lo = min((body.matrix_world @ v.co).z for v in body.data.vertices)
body.location.z -= lo; bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for p in body.data.polygons: p.use_smooth = True
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.wm.obj_export(filepath=OUT, export_selected_objects=True, export_uv=False, export_materials=False,
                      export_normals=False, export_smooth_groups=True, forward_axis='NEGATIVE_Z', up_axis='Y')
print('WROTE', OUT, len(body.data.polygons), 'faces', os.path.getsize(OUT) // 1024, 'KB')

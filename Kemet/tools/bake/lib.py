"""レベルを Blender で組み立てて、光をベイクし、ゲーム用に書き出すための道具。

座標はゲーム（three.js）と同じ：x=東, y=上, z=南（プレイヤーは -z へ進む）。
Blender へは (x, -z, y) に変換して置く。

出力（Game/assets/levels/<name>/）:
  level.glb          … 形。ノード名は「<グループ>__<材質>」。UV1=模様、UV2=ライトマップ
  lm_<グループ>.png  … 光の計算結果（sRGB で保存。値は 1/K 倍してある）
  meta.json          … 当たり判定・たいまつ・水面・光の筋・場所の区分・敵や宝箱の位置など
"""
import bpy, bmesh, math, os, json, random
from mathutils import Vector, noise

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'Game', 'assets'))


def B(x, y, z):
    """ゲーム座標 → Blender 座標"""
    return Vector((x, -z, y))


class Level:
    def __init__(self, name, samples=192):
        self.name = name
        self.out = os.path.join(ROOT, 'levels', name)
        os.makedirs(self.out, exist_ok=True)
        bpy.ops.wm.read_factory_settings(use_empty=True)
        s = bpy.context.scene
        s.render.engine = 'CYCLES'
        s.cycles.device = 'CPU'
        s.cycles.samples = samples
        s.cycles.max_bounces = 6
        s.cycles.diffuse_bounces = 4
        s.cycles.use_denoising = False
        self.scene = s
        self.mats = {}
        self.parts = {}      # (group, mat) -> bmesh
        self.lm_size = {}    # group -> px
        self.meta = {'colliders': {'boxes': [], 'circles': []}, 'torches': [], 'waters': [], 'beams': [],
                     'regions': [], 'spawns': {}, 'exits': [], 'enemies': [], 'chests': [], 'groups': {}, 'sky': None}

    # ---------- 材質 ----------
    def material(self, key, tex_id, tint=(1, 1, 1), scale=3.0, rough=0.85):
        m = bpy.data.materials.new(key)
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes['Principled BSDF']
        img = bpy.data.images.load(os.path.join(ROOT, 'tex', f'{tex_id}_diff.jpg'))
        uv = nt.nodes.new('ShaderNodeUVMap'); uv.uv_map = 'UVMap'
        tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = img
        nt.links.new(uv.outputs['UV'], tex.inputs['Vector'])
        mix = nt.nodes.new('ShaderNodeMixRGB'); mix.blend_type = 'MULTIPLY'; mix.inputs['Fac'].default_value = 1
        mix.inputs['Color2'].default_value = (*tint, 1)
        nt.links.new(tex.outputs['Color'], mix.inputs['Color1'])
        nt.links.new(mix.outputs['Color'], bsdf.inputs['Base Color'])
        # 凹凸も光の計算に入れる
        nimg = bpy.data.images.load(os.path.join(ROOT, 'tex', f'{tex_id}_nor.jpg')); nimg.colorspace_settings.name = 'Non-Color'
        ntex = nt.nodes.new('ShaderNodeTexImage'); ntex.image = nimg
        nt.links.new(uv.outputs['UV'], ntex.inputs['Vector'])
        nmap = nt.nodes.new('ShaderNodeNormalMap'); nmap.inputs['Strength'].default_value = 0.8
        nt.links.new(ntex.outputs['Color'], nmap.inputs['Color'])
        nt.links.new(nmap.outputs['Normal'], bsdf.inputs['Normal'])
        bsdf.inputs['Roughness'].default_value = rough
        lm = nt.nodes.new('ShaderNodeTexImage'); lm.name = 'LIGHTMAP'
        luv = nt.nodes.new('ShaderNodeUVMap'); luv.uv_map = 'Lightmap'
        nt.links.new(luv.outputs['UV'], lm.inputs['Vector'])
        nt.nodes.active = lm
        self.mats[key] = {'mat': m, 'tex': tex_id, 'tint': tint, 'scale': scale}

    def emission(self, key, color, strength):
        m = bpy.data.materials.new(key); m.use_nodes = True
        nt = m.node_tree
        for n in list(nt.nodes): nt.nodes.remove(n)
        e = nt.nodes.new('ShaderNodeEmission'); e.inputs['Color'].default_value = (*color, 1); e.inputs['Strength'].default_value = strength
        o = nt.nodes.new('ShaderNodeOutputMaterial'); nt.links.new(e.outputs['Emission'], o.inputs['Surface'])
        lm = nt.nodes.new('ShaderNodeTexImage'); lm.name = 'LIGHTMAP'; nt.nodes.active = lm
        self.mats[key] = {'mat': m, 'tex': None, 'emit': color}

    def group(self, name, lm_size):
        self.lm_size[name] = lm_size

    def bm(self, group, mat):
        k = (group, mat)
        if k not in self.parts: self.parts[k] = bmesh.new()
        return self.parts[k]

    # ---------- 形 ----------
    def box(self, group, mat, c, s, rot=0.0, collide=True):
        """c=中心(x,y,z)、s=大きさ(sx,sy,sz)、rot=y軸まわり（90度単位で当たり判定）"""
        bm = self.bm(group, mat)
        ret = bmesh.ops.create_cube(bm, size=1)
        ca, sa = math.cos(rot), math.sin(rot)
        for v in ret['verts']:
            lx, ly, lz = v.co.x * s[0], v.co.z * s[1], -v.co.y * s[2]  # ローカル（ゲーム座標）
            x = c[0] + lx * ca + lz * sa
            z = c[2] - lx * sa + lz * ca
            v.co = B(x, c[1] + ly, z)
        if collide:
            swap = abs(math.sin(rot)) > 0.5
            hw, hd = (s[2] if swap else s[0]) / 2, (s[0] if swap else s[2]) / 2
            self.meta['colliders']['boxes'].append([round(c[0] - hw, 3), round(c[0] + hw, 3), round(c[2] - hd, 3), round(c[2] + hd, 3)])

    def tbox(self, group, mat, c, s, taper=0.8, collide=True):
        """上がすぼまる箱（神殿の塔門など）"""
        bm = self.bm(group, mat)
        ret = bmesh.ops.create_cube(bm, size=1)
        for v in ret['verts']:
            k = taper if v.co.z > 0 else 1.0
            lx, ly, lz = v.co.x * s[0] * k, v.co.z * s[1], -v.co.y * s[2] * (0.5 + k / 2)
            v.co = B(c[0] + lx, c[1] + ly, c[2] + lz)
        if collide:
            self.meta['colliders']['boxes'].append([c[0] - s[0] / 2, c[0] + s[0] / 2, c[2] - s[2] / 2, c[2] + s[2] / 2])

    def cyl(self, group, mat, x, z, y0, h, r1, r2, seg=28, collide=True, lying=None):
        bm = self.bm(group, mat)
        # 層は形を作る前に用意する（あとから作ると面の参照が切れる）
        lay = bm.faces.layers.int.get('cyl') or bm.faces.layers.int.new('cyl')
        uvl = bm.loops.layers.uv.verify()
        ret = bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r1, radius2=r2, depth=h)
        for v in ret['verts']:
            p = Vector(v.co)
            if lying is not None:  # 倒れた柱：y軸まわりに lying ラジアン
                p = Vector((p.z, p.y, -p.x))
                ca, sa = math.cos(lying), math.sin(lying)
                p = Vector((p.x * ca - p.y * sa, p.x * sa + p.y * ca, p.z))
                v.co = B(x, 0, z) + Vector((0, 0, y0)) + p
            else:
                v.co = B(x, y0 + h / 2, z) + p
        # 円筒に沿った模様のUV（箱投影だと伸びるため）
        circ = 2 * math.pi * max(r1, r2)
        for f in {f for v in ret['verts'] for f in v.link_faces}:
            f[lay] = 1
            for lp in f.loops:
                p = lp.vert.co - B(x, y0 + h / 2, z) if lying is None else Vector((0, 0, 0))
                ang = math.atan2(p.y, p.x) if lying is None else 0
                lp[uvl].uv = ((ang / (2 * math.pi)) * circ / 2.5, (lp.vert.co.z) / 2.5)
        if collide: self.meta['colliders']['circles'].append([x, z, max(r1, r2) + 0.05])

    def rock(self, group, mat, c, r, seed=0, rough=0.35, subdiv=3, collide=False):
        """でこぼこの岩（球をゆがめる）。r=(rx, ry, rz)"""
        bm = self.bm(group, mat)
        ret = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1)
        o = Vector((seed * 7.3, seed * 3.1, seed * 5.7))
        for v in ret['verts']:
            d = v.co.normalized()
            k = 1 + rough * noise.noise(d * 1.6 + o) + rough * 0.4 * noise.noise(d * 4.1 + o)
            v.co = B(c[0] + d.x * r[0] * k, c[1] + d.z * r[1] * k, c[2] - d.y * r[2] * k)
        if collide: self.meta['colliders']['circles'].append([c[0], c[2], min(r[0], r[2]) * 0.9])

    def terrain(self, group, mat, x0, x1, z0, z1, nx, nz, height):
        bm = self.bm(group, mat)
        verts = []
        for j in range(nz + 1):
            row = []
            for i in range(nx + 1):
                x = x0 + (x1 - x0) * i / nx; z = z0 + (z1 - z0) * j / nz
                row.append(bm.verts.new(B(x, height(x, z), z)))
            verts.append(row)
        for j in range(nz):
            for i in range(nx):
                bm.faces.new((verts[j][i], verts[j + 1][i], verts[j + 1][i + 1], verts[j][i + 1]))

    def pyramid(self, group, mat, x, z, size, h):
        bm = self.bm(group, mat)
        s = size / 2
        base = [bm.verts.new(B(x + dx, 0, z + dz)) for dx, dz in ((-s, -s), (s, -s), (s, s), (-s, s))]
        top = bm.verts.new(B(x, h, z))
        for i in range(4): bm.faces.new((base[(i + 1) % 4], base[i], top))

    # ---------- 光 ----------
    def sky(self, hdri, strength=1.0, rotation=0.0):
        w = bpy.data.worlds.new('world'); self.scene.world = w; w.use_nodes = True
        nt = w.node_tree
        env = nt.nodes.new('ShaderNodeTexEnvironment'); env.image = bpy.data.images.load(os.path.join(ROOT, 'hdri', hdri))
        mp = nt.nodes.new('ShaderNodeMapping'); mp.inputs['Rotation'].default_value[2] = rotation
        tc = nt.nodes.new('ShaderNodeTexCoord')
        nt.links.new(tc.outputs['Generated'], mp.inputs['Vector']); nt.links.new(mp.outputs['Vector'], env.inputs['Vector'])
        nt.links.new(env.outputs['Color'], nt.nodes['Background'].inputs['Color'])
        nt.nodes['Background'].inputs['Strength'].default_value = strength
        self.meta['sky'] = {'hdri': hdri, 'rotation': rotation}

    def sun(self, elevation, azimuth, energy, color=(1, 0.95, 0.85), angle=1.0):
        """azimuth：光が向かう方角（0=北=-z へ）"""
        l = bpy.data.lights.new('sun', 'SUN'); l.energy = energy; l.color = color; l.angle = math.radians(angle)
        o = bpy.data.objects.new('sun', l); self.scene.collection.objects.link(o)
        # 光の進む向き（ゲーム座標）
        el, az = math.radians(elevation), math.radians(azimuth)
        d = Vector((math.sin(az) * math.cos(el), -math.sin(el), -math.cos(az) * math.cos(el)))
        o.rotation_mode = 'QUATERNION'
        o.rotation_quaternion = Vector((0, 0, -1)).rotation_difference(B(*d))
        self.meta['sun'] = {'dir': [round(d.x, 4), round(d.y, 4), round(d.z, 4)], 'color': list(color), 'energy': energy}

    def point(self, p, energy, color=(1.0, 0.55, 0.22), torch=True, radius=0.12):
        l = bpy.data.lights.new('pt', 'POINT'); l.energy = energy; l.color = color; l.shadow_soft_size = radius
        o = bpy.data.objects.new('pt', l); o.location = B(*p); self.scene.collection.objects.link(o)
        if torch: self.meta['torches'].append([round(v, 3) for v in p])

    def area(self, p, size, energy, color, normal):
        l = bpy.data.lights.new('area', 'AREA'); l.energy = energy; l.size = size; l.color = color
        o = bpy.data.objects.new('area', l); o.location = B(*p); self.scene.collection.objects.link(o)
        o.rotation_mode = 'QUATERNION'
        o.rotation_quaternion = Vector((0, 0, -1)).rotation_difference(B(*normal))

    # ---------- 仕上げ ----------
    def _uv_and_join(self, group):
        objs = []
        keys = [k for k in self.parts if k[0] == group]
        mesh = bpy.data.meshes.new(group)
        big = bmesh.new()
        for gi, (g, mk) in enumerate(keys):
            src = self.parts[(g, mk)]
            for f in src.faces: f.material_index = gi
            tmp = bpy.data.meshes.new('tmp'); src.to_mesh(tmp); big.from_mesh(tmp); bpy.data.meshes.remove(tmp)
        big.to_mesh(mesh); big.free()
        # 模様用のUVの名前をそろえる（円柱で先に作った層があればそれを使う）
        if len(mesh.uv_layers) == 0: mesh.uv_layers.new(name='UVMap')
        else: mesh.uv_layers[0].name = 'UVMap'
        obj = bpy.data.objects.new(group, mesh); self.scene.collection.objects.link(obj)
        for g, mk in keys: mesh.materials.append(self.mats[mk]['mat'])
        bpy.ops.object.select_all(action='DESELECT')
        bpy.context.view_layer.objects.active = obj; obj.select_set(True)
        # 模様用UV（材質ごとの大きさで箱投影）
        bpy.ops.object.mode_set(mode='EDIT')
        for i, (g, mk) in enumerate(keys):
            bpy.ops.mesh.select_all(action='DESELECT')
            obj.active_material_index = i
            bpy.ops.object.material_slot_select()
            # 円柱の面は自分で貼ったUVを残す
            bm_ = bmesh.from_edit_mesh(obj.data)
            lay = bm_.faces.layers.int.get('cyl')
            if lay is not None:
                for f in bm_.faces:
                    if f[lay] == 1: f.select = False
                bmesh.update_edit_mesh(obj.data)
            bpy.ops.uv.cube_project(cube_size=self.mats[mk].get('scale', 3.0))
        bpy.ops.object.mode_set(mode='OBJECT')
        mesh.uv_layers.new(name='Lightmap'); mesh.uv_layers.active = mesh.uv_layers['Lightmap']
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.003)
        bpy.ops.object.mode_set(mode='OBJECT')
        mesh.uv_layers.active = mesh.uv_layers['UVMap']
        return obj, keys

    def _denoise_save(self, img, path, k):
        s = self.scene
        s.use_nodes = True
        tree = s.node_tree
        for n in list(tree.nodes): tree.nodes.remove(n)
        src = tree.nodes.new('CompositorNodeImage'); src.image = img
        den = tree.nodes.new('CompositorNodeDenoise'); den.use_hdr = True; den.prefilter = 'ACCURATE'
        mul = tree.nodes.new('CompositorNodeMixRGB'); mul.blend_type = 'MULTIPLY'; mul.inputs['Fac'].default_value = 1
        mul.inputs[2].default_value = (1 / k, 1 / k, 1 / k, 1)
        out = tree.nodes.new('CompositorNodeComposite')
        tree.links.new(src.outputs['Image'], den.inputs['Image'])
        tree.links.new(den.outputs['Image'], mul.inputs[1])
        tree.links.new(mul.outputs['Image'], out.inputs['Image'])
        if not s.camera:
            cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); s.collection.objects.link(cam); s.camera = cam
        s.render.resolution_x = s.render.resolution_y = img.size[0]
        s.render.resolution_percentage = 100
        samples = s.cycles.samples; s.cycles.samples = 1
        s.render.image_settings.file_format = 'PNG'; s.render.image_settings.color_depth = '8'
        s.render.image_settings.color_mode = 'RGB'
        s.view_settings.view_transform = 'Standard'; s.view_settings.look = 'None'
        s.render.filepath = path
        bpy.ops.render.render(write_still=True)
        s.cycles.samples = samples
        s.use_nodes = False

    def bake_and_export(self):
        import numpy as np
        s = self.scene
        s.render.bake.use_pass_direct = True; s.render.bake.use_pass_indirect = True; s.render.bake.use_pass_color = False
        s.render.bake.margin = 8
        exported = []
        groups = list(dict.fromkeys(g for g, _ in self.parts))
        for group in groups:
            obj, keys = self._uv_and_join(group)
            size = self.lm_size.get(group, 1024)
            img = bpy.data.images.new('lm_' + group, size, size, float_buffer=True)
            for g, mk in keys:
                nt = self.mats[mk]['mat'].node_tree
                if 'LIGHTMAP' in nt.nodes: nt.nodes['LIGHTMAP'].image = img; nt.nodes.active = nt.nodes['LIGHTMAP']
            bpy.ops.object.select_all(action='DESELECT'); bpy.context.view_layer.objects.active = obj; obj.select_set(True)
            print(f'bake {group} {size}px', flush=True)
            bpy.ops.object.bake(type='DIFFUSE', uv_layer='Lightmap')
            px = np.empty(size * size * 4, dtype=np.float32); img.pixels.foreach_get(px)
            lum = px.reshape(-1, 4)[:, :3].max(axis=1)
            k = float(max(1.0, np.percentile(lum[lum > 0], 99.7))) if (lum > 0).any() else 1.0
            self._denoise_save(img, os.path.join(self.out, f'lm_{group}.png'), k)
            self.meta['groups'][group] = {'lightmap': f'lm_{group}.png', 'k': round(k, 4),
                                          'materials': {mk: {'tex': self.mats[mk]['tex'], 'tint': list(self.mats[mk].get('tint', (1, 1, 1))),
                                                             'emit': self.mats[mk].get('emit')} for _, mk in keys}}
            # 材質ごとに分けて書き出す
            bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
            bpy.ops.mesh.separate(type='MATERIAL'); bpy.ops.object.mode_set(mode='OBJECT')
            for o in bpy.context.selected_objects:
                o.name = f'{group}__{o.active_material.name}'
                exported.append(o)
        bpy.ops.object.select_all(action='DESELECT')
        for o in exported: o.select_set(True)
        bpy.ops.export_scene.gltf(filepath=os.path.join(self.out, 'level.glb'), export_format='GLB', use_selection=True,
                                  export_texcoords=True, export_normals=True, export_materials='NONE', export_yup=True)
        with open(os.path.join(self.out, 'meta.json'), 'w') as f:
            json.dump(self.meta, f, ensure_ascii=False)
        print('exported', self.out, flush=True)

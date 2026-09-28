// エジプトの建物・小物をコードで組み立てる。
// 動かない物は材質ごとに1つにまとめて（Batcher）、描画を軽くする。
import * as THREE from 'three';
import { mergeGeometries } from '../../lib/jsm/utils/BufferGeometryUtils.js';
import * as T from './textures.js';

// ---------- 材質 ----------
const mats = new Map();
export function mat(key, make) {
  if (!mats.has(key)) mats.set(key, make());
  return mats.get(key);
}
const std = (map, color = '#ffffff', extra = {}) => new THREE.MeshStandardMaterial({ map, color, roughness: 0.92, metalness: 0, ...extra });

export const M = {
  sandstone: () => mat('sandstone', () => std(T.sandstone())),
  sandstoneDark: () => mat('sandstoneD', () => std(T.sandstone('#c49a68'))),
  mud: () => mat('mud', () => std(T.mudbrick())),
  mudWhite: () => mat('mudW', () => std(T.mudbrick('#efe2c8'))),
  mudRose: () => mat('mudR', () => std(T.mudbrick('#e2b89a'))),
  hiero: () => mat('hiero', () => std(T.hieroglyphs())),
  hieroPlain: () => mat('hieroP', () => std(T.hieroglyphs('#cfa877', false, 33))),
  paving: () => mat('paving', () => std(T.paving())),
  wood: () => mat('wood', () => std(T.wood())),
  dark: () => mat('dark', () => new THREE.MeshStandardMaterial({ color: '#2a1d14', roughness: 1 })),
  gold: () => mat('gold', () => new THREE.MeshStandardMaterial({ color: '#f2c14e', roughness: 0.3, metalness: 0.85 })),
  blue: () => mat('blue', () => new THREE.MeshStandardMaterial({ color: '#2f6fb8', roughness: 0.7 })),
  red: () => mat('red', () => new THREE.MeshStandardMaterial({ color: '#b8432f', roughness: 0.8 })),
  trunk: () => mat('trunk', () => new THREE.MeshStandardMaterial({ color: '#8a6a44', roughness: 1 })),
  clay: () => mat('clay', () => new THREE.MeshStandardMaterial({ color: '#b86a3c', roughness: 0.85 })),
  leaf: () => mat('leaf', () => new THREE.MeshStandardMaterial({ map: T.palmLeaf(), alphaTest: 0.4, side: THREE.DoubleSide, roughness: 0.9 })),
  cloth: (a, b) => mat('cloth' + a + b, () => std(T.cloth(a, b), '#ffffff', { side: THREE.DoubleSide })),
};

// ---------- まとめ役 ----------
export class Batcher {
  constructor() { this.groups = new Map(); }

  add(geometry, material, matrix, { shadow = true } = {}) {
    const g = geometry.index ? geometry.toNonIndexed() : geometry.clone();
    g.applyMatrix4(matrix);
    for (const name of Object.keys(g.attributes)) if (!['position', 'normal', 'uv'].includes(name)) g.deleteAttribute(name);
    const key = material.uuid + (shadow ? 's' : '');
    if (!this.groups.has(key)) this.groups.set(key, { material, shadow, list: [] });
    this.groups.get(key).list.push(g);
  }

  /** 箱。uv を実寸に合わせる（テクスチャが伸びない） */
  box(w, h, d, material, pos, rotY = 0, texScale = 2) {
    const geo = new THREE.BoxGeometry(w, h, d);
    scaleBoxUV(geo, w, h, d, texScale);
    this.add(geo, material, trs(pos, rotY));
  }

  build(parent) {
    for (const { material, shadow, list } of this.groups.values()) {
      const merged = mergeGeometries(list, false);
      const mesh = new THREE.Mesh(merged, material);
      mesh.castShadow = shadow; mesh.receiveShadow = true;
      mesh.matrixAutoUpdate = false;
      parent.add(mesh);
    }
    this.groups.clear();
  }
}

export function trs(pos, rotY = 0, scale = [1, 1, 1]) {
  return new THREE.Matrix4().compose(new THREE.Vector3(...pos), new THREE.Quaternion().setFromEuler(new THREE.Euler(0, rotY, 0)), new THREE.Vector3(...scale));
}

function scaleBoxUV(geo, w, h, d, s) {
  const uv = geo.attributes.uv;
  // BoxGeometry の面順：+x, -x, +y, -y, +z, -z（各4頂点）
  const size = [[d, h], [d, h], [w, d], [w, d], [w, h], [w, h]];
  for (let f = 0; f < 6; f++) for (let v = 0; v < 4; v++) {
    const i = f * 4 + v;
    uv.setXY(i, uv.getX(i) * size[f][0] / s, uv.getY(i) * size[f][1] / s);
  }
}

// ---------- 当たり判定 ----------
export class Colliders {
  constructor() { this.boxes = []; this.circles = []; }
  box(cx, cz, w, d, rotY = 0) {
    // 回転は90度単位のみ想定
    const swap = Math.abs(Math.sin(rotY)) > 0.5;
    const hw = (swap ? d : w) / 2, hd = (swap ? w : d) / 2;
    this.boxes.push({ minX: cx - hw, maxX: cx + hw, minZ: cz - hd, maxZ: cz + hd });
  }
  circle(x, z, r) { this.circles.push({ x, z, r }); }

  /** 円（半径 r）を押し戻す */
  resolve(p, r) {
    for (const b of this.boxes) {
      const nx = Math.max(b.minX, Math.min(p.x, b.maxX)), nz = Math.max(b.minZ, Math.min(p.z, b.maxZ));
      const dx = p.x - nx, dz = p.z - nz, dist2 = dx * dx + dz * dz;
      if (dist2 < r * r) {
        if (dist2 > 1e-8) { const d = Math.sqrt(dist2); p.x = nx + (dx / d) * r; p.z = nz + (dz / d) * r; }
        else {
          // 中に入り込んだ：一番近い辺へ出す
          const opts = [[b.minX - r - p.x, 0], [b.maxX + r - p.x, 0], [0, b.minZ - r - p.z], [0, b.maxZ + r - p.z]];
          opts.sort((a, c) => Math.hypot(...a) - Math.hypot(...c));
          p.x += opts[0][0]; p.z += opts[0][1];
        }
      }
    }
    for (const c of this.circles) {
      const dx = p.x - c.x, dz = p.z - c.z, d = Math.hypot(dx, dz), min = r + c.r;
      if (d < min && d > 1e-6) { p.x = c.x + (dx / d) * min; p.z = c.z + (dz / d) * min; }
    }
  }

  /** 2点の間に壁があるか（敵の視線チェック用、簡易） */
  blocked(a, b) {
    const steps = Math.ceil(a.distanceTo(b) / 0.8);
    for (let i = 1; i < steps; i++) {
      const x = a.x + (b.x - a.x) * i / steps, z = a.z + (b.z - a.z) * i / steps;
      if (this.boxes.some(q => x > q.minX && x < q.maxX && z > q.minZ && z < q.maxZ)) return true;
    }
    return false;
  }
}

// ---------- 建物・小物 ----------

/** 日干しレンガの家 */
export function house(B, C, x, z, w, d, h, rotY = 0, opts = {}) {
  const wallMat = opts.mat || M.mud();
  B.box(w, h, d, wallMat, [x, h / 2, z], rotY);
  // 屋根のふち（パラペット）
  B.box(w + 0.3, 0.35, d + 0.3, M.mudWhite(), [x, h + 0.17, z], rotY);
  C.box(x, z, w, d, rotY);
  // 正面（ローカル +z）に扉と窓
  const f = new THREE.Vector3(0, 0, 1).applyAxisAngle(new THREE.Vector3(0, 1, 0), rotY);
  const side = new THREE.Vector3(1, 0, 0).applyAxisAngle(new THREE.Vector3(0, 1, 0), rotY);
  const front = (off, y, ww, hh, m = M.dark()) => B.box(ww, hh, 0.12, m, [x + f.x * (d / 2 + 0.03) + side.x * off, y, z + f.z * (d / 2 + 0.03) + side.z * off], rotY);
  front(0, 1.05, 1.1, 2.1);
  front(0, 2.2, 1.5, 0.18, M.wood());
  if (w > 4) { front(-w / 3, h * 0.62, 0.6, 0.6); front(w / 3, h * 0.62, 0.6, 0.6); }
  if (opts.upper) {
    const uw = w * 0.55, ud = d * 0.6;
    const ux = x - side.x * (w - uw) / 2 + f.x * -(d - ud) / 2, uz = z - side.z * (w - uw) / 2 + f.z * -(d - ud) / 2;
    B.box(uw, 2.4, ud, wallMat, [ux, h + 1.2, uz], rotY);
    B.box(uw + 0.25, 0.3, ud + 0.25, M.mudWhite(), [ux, h + 2.5, uz], rotY);
  }
  if (opts.awning) {
    const a = opts.awning;
    const geo = new THREE.PlaneGeometry(w * 0.7, 1.6);
    const m = new THREE.Matrix4().compose(
      new THREE.Vector3(x + f.x * (d / 2 + 0.75), 2.6, z + f.z * (d / 2 + 0.75)),
      new THREE.Quaternion().setFromEuler(new THREE.Euler(-Math.PI / 2 + 0.35, rotY, 0, 'YXZ')), new THREE.Vector3(1, 1, 1));
    B.add(geo, M.cloth(a[0], a[1]), m);
  }
}

/** 台形（上がすぼまる）箱：塔門（パイロン）用 */
function taperedBox(w, h, d, taper) {
  const geo = new THREE.BoxGeometry(w, h, d);
  const p = geo.attributes.position;
  for (let i = 0; i < p.count; i++) if (p.getY(i) > 0) { p.setX(i, p.getX(i) * taper); p.setZ(i, p.getZ(i) * (0.5 + taper / 2)); }
  geo.computeVertexNormals();
  scaleBoxUV(geo, w, h, d, 6);
  return geo;
}

/** 神殿の塔門：2つの塔と、あいだの門 */
export function pylon(B, C, x, z, width = 26, height = 13, rotY = 0) {
  const tw = width * 0.4, td = 5;
  const side = new THREE.Vector3(1, 0, 0).applyAxisAngle(new THREE.Vector3(0, 1, 0), rotY);
  for (const s of [-1, 1]) {
    const cx = x + side.x * s * (width / 2 - tw / 2), cz = z + side.z * s * (width / 2 - tw / 2);
    B.add(taperedBox(tw, height, td, 0.82), M.hiero(), trs([cx, height / 2, cz], rotY));
    B.box(tw * 0.86, 0.6, td * 0.95, M.sandstoneDark(), [cx, height + 0.3, cz], rotY);
    C.box(cx, cz, tw, td, rotY);
    // 旗ざお
    for (const k of [-0.25, 0.25]) {
      const px = cx + side.x * k * tw, pz = cz + side.z * k * tw;
      const f = new THREE.Vector3(0, 0, 1).applyAxisAngle(new THREE.Vector3(0, 1, 0), rotY);
      B.add(new THREE.CylinderGeometry(0.12, 0.16, height + 4, 8), M.wood(), trs([px + f.x * (td / 2 + 0.3), (height + 4) / 2, pz + f.z * (td / 2 + 0.3)], rotY));
    }
  }
  // 門
  const gw = width - tw * 2;
  B.box(gw + 1, height * 0.7 - 5, td * 0.8, M.hiero(), [x, 5 + (height * 0.7 - 5) / 2, z], rotY, 5);
  B.box(gw + 1.4, 0.8, td * 0.9, M.gold(), [x, height * 0.7 + 0.4, z], rotY);
  for (const s of [-1, 1]) {
    const px = x + side.x * s * (gw / 2 + 0.4), pz = z + side.z * s * (gw / 2 + 0.4);
    B.box(0.8, 5, td * 0.8, M.sandstone(), [px, 2.5, pz], rotY);
    C.box(px, pz, 0.8, td * 0.8, rotY);
  }
}

/** パピルス柱 */
export function column(B, C, x, z, h = 7, r = 0.6, painted = true) {
  const shaft = new THREE.CylinderGeometry(r * 0.9, r, h, 16, 1);
  B.add(shaft, painted ? M.hieroPlain() : M.sandstone(), trs([x, h / 2, z]));
  const pts = [];
  for (let i = 0; i <= 10; i++) { const t = i / 10; pts.push(new THREE.Vector2(r * 0.9 + Math.pow(t, 1.8) * r * 0.9, t * 1.4)); }
  B.add(new THREE.LatheGeometry(pts, 16), M.sandstone(), trs([x, h, z]));
  B.add(new THREE.CylinderGeometry(r * 0.95, r * 0.95, 0.25, 16), M.blue(), trs([x, h - 0.4, z]));
  B.add(new THREE.CylinderGeometry(r * 0.95, r * 0.95, 0.15, 16), M.red(), trs([x, h - 0.7, z]));
  B.box(r * 2.2, 0.4, r * 2.2, M.sandstoneDark(), [x, h + 1.6, z]);
  B.add(new THREE.CylinderGeometry(r * 1.3, r * 1.4, 0.4, 16), M.sandstoneDark(), trs([x, 0.2, z]));
  C.circle(x, z, r * 1.1);
}

/** オベリスク（先端は金） */
export function obelisk(B, C, x, z, h = 12) {
  const b = h * 0.09;
  B.add(taperedBox(b, h, b, 0.6), M.hieroPlain(), trs([x, h / 2 + 0.6, z]));
  const cap = new THREE.ConeGeometry(b * 0.6 * 0.72, b * 0.8, 4, 1);
  B.add(cap, M.gold(), trs([x, h + 0.6 + b * 0.4, z], Math.PI / 4));
  B.box(b * 1.8, 0.6, b * 1.8, M.sandstoneDark(), [x, 0.3, z]);
  C.box(x, z, b * 1.8, b * 1.8);
}

/** ピラミッド（遠景用：当たり判定なし） */
export function pyramid(B, x, z, size, rotY = 0) {
  const geo = new THREE.ConeGeometry(size * 0.7071, size * 0.64, 4, 1);
  const uv = geo.attributes.uv;
  for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * size / 4, uv.getY(i) * size / 6);
  B.add(geo, M.sandstone(), trs([x, size * 0.32, z], Math.PI / 4 + rotY));
  const cap = new THREE.ConeGeometry(size * 0.06, size * 0.054, 4, 1);
  B.add(cap, M.gold(), trs([x, size * 0.64 - size * 0.027, z], Math.PI / 4 + rotY));
}

/** ヤシの木 */
export function palm(B, C, x, z, h = 7, lean = 0.2, rotY = 0) {
  const segs = 8;
  let px = x, pz = z, py = 0;
  const dir = new THREE.Vector3(Math.sin(rotY) * lean, 1, Math.cos(rotY) * lean).normalize();
  for (let i = 0; i < segs; i++) {
    const len = h / segs;
    const geo = new THREE.CylinderGeometry(0.2 - i * 0.012, 0.26 - i * 0.012, len, 7);
    const q = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir.clone().add(new THREE.Vector3(0, -i * 0.02, 0)).normalize());
    B.add(geo, M.trunk(), new THREE.Matrix4().compose(new THREE.Vector3(px, py + len / 2, pz), q, new THREE.Vector3(1, 1, 1)));
    px += dir.x * len; py += dir.y * len; pz += dir.z * len;
  }
  // 葉：垂れ下がった板を放射状に
  for (let k = 0; k < 9; k++) {
    const geo = new THREE.PlaneGeometry(1.1, 3.6, 1, 6);
    const pos = geo.attributes.position;
    for (let i = 0; i < pos.count; i++) {
      const t = (pos.getY(i) + 1.8) / 3.6;
      pos.setZ(i, -Math.pow(t, 2) * 1.6); // しなり
    }
    geo.translate(0, 1.8, 0);
    geo.rotateX(-Math.PI / 2 + 0.5);
    geo.computeVertexNormals();
    B.add(geo, M.leaf(), trs([px, py, pz], (k / 9) * Math.PI * 2 + rotY));
  }
  C.circle(x, z, 0.35);
}

/** 壺 */
export function jar(B, C, x, z, s = 1, material = M.clay()) {
  const pts = [[0, 0], [0.25, 0.02], [0.38, 0.25], [0.4, 0.5], [0.3, 0.8], [0.16, 0.9], [0.2, 1.0]].map(([a, b]) => new THREE.Vector2(a * s, b * s));
  B.add(new THREE.LatheGeometry(pts, 12), material, trs([x, 0, z]));
  if (C) C.circle(x, z, 0.35 * s);
}

/** 市場の屋台 */
export function stall(B, C, x, z, rotY = 0, colors = ['#c8412f', '#f1e3c4']) {
  const w = 3.4, d = 2.2;
  const rot = v => v.applyAxisAngle(new THREE.Vector3(0, 1, 0), rotY);
  for (const [sx, sz] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) {
    const p = rot(new THREE.Vector3(sx * w / 2, 0, sz * d / 2));
    B.add(new THREE.CylinderGeometry(0.06, 0.06, 2.6, 6), M.wood(), trs([x + p.x, 1.3, z + p.z]));
  }
  B.box(w, 0.12, d * 0.8, M.wood(), [x, 0.9, z], rotY);
  B.box(w * 0.95, 0.85, 0.1, M.wood(), [x + rot(new THREE.Vector3(0, 0, d * 0.4)).x, 0.45, z + rot(new THREE.Vector3(0, 0, d * 0.4)).z], rotY);
  const geo = new THREE.PlaneGeometry(w + 0.4, d + 0.6);
  B.add(geo, M.cloth(...colors), new THREE.Matrix4().compose(new THREE.Vector3(x, 2.65, z),
    new THREE.Quaternion().setFromEuler(new THREE.Euler(-Math.PI / 2 + 0.15, rotY, 0, 'YXZ')), new THREE.Vector3(1, 1, 1)));
  // 売り物
  const goods = [M.gold(), M.red(), M.blue(), M.clay()];
  for (let i = 0; i < 5; i++) {
    const p = rot(new THREE.Vector3(-w / 2 + 0.5 + i * 0.6, 0, 0));
    B.add(new THREE.SphereGeometry(0.16, 8, 6), goods[i % goods.length], trs([x + p.x, 1.08, z + p.z]));
  }
  C.box(x, z, w, d * 0.8, rotY);
}

/** 井戸 */
export function well(B, C, x, z) {
  const ring = new THREE.CylinderGeometry(1.3, 1.4, 0.9, 20, 1, true);
  B.add(ring, M.sandstone(), trs([x, 0.45, z]));
  B.add(new THREE.CylinderGeometry(1.1, 1.1, 0.1, 20), M.blue(), trs([x, 0.6, z]));
  B.add(new THREE.TorusGeometry(1.35, 0.12, 6, 20), M.sandstoneDark(), new THREE.Matrix4().compose(new THREE.Vector3(x, 0.9, z), new THREE.Quaternion().setFromEuler(new THREE.Euler(Math.PI / 2, 0, 0)), new THREE.Vector3(1, 1, 1)));
  C.circle(x, z, 1.5);
}

/** 長い壁（城壁） */
export function wall(B, C, x1, z1, x2, z2, h = 5, t = 1.6, material = M.mud()) {
  const len = Math.hypot(x2 - x1, z2 - z1), rot = Math.atan2(x2 - x1, z2 - z1);
  const cx = (x1 + x2) / 2, cz = (z1 + z2) / 2;
  B.box(t, h, len, material, [cx, h / 2, cz], rot, 3);
  B.box(t + 0.3, 0.4, len, M.mudWhite(), [cx, h + 0.2, cz], rot, 3);
  // 当たり判定：軸に沿った壁だけ
  if (Math.abs(x2 - x1) < 0.01) C.box(cx, cz, t, len);
  else if (Math.abs(z2 - z1) < 0.01) C.box(cx, cz, len, t);
}

/** 石棺 */
export function sarcophagus(B, C, x, z, rotY = 0) {
  B.box(1.1, 0.8, 2.4, M.sandstoneDark(), [x, 0.4, z], rotY);
  B.box(1.0, 0.25, 2.3, M.hiero(), [x, 0.92, z], rotY);
  const f = new THREE.Vector3(0, 0, 0.7).applyAxisAngle(new THREE.Vector3(0, 1, 0), rotY);
  B.add(new THREE.SphereGeometry(0.28, 12, 8), M.gold(), trs([x + f.x, 1.05, z + f.z], rotY, [1, 0.5, 1.2]));
  C.box(x, z, 1.1, 2.4, rotY);
}

/** 小舟（パピルス舟） */
export function boat(B, x, z, rotY = 0) {
  const hull = new THREE.CylinderGeometry(0.7, 0.7, 6, 12, 8, false, 0, Math.PI);
  const p = hull.attributes.position;
  for (let i = 0; i < p.count; i++) {
    const y = p.getY(i) / 3; // -1..1（舟の長さ方向）
    p.setX(i, p.getX(i) * (1 - y * y * 0.7));
    p.setZ(i, p.getZ(i) * (1 - y * y * 0.7) + y * y * 0.9);
  }
  hull.computeVertexNormals();
  const m = new THREE.Matrix4().compose(new THREE.Vector3(x, 0.55, z), new THREE.Quaternion().setFromEuler(new THREE.Euler(0, rotY, Math.PI / 2, 'YXZ')), new THREE.Vector3(1, 1, 1));
  B.add(hull, M.trunk(), m);
}

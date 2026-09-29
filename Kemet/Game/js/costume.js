// ネフィの衣装：体の形から作るケープ（体と一緒に動く）、金の胸飾り（ウセク）、ホルスの眼の額飾り、腰のルーペと手帳
// 形はすべてコードで作るので、ファイルは増えない
import * as THREE from 'three';
import { makeHair } from './hair.js';

const GOLD = new THREE.Color('#e9b949'), LAPIS = new THREE.Color('#1d3f9e'), LAPIS2 = new THREE.Color('#2c5cc8'), TURQ = new THREE.Color('#2bb3a6');

/** 骨の元の位置（体の座標） */
function bindPos(skel, bone) {
  const i = skel.bones.indexOf(bone);
  return i < 0 ? null : new THREE.Vector3().setFromMatrixPosition(skel.boneInverses[i].clone().invert());
}

let ramp = null;
function toonRamp() {
  if (ramp) return ramp;
  ramp = new THREE.DataTexture(new Uint8Array([80, 160, 230, 255]), 4, 1, THREE.RedFormat);
  ramp.minFilter = ramp.magFilter = THREE.NearestFilter; ramp.needsUpdate = true;
  return ramp;
}

/** 体の肌の面を選んで少しふくらませ、同じ骨で動く服にする */
function garment(body, { pick, off, shape, color, name }) {
  const g = body.geometry, P = g.attributes.position, N = g.attributes.normal, SI = g.attributes.skinIndex, SW = g.attributes.skinWeight;
  const idx = g.index.array, mats = [].concat(body.material);
  const map = new Map(), pos = [], si = [], sw = [], col = [], tri = [];
  const p = new THREE.Vector3(), n = new THREE.Vector3(), c = new THREE.Color();
  const take = vi => {
    if (map.has(vi)) return map.get(vi);
    p.fromBufferAttribute(P, vi); n.fromBufferAttribute(N, vi);
    const o = p.clone().addScaledVector(n, off(p, n)); if (shape) shape(p, o);
    pos.push(o.x, o.y, o.z);
    si.push(SI.getX(vi), SI.getY(vi), SI.getZ(vi), SI.getW(vi)); sw.push(SW.getX(vi), SW.getY(vi), SW.getZ(vi), SW.getW(vi));
    color(p, c); col.push(c.r, c.g, c.b);
    map.set(vi, pos.length / 3 - 1); return pos.length / 3 - 1;
  };
  const a = new THREE.Vector3(), b = new THREE.Vector3(), d = new THREE.Vector3();
  for (const gr of g.groups) {
    if (!/Body_00_SKIN/.test((mats[gr.materialIndex] || {}).name || '')) continue;
    for (let t = gr.start; t < gr.start + gr.count; t += 3) {
      a.fromBufferAttribute(P, idx[t]); b.fromBufferAttribute(P, idx[t + 1]); d.fromBufferAttribute(P, idx[t + 2]);
      if (pick(a.add(b).add(d).multiplyScalar(1 / 3))) tri.push(take(idx[t]), take(idx[t + 1]), take(idx[t + 2]));
    }
  }
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  geo.setAttribute('skinIndex', new THREE.Uint16BufferAttribute(si, 4));
  geo.setAttribute('skinWeight', new THREE.Float32BufferAttribute(sw, 4));
  geo.setAttribute('color', new THREE.Float32BufferAttribute(col, 3));
  geo.setIndex(tri); geo.computeVertexNormals();
  const mesh = new THREE.SkinnedMesh(geo, new THREE.MeshToonMaterial({ vertexColors: true, side: THREE.DoubleSide, gradientMap: toonRamp() }));
  mesh.name = name; mesh.bind(body.skeleton, body.bindMatrix); mesh.frustumCulled = false; mesh.castShadow = true;
  body.parent.add(mesh);
  return mesh;
}

/** 骨に小物をつける（位置は体の座標で指定） */
function attach(skel, bone, obj, bindPoint) {
  const i = skel.bones.indexOf(bone);
  obj.position.copy(bindPoint).applyMatrix4(skel.boneInverses[i]);
  bone.add(obj);
  return obj;
}

const gold = () => new THREE.MeshStandardMaterial({ color: '#f0c050', metalness: 0.85, roughness: 0.28, emissive: '#3a2606' });
const lapis = () => new THREE.MeshStandardMaterial({ color: '#2150c0', metalness: 0.4, roughness: 0.25, emissive: '#0a1a50' });

/** 髪の色を変える（テクスチャをフィルターで塗り直す） */
function retint(mat, filter) {
  for (const key of ['map', 'shadeMultiplyTexture']) {
    const u = mat.uniforms?.[key]; const t = u?.value || mat[key]; if (!t?.image) continue;
    const img = t.image, c = document.createElement('canvas'); c.width = img.width; c.height = img.height;
    const x = c.getContext('2d'); x.filter = filter; x.drawImage(img, 0, 0);
    const n = new THREE.CanvasTexture(c); n.colorSpace = t.colorSpace; n.flipY = t.flipY; n.wrapS = t.wrapS; n.wrapT = t.wrapT;
    if (u) u.value = n; else mat[key] = n;
    mat.needsUpdate = true;
  }
}

/** ひだのあるスカート：腰から太ももの半ばまで。上は腰の骨、下は近い方の太ももの骨で動く */
function pleatedSkirt(body, skel, bone, bp, waistY) {
  const hipsB = skel.bones.indexOf(bone('hips')), lT = skel.bones.indexOf(bone('leftUpperLeg')), rT = skel.bones.indexOf(bone('rightUpperLeg'));
  const lx = bp('leftUpperLeg').x, knee = bp('leftLowerLeg').y;
  // 腰まわりの大きさ（体の点から）
  const P = body.geometry.attributes.position; let rx = 0, rz = 0, cz = 0, n = 0;
  for (let i = 0; i < P.count; i++) { const y = P.getY(i); if (Math.abs(y - waistY) < 0.02) { rx = Math.max(rx, Math.abs(P.getX(i))); cz += P.getZ(i); n++; } }
  cz /= Math.max(1, n);
  for (let i = 0; i < P.count; i++) { const y = P.getY(i); if (Math.abs(y - waistY) < 0.02) rz = Math.max(rz, Math.abs(P.getZ(i) - cz)); }
  const bottom = knee + (waistY - knee) * 0.38, RINGS = 9, SEG = 48, pos = [], si = [], sw = [], col = [], idx = [];
  const cc = new THREE.Color();
  for (let r = 0; r <= RINGS; r++) {
    const t = r / RINGS, y = waistY - (waistY - bottom) * t;
    for (let k = 0; k <= SEG; k++) {
      const a = k / SEG * Math.PI * 2, pleat = 1 + 0.06 * t * Math.cos(a * 12);
      const fl = 1.12 + t * 0.75;
      const x = Math.cos(a) * (rx + 0.012) * fl * pleat, z = cz + Math.sin(a) * (rz + 0.012) * fl * pleat;
      pos.push(x, y, z);
      const side = Math.sign(x) === Math.sign(lx) ? lT : rT, wl = Math.min(0.75, t * 0.9) * Math.min(1, Math.abs(x) / (rx * 0.5));
      si.push(hipsB, side, 0, 0); sw.push(1 - wl, wl, 0, 0);
      cc.copy(LAPIS); if (t > 0.86) cc.copy(GOLD); else if (t > 0.76) cc.set('#f5f1e6'); else if (Math.cos(a * 12) > 0.85) cc.copy(LAPIS2);
      col.push(cc.r, cc.g, cc.b);
    }
  }
  for (let r = 0; r < RINGS; r++) for (let k = 0; k < SEG; k++) { const a = r * (SEG + 1) + k, b = a + 1, c = a + SEG + 1, d = c + 1; idx.push(a, c, b, b, c, d); }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute('skinIndex', new THREE.Uint16BufferAttribute(si, 4)); g.setAttribute('skinWeight', new THREE.Float32BufferAttribute(sw, 4));
  g.setAttribute('color', new THREE.Float32BufferAttribute(col, 3)); g.setIndex(idx); g.computeVertexNormals();
  const m = new THREE.SkinnedMesh(g, new THREE.MeshToonMaterial({ vertexColors: true, side: THREE.DoubleSide, gradientMap: toonRamp() }));
  m.bind(skel, body.bindMatrix); m.frustumCulled = false; m.castShadow = true; body.parent.add(m);
  return { rx, rz, cz, y: waistY };
}

/** 探偵のケープ：首から胸の下まで、体のまわりをなめらかに包む輪を重ねる。わきは二の腕の骨で動く */
function capelet(body, skel, bone, neck, upper, lsh) {
  const P = body.geometry.attributes.position, BINS = 36;
  const top = neck.y - 0.005, bottom = upper.y - 0.14, RINGS = 8;
  const chestB = skel.bones.indexOf(bone('upperChest') || bone('chest'));
  const armL = skel.bones.indexOf(bone('leftUpperArm')), armR = skel.bones.indexOf(bone('rightUpperArm'));
  const cx = 0, cz = neck.z + 0.01, maxR = Math.abs(lsh.x) + 0.05;
  // 高さごと・向きごとに、体のいちばん外側（腕はのぞく）
  const rad = [];
  for (let r = 0; r <= RINGS; r++) {
    const y = top - (top - bottom) * (r / RINGS), row = new Array(BINS).fill(0.06);
    for (let i = 0; i < P.count; i++) {
      const vy = P.getY(i); if (vy > y + 0.045 || vy < y - 0.045) continue;
      const x = P.getX(i) - cx, z = P.getZ(i) - cz, d = Math.hypot(x, z); if (d > maxR) continue;
      const b = Math.floor(((Math.atan2(z, x) + Math.PI * 2) % (Math.PI * 2)) / (Math.PI * 2) * BINS);
      row[b] = Math.max(row[b], d);
    }
    rad.push(row);
  }
  // 下へいくほど広く（上の輪より内側に入らない）、となりとなめらかに
  for (let r = 0; r <= RINGS; r++) {
    const row = rad[r];
    for (let k = 0; k < 2; k++) for (let b = 0; b < BINS; b++) row[b] = Math.max(row[b], (row[(b + BINS - 1) % BINS] + row[(b + 1) % BINS]) / 2 * 0.98);
    if (r) for (let b = 0; b < BINS; b++) row[b] = Math.max(row[b], rad[r - 1][b] + 0.004);
  }
  const SEG = 72, pos = [], si = [], sw = [], col = [], idx = [], c = new THREE.Color();
  for (let r = 0; r <= RINGS; r++) {
    const t = r / RINGS, y = top - (top - bottom) * t;
    for (let k = 0; k <= SEG; k++) {
      const a = k / SEG * Math.PI * 2, f = (a / (Math.PI * 2)) * BINS, b0 = Math.floor(f) % BINS, b1 = (b0 + 1) % BINS, w = f - Math.floor(f);
      const d = (rad[r][b0] * (1 - w) + rad[r][b1] * w) + 0.032 + t * 0.015;
      const x = cx + Math.cos(a) * d, z = cz + Math.sin(a) * d;
      pos.push(x, y - t * t * 0.01, z);
      const side = Math.abs(Math.cos(a)) * t, arm = x > 0 === (lsh.x > 0) ? armL : armR;
      si.push(chestB, arm, 0, 0); sw.push(1 - side * 0.5, side * 0.5, 0, 0);
      c.copy(LAPIS); if (t > 0.88) c.copy(GOLD); else if (t > 0.8) c.copy(LAPIS2); if (t < 0.08) c.copy(GOLD);
      col.push(c.r, c.g, c.b);
    }
  }
  for (let r = 0; r < RINGS; r++) for (let k = 0; k < SEG; k++) { const a = r * (SEG + 1) + k, b = a + 1, cc = a + SEG + 1, d = cc + 1; idx.push(a, cc, b, b, cc, d); }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute('skinIndex', new THREE.Uint16BufferAttribute(si, 4)); g.setAttribute('skinWeight', new THREE.Float32BufferAttribute(sw, 4));
  g.setAttribute('color', new THREE.Float32BufferAttribute(col, 3)); g.setIndex(idx); g.computeVertexNormals();
  const m = new THREE.SkinnedMesh(g, new THREE.MeshToonMaterial({ vertexColors: true, side: THREE.DoubleSide, gradientMap: toonRamp() }));
  m.bind(skel, body.bindMatrix); m.frustumCulled = false; m.castShadow = true; body.parent.add(m);
}

export function dressNefi(vrm) {
  const H = vrm.humanoid, bone = n => H.getRawBoneNode(n);
  let body = null;
  vrm.scene.traverse(o => { if (!body && o.isSkinnedMesh && [].concat(o.material).some(m => /Body_00_SKIN/.test(m.name))) body = o; });
  if (!body) return;
  const skel = body.skeleton, bp = n => bindPos(skel, bone(n));
  const neck = bp('neck'), upper = bp('upperChest') || bp('chest'), lsh = bp('leftUpperArm'), lel = bp('leftLowerArm'), hips = bp('hips'), head = bp('head');
  const front = -1;   // VRM0 の体は -z が前
  // 見本の髪と服はかくし、髪・服はオリジナルを作る（体と顔の土台だけを使う）
  let face = null;
  vrm.scene.traverse(o => {
    if (!o.isMesh) return;
    for (const m of [].concat(o.material)) {
      if (/HAIR|Tops/.test(m.name)) m.visible = false;
      if (/EyeIris/.test(m.name)) retint(m, 'sepia(1) saturate(3.2) hue-rotate(-12deg) brightness(1.15)');   // 金の瞳
    }
    if (!face && [].concat(o.material).some(m => /Face_00_SKIN/.test(m.name))) face = o;
  });
  {
    // 頭の大きさ：顔と後頭部の肌の点から測る
    const bb = new THREE.Box3(), v = new THREE.Vector3();
    vrm.scene.traverse(o => {
      if (!o.isSkinnedMesh) return;
      const mats = [].concat(o.material), P = o.geometry.attributes.position, idx = o.geometry.index.array;
      for (const gr of o.geometry.groups) {
        const m = mats[gr.materialIndex]; if (!/SKIN/.test(m?.name || '')) continue;
        for (let t = gr.start; t < gr.start + gr.count; t++) { v.fromBufferAttribute(P, idx[t]); if (v.y > neck.y + 0.06 && Math.abs(v.x) < 0.14) bb.expandByPoint(v); }
      }
    });
    const C = bb.getCenter(new THREE.Vector3()), sz = bb.getSize(new THREE.Vector3());
    const R = sz.x / 2, Rz = sz.z / 2;
    C.y = bb.max.y - R * 1.02;
    const hair = makeHair(new THREE.Vector3(), R, toonRamp(), Rz / R);
    attach(skel, bone('head'), hair.group, C);
    vrm.costumeUpdate = hair.update;
    // 額飾り：前髪の上を通る金の輪と、ホルスの眼（ラピスの石）
    const band = new THREE.Mesh(new THREE.TorusGeometry(1, 0.06, 6, 48), gold());
    band.scale.set(R * 1.13, R * 1.13, R * 1.13 * Rz / R); band.rotation.x = Math.PI / 2 - 0.3;
    attach(skel, bone('head'), band, C.clone().add(new THREE.Vector3(0, R * 0.42, 0)));
    const eye = new THREE.Group();
    eye.add(new THREE.Mesh(new THREE.SphereGeometry(0.012, 16, 10), lapis()));
    const lid = new THREE.Mesh(new THREE.TorusGeometry(0.019, 0.0035, 6, 24), gold()); lid.scale.set(1.5, 0.8, 1); eye.add(lid);
    const tear = new THREE.Mesh(new THREE.BoxGeometry(0.004, 0.02, 0.004), gold()); tear.position.set(0.004, -0.018, 0); eye.add(tear);
    attach(skel, bone('head'), eye, C.clone().add(new THREE.Vector3(0, R * 0.62, -Rz * 1.12)));
  }

  // 上着：白い巫女服（体にそう）。えりと裾に金、胸にラピスの線
  const WHITE = new THREE.Color('#f5f1e6');
  const waistY = hips.y + 0.07;
  garment(body, {
    name: 'blouse',
    pick: p => p.y > waistY - 0.03 && p.y < neck.y + 0.035 && Math.abs(p.x) < Math.abs(lsh.x) + 0.02,
    off: () => 0.011,
    color: (p, c) => { c.copy(WHITE); },
  });
  // 袖：肩からひじは細く、ひじから先はふわっと広がる（袖口はラピスと金）
  garment(body, {
    name: 'sleeves',
    pick: p => Math.abs(p.x) >= Math.abs(lsh.x) + 0.0 && Math.abs(p.x) < Math.abs(bp('leftHand').x) - 0.03,
    off: () => 0.012,
    shape: (p, o) => { const k = THREE.MathUtils.clamp((Math.abs(p.x) - Math.abs(lel.x)) / (Math.abs(bp('leftHand').x) - Math.abs(lel.x)), 0, 1); o.y += (o.y - lel.y) * k * 1.4 - k * 0.02; o.z += (o.z - lel.z) * k * 1.4; },
    color: (p, c) => { c.copy(WHITE); },
  });
  const SK = pleatedSkirt(body, skel, bone, bp, waistY);

  // ケープ（探偵のケープ風）：肩から胸・二の腕までをおおい、すそは広がる。ふちは金、内側に一本の金線
  capelet(body, skel, bone, neck, upper, lsh);
  // 腰：金の帯、ホルスの眼のルーペ（虫めがね）、古い手帳
  const belt = new THREE.Mesh(new THREE.TorusGeometry(0.125, 0.012, 6, 40), gold()); belt.rotation.x = Math.PI / 2; belt.scale.set(1, 0.82, 1);
  belt.scale.set(SK.rx * 1.2 / 0.125, SK.rz * 1.2 / 0.125, 1); attach(skel, bone('hips'), belt, new THREE.Vector3(0, SK.y + 0.004, SK.cz));
  const loupe = new THREE.Group();
  const rim = new THREE.Mesh(new THREE.TorusGeometry(0.035, 0.006, 8, 30), gold()); loupe.add(rim);
  const glass = new THREE.Mesh(new THREE.CircleGeometry(0.033, 24), new THREE.MeshStandardMaterial({ color: '#bfe8ff', metalness: 0.2, roughness: 0.05, transparent: true, opacity: 0.45, side: THREE.DoubleSide })); loupe.add(glass);
  const grip = new THREE.Mesh(new THREE.CylinderGeometry(0.007, 0.009, 0.08, 10), gold()); grip.position.y = -0.075; loupe.add(grip);
  loupe.rotation.set(0.2, 1.3, 0.25);
  attach(skel, bone('hips'), loupe, new THREE.Vector3(0.13, hips.y + 0.02, hips.z + front * 0.02));
  const book = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.085, 0.022), new THREE.MeshStandardMaterial({ color: '#6b4a2a', roughness: 0.8 }));
  book.rotation.y = 0.3;
  attach(skel, bone('hips'), book, new THREE.Vector3(-0.13, hips.y + 0.0, hips.z + 0.03));
  // 腕輪
  for (const s of ['left', 'right']) {
    const la = bone(s + 'LowerArm'), hand = bp(s + 'Hand'); if (!la || !hand) continue;
    const r = new THREE.Mesh(new THREE.CylinderGeometry(0.032, 0.032, 0.035, 20, 1, true), gold()); r.rotation.z = Math.PI / 2;
    attach(skel, la, r, new THREE.Vector3(hand.x * 0.93, hand.y, hand.z));
  }
}

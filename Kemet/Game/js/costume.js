// ネフィの衣装：体の形から作るケープ（体と一緒に動く）、金の胸飾り（ウセク）、ホルスの眼の額飾り、腰のルーペと手帳
// 形はすべてコードで作るので、ファイルは増えない
import * as THREE from 'three';

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

export function dressNefi(vrm) {
  const H = vrm.humanoid, bone = n => H.getRawBoneNode(n);
  let body = null;
  vrm.scene.traverse(o => { if (!body && o.isSkinnedMesh && [].concat(o.material).some(m => /Body_00_SKIN/.test(m.name))) body = o; });
  if (!body) return;
  const skel = body.skeleton, bp = n => bindPos(skel, bone(n));
  const neck = bp('neck'), upper = bp('upperChest') || bp('chest'), lsh = bp('leftUpperArm'), lel = bp('leftLowerArm'), hips = bp('hips'), head = bp('head');
  const front = -1;   // VRM0 の体は -z が前
  // 髪：ほんのりラピスがかった黒
  vrm.scene.traverse(o => { if (o.isMesh) for (const m of [].concat(o.material)) if (/HAIR/.test(m.name)) retint(m, 'grayscale(1) brightness(0.55) sepia(1) hue-rotate(185deg) saturate(2.2) brightness(0.75)'); });

  // ケープ（探偵のケープ風）：肩から胸・二の腕までをおおい、すそは広がる。ふちは金、内側に一本の金線
  const capeBottom = upper.y - 0.13, armOut = Math.abs(lel.x) - 0.02;
  garment(body, {
    name: 'cape',
    pick: p => p.y > capeBottom && p.y < neck.y + 0.01 && Math.abs(p.x) < armOut,
    off: p => 0.075 + Math.max(0, (upper.y - p.y)) * 0.25,
    shape: (p, o) => { const k = Math.max(0, (neck.y - p.y) / (neck.y - capeBottom)); o.x += Math.sign(p.x) * k * k * 0.05; o.y -= k * k * 0.02; },
    color: (p, c) => { c.copy(LAPIS); if (p.y < capeBottom + 0.018) c.copy(GOLD); else if (p.y < capeBottom + 0.034) c.copy(LAPIS2); if (p.y > neck.y - 0.012) c.copy(GOLD); },
  });
  // 胸飾り（ウセク）：金・ラピス・トルコ石の半円の輪を重ねる（ケープの上）
  const us = new THREE.Group();
  const bands = [GOLD, LAPIS, GOLD, TURQ, GOLD];
  bands.forEach((c, i) => {
    const r = 0.07 + i * 0.013;
    const t = new THREE.Mesh(new THREE.TorusGeometry(r, 0.0075, 6, 36, Math.PI), new THREE.MeshStandardMaterial({ color: c, metalness: c === GOLD ? 0.85 : 0.3, roughness: 0.3, emissive: c.clone().multiplyScalar(0.12) }));
    t.rotation.set(-Math.PI / 2 - 0.55, 0, 0); t.scale.set(1.15, 1, 1); us.add(t);
  });
  attach(skel, bone('upperChest') || bone('chest'), us, new THREE.Vector3(0, neck.y - 0.035, neck.z + front * 0.045));
  // 額飾り：金の輪と、ホルスの眼（ラピスの石）
  const band = new THREE.Mesh(new THREE.TorusGeometry(0.1, 0.006, 6, 48), gold());
  band.rotation.x = Math.PI / 2 - 0.22;
  attach(skel, bone('head'), band, new THREE.Vector3(0, head.y + 0.105, head.z + front * 0.005));
  const eye = new THREE.Group();
  const gem = new THREE.Mesh(new THREE.SphereGeometry(0.013, 16, 10), lapis()); eye.add(gem);
  const lid = new THREE.Mesh(new THREE.TorusGeometry(0.02, 0.0035, 6, 24), gold()); lid.scale.set(1.5, 0.8, 1); eye.add(lid);
  const tear = new THREE.Mesh(new THREE.BoxGeometry(0.004, 0.022, 0.004), gold()); tear.position.set(0.004, -0.02, 0); eye.add(tear);
  attach(skel, bone('head'), eye, new THREE.Vector3(0, head.y + 0.125, head.z + front * 0.1));
  // 腰：金の帯、ホルスの眼のルーペ（虫めがね）、古い手帳
  const belt = new THREE.Mesh(new THREE.TorusGeometry(0.125, 0.012, 6, 40), gold()); belt.rotation.x = Math.PI / 2; belt.scale.set(1, 0.82, 1);
  attach(skel, bone('hips'), belt, new THREE.Vector3(0, hips.y + 0.08, hips.z));
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

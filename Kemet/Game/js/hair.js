// ネフィの髪（オリジナル）：前髪・横髪・後ろ髪・長いツインテール（毛先がラピス色）・アホ毛・金の髪留め
// 1房ずつ、曲線にそって細長い束を作る。ツインテールは頭の動きに少し遅れて揺れる
import * as THREE from 'three';

const BASE = new THREE.Color('#171a2c'), SHINE = new THREE.Color('#3a4266'), TIP = new THREE.Color('#2f62dc');

/** 曲線にそった髪の束。w0→w1 の幅で細くなる。平たいひし形の断面 */
function lock(pts, { w0 = 0.03, w1 = 0.002, th = 0.35, tipFrom = 0.7, tip = null, side = null } = {}) {
  const curve = new THREE.CatmullRomCurve3(pts);
  const N = 18, R = 6, pos = [], col = [], idx = [];
  const frames = curve.computeFrenetFrames(N, false);
  const c = new THREE.Color();
  for (let i = 0; i <= N; i++) {
    const t = i / N, p = curve.getPointAt(t);
    const T = curve.getTangentAt(t);
    // 幅の向き：頭の外側に向く面を平らに（side があればその向き）
    let W = side ? side.clone() : frames.binormals[i].clone();
    W.sub(T.clone().multiplyScalar(W.dot(T))).normalize();
    const D = new THREE.Vector3().crossVectors(T, W).normalize();
    const w = THREE.MathUtils.lerp(w0, w1, Math.pow(t, 1.3));
    for (let r = 0; r < R; r++) {
      const a = r / R * Math.PI * 2;
      const q = p.clone().addScaledVector(W, Math.cos(a) * w).addScaledVector(D, Math.sin(a) * w * th);
      pos.push(q.x, q.y, q.z);
      c.copy(BASE).lerp(SHINE, Math.max(0, Math.cos(a)) * 0.35 * (1 - t));
      if (tip && t > tipFrom) c.lerp(tip, Math.min(1, (t - tipFrom) / (1 - tipFrom)));
      col.push(c.r, c.g, c.b);
    }
  }
  for (let i = 0; i < N; i++) for (let r = 0; r < R; r++) {
    const a = i * R + r, b = i * R + (r + 1) % R, d = a + R, e = b + R;
    idx.push(a, d, b, b, d, e);
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute('color', new THREE.Float32BufferAttribute(col, 3));
  g.setIndex(idx); g.computeVertexNormals();
  return g;
}

const V = (x, y, z) => new THREE.Vector3(x, y, z);

/** 髪を作る。C＝頭の中心、R＝頭の半径（体の座標：前は -z）。戻り値：{ group, update(dt, headWorldPos) } */
export function makeHair(C, R, ramp, kz = 1.15) {
  const mat = new THREE.MeshToonMaterial({ vertexColors: true, side: THREE.DoubleSide, gradientMap: ramp });
  const group = new THREE.Group();
  const add = g => { const m = new THREE.Mesh(g, mat); m.castShadow = true; m.frustumCulled = false; group.add(m); return m; };
  const S = (a, y, r = 1) => V(Math.sin(a) * R * r, y * R, -Math.cos(a) * R * kz * r);   // 頭のまわりの点（a=0 が正面、前後に長いだ円）

  // 頭の地肌をおおう髪（上と後ろ）
  const capM = new THREE.MeshToonMaterial({ color: BASE, gradientMap: ramp });
  const top = new THREE.Mesh(new THREE.SphereGeometry(R * 1.07, 32, 18, 0, Math.PI * 2, 0, Math.PI * 0.46), capM); top.scale.set(1.08, 1.1, 1.08 * kz); group.add(top);
  const back = new THREE.Mesh(new THREE.SphereGeometry(R * 1.06, 24, 14, 0, Math.PI, Math.PI * 0.4, Math.PI * 0.42), capM); back.scale.set(1.08, 1.1, 1.1 * kz); group.add(back);

  // 前髪：額をおおって眉の上まで。まん中は短く、はしは長く、毛先は少し内へ
  for (let i = 0; i < 9; i++) {
    const u = i / 8 - 0.5, a = u * 2.3, len = 0.05 + Math.abs(u) * 0.9 + (i % 2) * 0.1;
    const r0 = S(a * 0.6, 0.95, 0.7), r1 = S(a, 0.55, 1.14), r2 = S(a * 1.02, 0.1 - len * 0.5, 1.13), r3 = S(a * 1.0, -0.05 - len, 1.08);
    add(lock([r0, r1, r2, r3], { w0: R * 0.5, w1: R * 0.05, th: 0.25 }));
  }
  // 横髪：顔の横を通って胸まで。毛先はラピス色
  for (const s of [-1, 1]) for (let k = 0; k < 2; k++) {
    const a = s * (1.25 + k * 0.18);
    add(lock([S(a, 0.6, 0.9), S(a, 0.1, 1.12), S(a * 0.95, -0.8, 1.05), S(a * 0.9, -1.8 - k * 0.3, 0.95), S(a * 0.86, -2.6 - k * 0.4, 0.9)], { w0: R * 0.17, w1: R * 0.02, th: 0.35, tip: TIP, tipFrom: 0.72 }));
  }
  // 後ろ髪：うなじまでのショート（ツインテール以外）
  for (let i = 0; i < 12; i++) {
    const a = Math.PI * (0.6 + i / 11 * 0.8), jitter = (i % 3) * 0.08;
    add(lock([S(a, 0.8, 0.8), S(a, 0.2, 1.14), S(a, -0.6, 1.12), S(a, -1.2 - jitter, 0.98)], { w0: R * 0.2, w1: R * 0.04, th: 0.3 }));
  }
  // アホ毛（ぴょこんと一本）
  add(lock([V(0, R * 1.02, -R * 0.1), V(R * 0.05, R * 1.35, -R * 0.2), V(R * 0.2, R * 1.55, -R * 0.1), V(R * 0.32, R * 1.45, R * 0.05)], { w0: R * 0.06, w1: R * 0.005, th: 0.4 }));

  // ツインテール：頭の横上に金の髪留め、長い束が下へ。毛先はラピス色
  const tails = [];
  const gold = new THREE.MeshStandardMaterial({ color: '#f0c050', metalness: 0.85, roughness: 0.28, emissive: '#3a2606' });
  const gem = new THREE.MeshStandardMaterial({ color: '#2150c0', metalness: 0.4, roughness: 0.2, emissive: '#0a1a50' });
  for (const s of [-1, 1]) {
    const pivot = new THREE.Group(); pivot.position.copy(V(s * R * 0.92, R * 0.55, R * 0.25)); group.add(pivot);
    const tail = new THREE.Group(); pivot.add(tail);
    for (let k = 0; k < 6; k++) {
      const sp = (k - 2.5) * 0.012, L = 0.5 + (k % 3) * 0.06;
      tail.add(new THREE.Mesh(lock([V(0, 0, 0), V(s * (0.05 + sp), -0.04, 0.02 + sp), V(s * (0.09 + sp), -0.16, 0.04), V(s * (0.08 + sp * 1.5), -L * 0.6, 0.05 + sp), V(s * (0.05 + sp * 2), -L, 0.03)],
        { w0: 0.03, w1: 0.003, th: 0.45, tip: TIP, tipFrom: 0.62 }), mat));
    }
    const ring = new THREE.Mesh(new THREE.TorusGeometry(0.022, 0.009, 8, 20), gold); ring.rotation.set(Math.PI / 2, 0, s * 0.5); pivot.add(ring);
    const g2 = new THREE.Mesh(new THREE.SphereGeometry(0.011, 12, 8), gem); g2.position.set(s * 0.012, 0.004, -0.018); pivot.add(g2);
    tails.push({ pivot: tail, s, ang: new THREE.Vector2(), vel: new THREE.Vector2() });
  }
  group.traverse(o => { if (o.isMesh) { o.castShadow = true; o.frustumCulled = false; } });
  group.position.copy(C);

  // 揺れ：頭が動いた向きと逆へ、ばねのように遅れてついてくる
  const prev = new THREE.Vector3(), cur = new THREE.Vector3(), q = new THREE.Quaternion();
  let first = true;
  function update(dt) {
    if (!dt) return;
    group.getWorldPosition(cur);
    if (first) { prev.copy(cur); first = false; }
    const v = cur.clone().sub(prev).divideScalar(Math.max(dt, 1e-3)); prev.copy(cur);
    // 頭の向きの中での速さに直す
    group.getWorldQuaternion(q); v.applyQuaternion(q.invert());
    for (const t of tails) {
      const fx = THREE.MathUtils.clamp(-v.z * 0.08, -0.9, 0.9), fz = THREE.MathUtils.clamp(v.x * 0.06 + v.y * 0.03, -0.6, 0.6);
      t.vel.x += ((fx - t.ang.x) * 60 - t.vel.x * 8) * dt; t.vel.y += ((fz - t.ang.y) * 60 - t.vel.y * 8) * dt;
      t.ang.addScaledVector(t.vel, dt);
      t.pivot.rotation.set(t.ang.x, 0, t.ang.y);
    }
  }
  return { group, update };
}

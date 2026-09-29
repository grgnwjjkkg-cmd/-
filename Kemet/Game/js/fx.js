// 技の光：ラーの円環（広がる金の輪）、セトの雷、砂走りの砂けむり、溜めの光
import * as THREE from 'three';

const add = THREE.AdditiveBlending;

export class FX {
  constructor(scene) {
    this.scene = scene;
    this.items = [];
    // 砂の粒（使い回す）
    const N = 240;
    this.sand = new THREE.Points(new THREE.BufferGeometry().setAttribute('position', new THREE.BufferAttribute(new Float32Array(N * 3), 3)),
      new THREE.PointsMaterial({ color: '#e8cf98', size: 0.08, transparent: true, opacity: 0.8, depthWrite: false }));
    this.sand.frustumCulled = false;
    this.sandV = Array.from({ length: N }, () => ({ v: new THREE.Vector3(), life: 0 }));
    this.sandI = 0;
    scene.add(this.sand);
    // 溜めの光の輪
    this.chargeRing = new THREE.Mesh(new THREE.RingGeometry(0.9, 1.0, 48).rotateX(-Math.PI / 2),
      new THREE.MeshBasicMaterial({ color: '#ffcf5a', transparent: true, opacity: 0, blending: add, depthWrite: false, side: THREE.DoubleSide }));
    scene.add(this.chargeRing);
  }

  /** 足もとから砂を舞い上げる */
  puff(pos, n = 3, spread = 0.5, up = 1.2, color) {
    const a = this.sand.geometry.attributes.position;
    for (let i = 0; i < n; i++) {
      const k = this.sandI = (this.sandI + 1) % this.sandV.length;
      a.setXYZ(k, pos.x + (Math.random() - 0.5) * spread, 0.1 + Math.random() * 0.2, pos.z + (Math.random() - 0.5) * spread);
      this.sandV[k].v.set((Math.random() - 0.5) * 2, up * (0.5 + Math.random()), (Math.random() - 0.5) * 2);
      this.sandV[k].life = 0.6 + Math.random() * 0.4;
    }
  }

  /** 広がる輪（色、最大の半径、秒） */
  ring(pos, color, maxR, dur = 0.5, y = 0.1) {
    const m = new THREE.Mesh(new THREE.RingGeometry(0.85, 1, 64).rotateX(-Math.PI / 2),
      new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 1, blending: add, depthWrite: false, side: THREE.DoubleSide }));
    m.position.set(pos.x, y, pos.z);
    this.scene.add(m);
    this.items.push({ m, t: 0, dur, update: (it, k) => { const r = 0.3 + maxR * (1 - (1 - k) ** 3); it.m.scale.set(r, 1, r); it.m.material.opacity = 1 - k; } });
  }

  /** 太陽の光の柱（ラーの円環の中心） */
  pillar(pos, color = '#ffd36a') {
    const m = new THREE.Mesh(new THREE.CylinderGeometry(0.6, 1.4, 14, 32, 1, true),
      new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.8, blending: add, depthWrite: false, side: THREE.DoubleSide }));
    m.position.set(pos.x, 7, pos.z);
    const light = new THREE.PointLight(color, 60, 18); light.position.set(pos.x, 2, pos.z);
    this.scene.add(m, light);
    this.items.push({ m, extra: [light], t: 0, dur: 0.7, update: (it, k) => { it.m.material.opacity = 0.8 * (1 - k); it.m.scale.set(1 + k, 1, 1 + k); light.intensity = 60 * (1 - k); } });
  }

  /** 空から落ちる雷 */
  bolt(to) {
    const pts = [], top = new THREE.Vector3(to.x + (Math.random() - 0.5) * 2, 22, to.z + (Math.random() - 0.5) * 2);
    for (let i = 0; i <= 10; i++) {
      const k = i / 10, p = top.clone().lerp(new THREE.Vector3(to.x, 0.2, to.z), k);
      if (i && i < 10) { p.x += (Math.random() - 0.5) * 1.6; p.z += (Math.random() - 0.5) * 1.6; }
      pts.push(p);
    }
    const geo = new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts), 40, 0.12, 6);
    const m = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ color: '#cfe4ff', transparent: true, opacity: 1, blending: add, depthWrite: false }));
    const glow = new THREE.Mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts), 40, 0.45, 6), new THREE.MeshBasicMaterial({ color: '#6a8cff', transparent: true, opacity: 0.5, blending: add, depthWrite: false }));
    const light = new THREE.PointLight('#9ab8ff', 120, 26); light.position.set(to.x, 3, to.z);
    this.scene.add(m, glow, light);
    this.items.push({ m, extra: [glow, light], t: 0, dur: 0.45, update: (it, k) => { const f = Math.random() < 0.5 ? 1 : 0.4; it.m.material.opacity = (1 - k) * f; glow.material.opacity = 0.5 * (1 - k) * f; light.intensity = 120 * (1 - k) * f; } });
  }

  /** 溜めの輪（0〜1） */
  charge(pos, k) {
    this.chargeRing.position.set(pos.x, 0.06, pos.z);
    const r = 1.2 + k * 1.6; this.chargeRing.scale.set(r, 1, r);
    this.chargeRing.material.opacity = 0.35 + k * 0.5;
    this.chargeRing.material.color.set(k >= 1 ? '#fff2b0' : '#ffb640');
    this.chargeVisible = true;
  }

  update(dt) {
    this.items = this.items.filter(it => {
      it.t += dt;
      const k = Math.min(1, it.t / it.dur);
      it.update(it, k);
      if (k >= 1) { this.scene.remove(it.m); it.m.geometry.dispose(); it.m.material.dispose(); for (const e of it.extra || []) { this.scene.remove(e); e.geometry?.dispose(); e.material?.dispose(); } return false; }
      return true;
    });
    const a = this.sand.geometry.attributes.position;
    for (let i = 0; i < this.sandV.length; i++) {
      const s = this.sandV[i]; if (s.life <= 0) { a.setY(i, -99); continue; }
      s.life -= dt; s.v.y -= 3 * dt;
      a.setXYZ(i, a.getX(i) + s.v.x * dt, Math.max(0.02, a.getY(i) + s.v.y * dt), a.getZ(i) + s.v.z * dt);
    }
    a.needsUpdate = true;
    if (!this.chargeVisible) this.chargeRing.material.opacity = 0;
    this.chargeVisible = false;
  }
}

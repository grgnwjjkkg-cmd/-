// 危ない場所：溶岩（踏むとやけど）・冷たい水（落ちると凍える）・噴き出す炎（ときどき）
// 地形の形は tools/bake/*.py の meta.json（hazards / jets）に書いてある
import * as THREE from 'three';
import { audio } from './audio.js';

/** 点 (x, z) が危ない場所の上か */
function onHazard(h, x, z) {
  if (h.box) return x > h.box[0] && x < h.box[1] && z > h.box[2] && z < h.box[3];
  if (h.circle) return Math.hypot(x - h.circle[0], z - h.circle[1]) < h.circle[2];
  if (h.seg) {
    const [x0, z0, x1, z1] = h.seg, dx = x1 - x0, dz = z1 - z0;
    const t = Math.max(0, Math.min(1, ((x - x0) * dx + (z - z0) * dz) / (dx * dx + dz * dz)));
    return Math.hypot(x - (x0 + dx * t), z - (z0 + dz * t)) < h.w / 2;
  }
  return false;
}

const MSG = { lava: '溶岩でやけど！', cold: '氷の水に落ちた！' };

export class Hazards {
  constructor(zone, scene) {
    this.list = zone.hazards || [];
    this.jets = (zone.jets || []).map(j => {
      const mat = new THREE.MeshBasicMaterial({ color: '#ff8a2a', transparent: true, opacity: 0, blending: THREE.AdditiveBlending, depthWrite: false });
      const m = new THREE.Mesh(new THREE.CylinderGeometry(0.25, 0.9, 5, 16, 1, true), mat);
      m.position.set(j.x, 2.5, j.z); scene.add(m);
      const vent = new THREE.Mesh(new THREE.RingGeometry(0.4, 0.8, 16), new THREE.MeshBasicMaterial({ color: '#ff5a1a', transparent: true, opacity: 0.6, side: THREE.DoubleSide }));
      vent.rotation.x = -Math.PI / 2; vent.position.set(j.x, 0.03, j.z); scene.add(vent);
      return { ...j, m, vent, was: false };
    });
    this.cool = 0; this.lastSafe = null;
  }

  dispose(scene) {
    for (const j of this.jets) for (const o of [j.m, j.vent]) { scene.remove(o); o.geometry.dispose(); o.material.dispose(); }
    this.jets = [];
  }

  /** 毎フレーム。g はゲーム本体（ダメージ・文字・揺れに使う） */
  update(dt, t, P, g) {
    this.cool = Math.max(0, this.cool - dt);
    const p = P.pos;
    // 噴き出す炎：周期の最初の3割だけ燃える。直前にふちが明るくなる（予告）
    for (const j of this.jets) {
      const ph = ((t + j.offset) % j.period) / j.period, on = ph < 0.3, warn = ph > 0.8;
      j.m.material.opacity = on ? 0.55 + Math.sin(t * 40) * 0.15 : 0;
      j.m.scale.set(1, on ? 0.8 + Math.sin(t * 25) * 0.2 : 0.01, 1);
      j.vent.material.opacity = warn ? 0.6 + Math.sin(t * 30) * 0.4 : on ? 1 : 0.35;
      if (on && !j.was && Math.hypot(p.x - j.x, p.z - j.z) < 18) audio.sfx('sun');
      j.was = on;
      if (on && this.cool <= 0 && Math.hypot(p.x - j.x, p.z - j.z) < 1.3 && p.y < 4.5) this.hit(P, g, 16, '炎にまかれた！', j);
    }
    // 床の危ない所（跳んでいる間は平気）
    const h = this.list.find(h => onHazard(h, p.x, p.z));
    if (!h || P.air || p.y > h.y) { if (!P.air) this.lastSafe = p.clone(); return; }
    if (this.cool > 0) return;
    this.hit(P, g, h.dmg, MSG[h.kind] || 'いたっ！', null);
    // 安全な所へ押し戻す
    if (this.lastSafe) p.copy(this.lastSafe);
    P.vy = 5; P.air = true;
  }

  hit(P, g, dmg, msg, from) {
    this.cool = 0.9;
    if (!P.alive) return;
    P.hp -= dmg; P.invuln = Math.max(P.invuln, 0.5);
    P.actor.flash?.('#ff6020'); audio.sfx('hurt');
    g.popNumber(P.pos, dmg, 'hurt'); g.shake = 0.2;
    g.fx?.puff(P.pos.clone(), 6, 0.6, 2, from ? '#ff9a3a' : undefined);
    if (g.time - (this.lastMsg || -99) > 4) { this.lastMsg = g.time; g.toast(msg); }
    if (P.hp <= 0) { P.hp = 0; P.state = 'dead'; P.actor.play('Death01', { fade: 0.1, loop: false }); g.onPlayerDown(); }
  }
}

// 第1章の探索の仕掛け
//  ・光の鏡：天井の穴から差す日の光を、鏡を回して壁の太陽円盤へ導く（浸水した柱の広間）
//  ・押す石：石を押して床の板に乗せると、祠の扉が沈む（墓地の東）
//  ・トゲの罠：通路の床からトゲが出る。タイミングを見るか、砂走りで抜ける
//  ・黄金のスカラベ：町と墓地に5つ隠れている。全部集めるとお守り
import * as THREE from 'three';
import * as B from './world/builders.js';
import { audio } from './audio.js';

export const GOLD_SCARABS = [
  { id: 'gs_town1', zone: 'town', x: -47.5, z: -66 },
  { id: 'gs_town2', zone: 'town', x: 34, z: 39 },
  { id: 'gs_nec1', zone: 'necropolis', x: -28.5, z: 43.6 },
  { id: 'gs_nec2', zone: 'necropolis', x: 5, z: -29 },
  { id: 'gs_nec3', zone: 'necropolis', x: 8.2, z: -57 },
];

const DIRS = [[0, -1], [1, 0], [0, 1], [-1, 0]];   // 北・東・南・西（-z が北）

// 光の鏡の仕掛け（浸水した柱の広間）
const MIRROR = {
  sun: 0,                                         // 日の光が当たっている鏡
  mirrors: [{ x: 3, z: -60, dir: 2 }, { x: 0, z: -60, dir: 1 }],
  disc: { x: 0, z: -79.3, y: 1.5 },               // 北の壁の太陽円盤
  bounds: [-9, 9, -80, -38],
  pillars: [-44, -52, -60, -68, -76].flatMap(z => [[-4.5, z], [4.5, z]]),
};

// 押す石（墓地の東）
const BLOCK = { start: [12, 81], plate: [15, 72], shrine: [22, 72], area: [9, 19.5, 62, 92] };

export class Puzzles {
  constructor(game, zoneName) {
    this.g = game; this.zone = zoneName; this.root = new THREE.Group(); game.scene.add(this.root);
    this.items = [];      // 調べる・回す・拾うことのできる物
    this.t = 0;
    const f = game.save.flags;
    for (const s of GOLD_SCARABS) if (s.zone === zoneName && !(game.save.scarabs || []).includes(s.id)) this.makeScarab(s);
    if (zoneName === 'necropolis') {
      this.makeMirrors(!!f.necMirror);
      this.makeBlock(!!f.necBlock);
      this.makeSpikes();
    }
  }

  dispose() {
    this.g.scene.remove(this.root);
    this.root.traverse(o => { o.geometry?.dispose(); });
    for (const c of this.cols || []) { const a = this.g.zone.colliders.boxes, i = a.indexOf(c); if (i >= 0) a.splice(i, 1); }
  }

  addBox(b) { (this.cols ||= []).push(b); this.g.zone.colliders.boxes.push(b); return b; }

  // ---------- 黄金のスカラベ ----------
  makeScarab(s) {
    const grp = new THREE.Group();
    const gold = new THREE.MeshStandardMaterial({ color: '#ffd35a', metalness: 0.9, roughness: 0.25, emissive: '#7a4a08', emissiveIntensity: 0.8 });
    const body = new THREE.Mesh(new THREE.SphereGeometry(0.16, 16, 10), gold); body.scale.set(1, 0.55, 1.35); grp.add(body);
    const head = new THREE.Mesh(new THREE.SphereGeometry(0.07, 10, 8), gold); head.position.set(0, 0, 0.22); grp.add(head);
    const glow = new THREE.Mesh(new THREE.SphereGeometry(0.5, 12, 8), new THREE.MeshBasicMaterial({ color: '#ffcf5a', transparent: true, opacity: 0.12, blending: THREE.AdditiveBlending, depthWrite: false }));
    grp.add(glow);
    grp.position.set(s.x, 0.45, s.z);
    this.root.add(grp);
    const it = { kind: 'scarab', def: s, mesh: grp, label: '拾う', x: s.x, z: s.z, r: 1.6 };
    it.act = () => this.takeScarab(it);
    this.items.push(it);
  }

  takeScarab(it) {
    const g = this.g, list = (g.save.scarabs ||= []);
    list.push(it.def.id);
    this.root.remove(it.mesh); this.items.splice(this.items.indexOf(it), 1);
    audio.sfx('rare');
    g.fx?.pillar(it.mesh.position.clone().setY(0), '#ffd36a');
    const n = list.length, all = GOLD_SCARABS.length;
    g.toast(`黄金のスカラベを見つけた！（${n} / ${all}）`);
    g.gainAnkh(50);
    if (n >= all && !g.save.flags.allScarabs) {
      g.save.flags.allScarabs = true;
      setTimeout(() => g.runSteps([{ who: 'narr', text: `黄金のスカラベが${all}つそろった！` }, { run: a => a.giveItem('ankh_charm') }, { who: 'narr', text: 'スカラベたちが光り、「アンクの首飾り」に姿を変えた。' }]), 600);
    }
    g.persist();
  }

  // ---------- 光の鏡 ----------
  makeMirrors(solved) {
    const stone = B.M.pbr('sandstone_blocks_08'), bronze = new THREE.MeshStandardMaterial({ color: '#e8c078', metalness: 1, roughness: 0.15, emissive: '#402808' });
    this.mirrors = MIRROR.mirrors.map((m, i) => {
      const grp = new THREE.Group(); grp.position.set(m.x, 0, m.z);
      const ped = new THREE.Mesh(new THREE.CylinderGeometry(0.35, 0.45, 0.9, 12), stone); ped.position.y = 0.45; grp.add(ped);
      const head = new THREE.Group(); head.position.y = 1.4; grp.add(head);
      const frame = new THREE.Mesh(new THREE.TorusGeometry(0.42, 0.06, 8, 24), bronze); head.add(frame);
      const face = new THREE.Mesh(new THREE.CircleGeometry(0.4, 24), bronze.clone()); face.material.side = THREE.DoubleSide; head.add(face);
      const post = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.05, 0.5, 6), bronze); post.position.y = -0.3; head.add(post);
      this.root.add(grp);
      this.g.zone.colliders.circle(m.x, m.z, 0.45);
      const it = { kind: 'mirror', label: '鏡を回す', x: m.x, z: m.z, r: 1.8, grp, head, face, dir: solved ? [3, 0][i] : m.dir, yaw: 0, idx: i };
      it.act = () => { if (this.g.save.flags.necMirror) return; it.dir = (it.dir + 1) % 4; audio.sfx('stone'); this.traceBeam(true); };
      this.items.push(it);
      return it;
    });
    // 北の壁の太陽円盤
    const D = MIRROR.disc;
    const discMat = new THREE.MeshStandardMaterial({ color: '#c9a050', metalness: 0.8, roughness: 0.35, emissive: '#ffb640', emissiveIntensity: solved ? 2.5 : 0.05 });
    this.disc = new THREE.Mesh(new THREE.CylinderGeometry(0.9, 0.9, 0.15, 32), discMat);
    this.disc.rotation.x = Math.PI / 2; this.disc.position.set(D.x, D.y, D.z + 0.2); this.root.add(this.disc);
    for (let i = 0; i < 12; i++) {   // 光線の飾り
      const a = i / 12 * Math.PI * 2, ray = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.5, 0.06), discMat);
      ray.position.set(D.x + Math.cos(a) * 1.25, D.y + Math.sin(a) * 1.25, D.z + 0.15); ray.rotation.z = a - Math.PI / 2; this.root.add(ray);
    }
    // 光の線（反射した日の光）
    this.beamMat = new THREE.MeshBasicMaterial({ color: '#ffe6a0', transparent: true, opacity: 0.55, blending: THREE.AdditiveBlending, depthWrite: false });
    this.beams = [];
    this.traceBeam(false);
    if (solved) this.g.makeChest({ x: 0, z: -76.5, ankh: 600 }, 'mirror');
  }

  /** 日の光の道すじを計算して、光の線を引き直す */
  traceBeam(check) {
    for (const b of this.beams) { this.root.remove(b); b.geometry.dispose(); }
    this.beams = [];
    const [x0, x1, z0, z1] = MIRROR.bounds;
    let cur = this.mirrors[MIRROR.sun], p = new THREE.Vector2(cur.x, cur.z), inDir = null, hitDisc = false;
    const lit = new Set();
    for (let hop = 0; hop < 6 && cur; hop++) {
      lit.add(cur);
      const d = DIRS[cur.dir];
      cur.out = d; cur.inDir = inDir;
      // 光が進む：柱・壁・ほかの鏡にぶつかるまで
      let next = null, t = 0;
      for (t = 0.5; t < 60; t += 0.1) {
        const x = p.x + d[0] * t, z = p.y + d[1] * t;
        if (x < x0 || x > x1 || z < z0 || z > z1) { if (z < z0 + 0.3 && Math.abs(x - MIRROR.disc.x) < 1) hitDisc = true; break; }
        if (MIRROR.pillars.some(([px, pz]) => Math.hypot(x - px, z - pz) < 1.3)) break;
        next = this.mirrors.find(m => m !== cur && Math.hypot(x - m.x, z - m.z) < 0.35);
        if (next) break;
      }
      const len = next ? Math.hypot(next.x - p.x, next.z - p.y) : t;
      const beam = new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.07, len, 8, 1, true), this.beamMat);
      beam.rotation.z = Math.PI / 2; beam.rotation.y = -Math.atan2(d[1], d[0]);
      beam.position.set(p.x + d[0] * len / 2, 1.4, p.y + d[1] * len / 2);
      this.root.add(beam); this.beams.push(beam);
      if (!next) break;
      inDir = [-d[0], -d[1]];
      p = new THREE.Vector2(next.x, next.z); cur = next;
    }
    for (const m of this.mirrors) {
      m.lit = lit.has(m);
      // 鏡の面の向き：入ってくる光と出ていく光のまん中（日の光の鏡は上から）
      const out = DIRS[m.dir];
      const inV = m === this.mirrors[MIRROR.sun] ? new THREE.Vector3(0, 1, 0) : m.inDir ? new THREE.Vector3(m.inDir[0], 0, m.inDir[1]) : new THREE.Vector3(out[0], 0, out[1]);
      const n = inV.clone().add(new THREE.Vector3(out[0], 0, out[1])).normalize();
      m.want = n;
      m.face.material.emissiveIntensity = m.lit ? 1.6 : 0.1;
    }
    if (check && hitDisc && !this.g.save.flags.necMirror) this.solveMirror();
  }

  async solveMirror() {
    const g = this.g;
    g.save.flags.necMirror = true;
    audio.sfx('rumble'); g.shake = 0.5;
    this.disc.material.emissiveIntensity = 2.5;
    g.fx?.pillar(new THREE.Vector3(0, 0, -77), '#ffd36a');
    g.makeChest({ x: 0, z: -76.5, ankh: 600 }, 'mirror');
    await g.runSteps([{ who: 'narr', text: '日の光が太陽円盤に届いた！ 円盤が輝き、壁の奥で石が動いた……' },
      { run: a => a.giveItem('sun_disk') }, { who: 'narr', text: '円盤の裏から「太陽円盤」のお守りが現れた。宝箱も出てきた！' }]);
    g.persist();
  }

  // ---------- 押す石と祠 ----------
  makeBlock(solved) {
    const stone = B.M.pbr('large_sandstone_blocks_01'), dark = B.M.dark();
    const [sx, sz] = BLOCK.shrine, [px, pz] = BLOCK.plate;
    // 小さな祠（南に扉）
    const walls = [[sx, sz - 2.1, 4.6, 0.4], [sx - 2.1, sz, 0.4, 4.6], [sx + 2.1, sz, 0.4, 4.6], [sx - 1.5, sz + 2.1, 1.6, 0.4], [sx + 1.5, sz + 2.1, 1.6, 0.4]];
    for (const [x, z, w, d] of walls) {
      const m = new THREE.Mesh(new THREE.BoxGeometry(w, 3.2, d), stone); m.position.set(x, 1.6, z); this.root.add(m);
      this.addBox({ minX: x - w / 2, maxX: x + w / 2, minZ: z - d / 2, maxZ: z + d / 2 });
    }
    const roof = new THREE.Mesh(new THREE.BoxGeometry(5.2, 0.5, 5.2), stone); roof.position.set(sx, 3.45, sz); this.root.add(roof);
    const inside = new THREE.Mesh(new THREE.BoxGeometry(3.8, 0.05, 3.8), dark); inside.position.set(sx, 0.03, sz); this.root.add(inside);
    this.door = new THREE.Mesh(new THREE.BoxGeometry(1.4, 2.8, 0.3), B.M.hiero()); this.door.position.set(sx, 1.4, sz + 2.1); this.root.add(this.door);
    this.doorBox = { minX: sx - 0.7, maxX: sx + 0.7, minZ: sz + 1.9, maxZ: sz + 2.3 };
    // 床の板
    this.plate = new THREE.Mesh(new THREE.BoxGeometry(1.8, 0.12, 1.8), B.M.gold()); this.plate.position.set(px, 0.06, pz); this.root.add(this.plate);
    // 押す石
    const [bx, bz] = solved ? BLOCK.plate : BLOCK.start;
    this.block = new THREE.Mesh(new THREE.BoxGeometry(1.6, 1.6, 1.6), stone); this.block.position.set(bx, 0.8, bz); this.root.add(this.block);
    this.block.castShadow = true;
    this.blockBox = this.addBox({ minX: bx - 0.8, maxX: bx + 0.8, minZ: bz - 0.8, maxZ: bz + 0.8, top: 1.6 });
    if (solved) { this.door.visible = false; this.plate.position.y = 0.02; }
    else this.addBox(this.doorBox);
    this.g.makeChest({ x: sx, z: sz - 0.8, ankh: 400 }, 'shrine');   // 祠の中の宝箱
  }

  updateBlock(dt) {
    if (!this.block || this.g.save.flags.necBlock) return;
    const P = this.g.player, p = P.pos, b = this.block.position;
    const dx = p.x - b.x, dz = p.z - b.z;
    const pushing = P.state === 'move' && !P.air && P.speedNow > 1.2;
    let mx = 0, mz = 0;
    if (pushing) {
      const fx = Math.sin(P.face), fz = Math.cos(P.face);
      if (Math.abs(dx) > Math.abs(dz) && Math.abs(dz) < 0.9 && Math.abs(dx) < 1.35 && fx * -Math.sign(dx) > 0.75) mx = -Math.sign(dx);
      else if (Math.abs(dz) >= Math.abs(dx) && Math.abs(dx) < 0.9 && Math.abs(dz) < 1.35 && fz * -Math.sign(dz) > 0.75) mz = -Math.sign(dz);
    }
    if (mx || mz) {
      const [ax0, ax1, az0, az1] = BLOCK.area, v = 1.5 * dt;
      const nx = Math.max(ax0, Math.min(ax1, b.x + mx * v)), nz = Math.max(az0, Math.min(az1, b.z + mz * v));
      // ほかの壁・岩にぶつかるなら動かない
      const C = this.g.zone.colliders;
      const hit = C.boxes.some(q => q !== this.blockBox && nx + 0.8 > q.minX && nx - 0.8 < q.maxX && nz + 0.8 > q.minZ && nz - 0.8 < q.maxZ)
        || C.circles.some(c => Math.max(Math.abs(nx - c.x), Math.abs(nz - c.z)) < 0.8 + c.r);
      if (!hit) {
        b.x = nx; b.z = nz;
        Object.assign(this.blockBox, { minX: nx - 0.8, maxX: nx + 0.8, minZ: nz - 0.8, maxZ: nz + 0.8 });
        P.actor.play('Push_Loop', { fade: 0.2 });
        this.scrape = (this.scrape || 0) - dt;
        if (this.scrape <= 0) { this.scrape = 0.45; audio.sfx('stone'); this.g.fx?.puff(b.clone().setY(0), 1, 0.6, 0.4); }
      }
    }
    const [px, pz] = BLOCK.plate;
    if (Math.abs(b.x - px) < 0.75 && Math.abs(b.z - pz) < 0.75) {
      b.x = px; b.z = pz;
      Object.assign(this.blockBox, { minX: px - 0.8, maxX: px + 0.8, minZ: pz - 0.8, maxZ: pz + 0.8 });
      this.solveBlock();
    }
  }

  async solveBlock() {
    const g = this.g;
    g.save.flags.necBlock = true;
    this.plate.position.y = 0.02;
    audio.sfx('rumble'); g.shake = 0.4;
    const a = g.zone.colliders.boxes, i = a.indexOf(this.doorBox); if (i >= 0) a.splice(i, 1);
    this.doorSink = 0;
    g.toast('カチッ……祠の扉が沈んでいく！');
    g.gainExp?.(60);
    g.persist();
  }

  // ---------- トゲの罠（墓の中の通路） ----------
  makeSpikes() {
    const metal = new THREE.MeshStandardMaterial({ color: '#8a7a64', metalness: 0.7, roughness: 0.45 });
    const cone = new THREE.ConeGeometry(0.09, 0.8, 6);
    this.spikes = [-32.5, -35.5].map((z, k) => {
      const grp = new THREE.Group(); grp.position.set(0, -0.8, z);
      for (let x = -1.35; x <= 1.36; x += 0.45) for (let dz = -0.9; dz <= 0.91; dz += 0.45) {
        const s = new THREE.Mesh(cone, metal); s.position.set(x, 0.4, dz); grp.add(s);
      }
      this.root.add(grp);
      const slots = new THREE.Mesh(new THREE.PlaneGeometry(3.1, 2.1), new THREE.MeshStandardMaterial({ color: '#1c140e', roughness: 1 }));
      slots.rotation.x = -Math.PI / 2; slots.position.set(0, 0.012, z); this.root.add(slots);
      return { grp, z, phase: k * 1.3, up: 0 };
    });
  }

  updateSpikes(dt) {
    if (!this.spikes) return;
    const P = this.g.player, T = 2.6;
    for (const s of this.spikes) {
      const ph = ((this.t + s.phase) % T) / T;
      const want = ph < 0.3 ? 1 : ph > 0.85 ? 0.12 : 0;   // 出る直前に少しだけ顔を出す（予告）
      if (want === 1 && s.up < 0.5) { if (Math.abs(P.pos.z - s.z) < 8) audio.sfx('stone'); }
      s.up += (want - s.up) * Math.min(1, dt * (want > s.up ? 22 : 6));
      s.grp.position.y = -0.8 + s.up * 0.8;
      if (s.up > 0.6 && !P.air && Math.abs(P.pos.z - s.z) < 1.05 && Math.abs(P.pos.x) < 1.6) this.g.hazards?.hit(P, this.g, 12, 'トゲの罠！', null);
    }
  }

  update(dt) {
    this.t += dt;
    for (const it of this.items) {
      if (it.kind === 'scarab') { it.mesh.rotation.y += dt * 1.6; it.mesh.position.y = 0.45 + Math.sin(this.t * 2.4 + it.x) * 0.08; it.mesh.children[2].material.opacity = 0.1 + Math.sin(this.t * 3) * 0.05; }
      if (it.kind === 'mirror' && it.want) {
        const yaw = Math.atan2(it.want.x, it.want.z), pitch = Math.asin(Math.max(-1, Math.min(1, it.want.y)));
        let d = yaw - it.yaw; d = Math.atan2(Math.sin(d), Math.cos(d)); it.yaw += d * Math.min(1, dt * 8);
        it.head.rotation.set(0, 0, 0); it.head.rotateY(it.yaw); it.head.rotateX(-pitch);
      }
    }
    for (const b of this.beams || []) b.material.opacity = 0.45 + Math.sin(this.t * 6) * 0.1;
    this.updateBlock(dt);
    if (this.doorSink != null && this.door.visible) { this.doorSink += dt; this.door.position.y = 1.4 - this.doorSink * 1.2; if (this.doorSink > 2.4) this.door.visible = false; }
    this.updateSpikes(dt);
  }

  /** いちばん近い「調べられる物」 */
  nearest(p) {
    let best = null, bd = Infinity;
    for (const it of this.items) { const d = Math.hypot(p.x - it.x, p.z - it.z); if (d < it.r && d < bd) { bd = d; best = it; } }
    return best && { kind: 'puzzle', item: best, label: best.label, d: bd };
  }
}

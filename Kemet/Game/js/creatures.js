// 泳ぐ敵・飛ぶ敵（上下にも動く）。水の中の「ナイルの大魚」、空の「ハヤブサの精霊」
import * as THREE from 'three';
import { audio } from './audio.js';

export const CREATURE_TYPES = {
  fish: { name: 'ナイルの大魚', hp: 55, atk: 11, speed: 3.2, lunge: 13, reach: 1.6, keep: 7, windup: 0.7, cooldown: 2.2, exp: 22, ankh: 28 },
  bird: { name: 'ハヤブサの精霊', hp: 45, atk: 10, speed: 5.5, lunge: 16, reach: 1.5, keep: 8, windup: 0.55, cooldown: 2.0, exp: 24, ankh: 32 },
};

// 最初に入ったときに出てくる場所（光の計算とは別に、ここで決める）
export const CREATURE_SPAWNS = {
  sunken: [['fish', -10, 5, -20], ['fish', 12, 7, -30], ['fish', -24, 4, 6], ['fish', 20, 9, 14], ['fish', 0, 11, -44], ['fish', -30, 6, 30]],
  sky: [['bird', 0, 6, 10], ['bird', -40, 5, -4], ['bird', 44, 7, -4], ['bird', 0, 8, -42], ['bird', 18, 10, 34], ['bird', -18, 9, -60]],
};

function fishMesh() {
  const g = new THREE.Group();
  const skin = new THREE.MeshStandardMaterial({ color: '#4d5a52', roughness: 0.45, metalness: 0.3 });
  const belly = new THREE.MeshStandardMaterial({ color: '#b9b08a', roughness: 0.6 });
  const body = new THREE.Mesh(new THREE.SphereGeometry(0.5, 20, 12), skin); body.scale.set(0.7, 0.8, 2.2); g.add(body);
  const b2 = new THREE.Mesh(new THREE.SphereGeometry(0.46, 16, 10), belly); b2.scale.set(0.62, 0.55, 2.0); b2.position.y = -0.12; g.add(b2);
  const tail = new THREE.Group(); tail.position.z = -1.05; g.add(tail);
  const fin = new THREE.Mesh(new THREE.ConeGeometry(0.5, 0.8, 4), skin); fin.rotation.x = -Math.PI / 2; fin.scale.set(0.15, 1, 1.1); fin.position.z = -0.35; tail.add(fin);
  const dorsal = new THREE.Mesh(new THREE.ConeGeometry(0.25, 0.6, 4), skin); dorsal.position.set(0, 0.45, 0.1); dorsal.scale.set(0.2, 1, 1.4); g.add(dorsal);
  const eyeM = new THREE.MeshBasicMaterial({ color: '#ffcf40' });
  for (const s of [-1, 1]) { const e = new THREE.Mesh(new THREE.SphereGeometry(0.06, 8, 6), eyeM); e.position.set(s * 0.3, 0.1, 0.85); g.add(e); }
  // 牙
  const teeth = new THREE.MeshStandardMaterial({ color: '#eee8d8' });
  for (let i = 0; i < 6; i++) { const t = new THREE.Mesh(new THREE.ConeGeometry(0.03, 0.12, 4), teeth); t.position.set(-0.15 + i * 0.06, -0.12, 1.02); t.rotation.x = Math.PI; g.add(t); }
  g.userData.anim = (t) => { tail.rotation.y = Math.sin(t * 8) * 0.5; body.rotation.y = Math.sin(t * 8 + 1) * 0.06; };
  return g;
}

function birdMesh() {
  const g = new THREE.Group();
  const gold = new THREE.MeshStandardMaterial({ color: '#e0b458', roughness: 0.35, metalness: 0.6, emissive: '#3a2a08' });
  const feather = new THREE.MeshStandardMaterial({ color: '#f4ead2', roughness: 0.6, side: THREE.DoubleSide, emissive: '#2a2210' });
  const body = new THREE.Mesh(new THREE.SphereGeometry(0.35, 16, 10), gold); body.scale.set(0.8, 0.8, 1.8); g.add(body);
  const head = new THREE.Mesh(new THREE.SphereGeometry(0.22, 12, 8), gold); head.position.set(0, 0.2, 0.62); g.add(head);
  const beak = new THREE.Mesh(new THREE.ConeGeometry(0.07, 0.22, 6), new THREE.MeshStandardMaterial({ color: '#3a2a10' })); beak.rotation.x = Math.PI / 2; beak.position.set(0, 0.16, 0.86); g.add(beak);
  const eyeM = new THREE.MeshBasicMaterial({ color: '#7fd4ff' });
  for (const s of [-1, 1]) { const e = new THREE.Mesh(new THREE.SphereGeometry(0.04, 8, 6), eyeM); e.position.set(s * 0.12, 0.26, 0.76); g.add(e); }
  const wings = [];
  for (const s of [-1, 1]) {
    const w = new THREE.Group(); w.position.set(s * 0.22, 0.1, 0.05); g.add(w);
    const shape = new THREE.Shape(); shape.moveTo(0, 0); shape.lineTo(s * 1.5, 0.15); shape.lineTo(s * 1.7, -0.1); shape.lineTo(s * 1.1, -0.35); shape.lineTo(s * 0.4, -0.45); shape.lineTo(0, -0.3);
    const m = new THREE.Mesh(new THREE.ShapeGeometry(shape), feather); m.rotation.x = -Math.PI / 2; w.add(m);
    wings.push({ w, s });
  }
  const tail = new THREE.Mesh(new THREE.ConeGeometry(0.25, 0.6, 4), feather); tail.rotation.x = -Math.PI / 2; tail.position.z = -0.75; tail.scale.set(1, 1, 0.2); g.add(tail);
  g.userData.anim = (t, fast) => { for (const { w, s } of wings) w.rotation.z = s * Math.sin(t * (fast ? 16 : 8)) * 0.7; };
  return g;
}

export class Creature {
  constructor(type, x, y, z) {
    this.type = type; this.def = CREATURE_TYPES[type];
    this.root = type === 'fish' ? fishMesh() : birdMesh();
    this.root.scale.setScalar(type === 'fish' ? 1.3 : 1.2);
    this.pos = this.root.position; this.pos.set(x, y, z);
    this.home = this.pos.clone();
    this.hp = this.def.hp; this.maxHP = this.def.hp;
    this.state = 'roam'; this.timer = Math.random() * 2; this.t = Math.random() * 10;
    this.radius = 0.9; this.vel = new THREE.Vector3();
    this.mats = []; this.root.traverse(o => { if (o.isMesh && o.material.emissive) this.mats.push(o.material); });
    this.flashT = 0;
  }

  get alive() { return this.state !== 'dead'; }

  update(dt, player, world) {
    this.t += dt;
    const P = player.pos.clone().add(new THREE.Vector3(0, 1.0, 0));
    const to = P.clone().sub(this.pos), d = to.length();
    const def = this.def;
    this.flashT = Math.max(0, this.flashT - dt);
    for (const m of this.mats) m.emissiveIntensity = this.flashT > 0 ? 3 : this.state === 'windup' ? 1.5 + Math.sin(this.t * 30) : 1;
    if (this.state === 'dead') {
      this.vel.y -= (this.type === 'fish' ? 1 : 12) * dt;
      this.pos.addScaledVector(this.vel, dt); this.root.rotation.z += dt * 2;
      this.timer -= dt; this.root.scale.multiplyScalar(1 - dt * 0.6);
      return this.timer > 0;
    }
    const look = (v, k) => { const want = Math.atan2(v.x, v.z); let a = want - this.root.rotation.y; a = Math.atan2(Math.sin(a), Math.cos(a)); this.root.rotation.y += a * Math.min(1, dt * k); };
    switch (this.state) {
      case 'roam': {   // まわりをゆっくり回る
        const c = this.home.clone().add(new THREE.Vector3(Math.sin(this.t * 0.4) * 5, Math.sin(this.t * 0.7) * 1.5, Math.cos(this.t * 0.4) * 5));
        this.vel.lerp(c.sub(this.pos).clampLength(0, def.speed * 0.5), dt * 2);
        if (d < 14 && player.alive) this.state = 'circle';
        break;
      }
      case 'circle': { // 相手のまわりを回りながら、間合いをはかる
        const side = new THREE.Vector3(-to.z, 0, to.x).normalize();
        const want = to.clone().normalize().multiplyScalar(d - def.keep).add(side.multiplyScalar(def.speed * 0.6));
        want.y = (P.y - this.pos.y) * 0.8;
        this.vel.lerp(want.clampLength(0, def.speed), dt * 3);
        this.timer -= dt;
        if (this.timer <= 0 && d < def.keep + 4) { this.state = 'windup'; this.timer = def.windup; audio.sfx(this.type === 'fish' ? 'bubble' : 'screech'); }
        if (d > 24) this.state = 'roam';
        break;
      }
      case 'windup':   // 攻撃の前ぶれ（体が光る）。ここで砂走りすれば「時の砂」
        this.vel.multiplyScalar(1 - dt * 4);
        this.timer -= dt;
        if (this.timer <= 0) { this.state = 'lunge'; this.timer = 0.55; this.hitDone = false; this.vel.copy(to.normalize().multiplyScalar(def.lunge)); }
        break;
      case 'lunge':
        this.timer -= dt;
        if (!this.hitDone && this.pos.distanceTo(P) < def.reach + 0.4) { this.hitDone = true; world.creatureHit(this, player); }
        if (this.timer <= 0) { this.state = 'circle'; this.timer = def.cooldown * (0.8 + Math.random() * 0.5); }
        break;
      case 'hurt':
        this.vel.multiplyScalar(1 - dt * 3); this.timer -= dt;
        if (this.timer <= 0) { this.state = 'circle'; this.timer = def.cooldown * 0.6; }
        break;
    }
    this.pos.addScaledVector(this.vel, dt);
    const g = world.colliders.groundAt(this.pos.x, this.pos.z, this.pos.y);
    this.pos.y = Math.max(Number.isFinite(g) ? g + 0.8 : -30, this.pos.y);
    if (world.zone?.swim) this.pos.y = Math.min(world.zone.swim.surface - 1, this.pos.y);
    if (this.vel.lengthSq() > 0.1) look(this.state === 'lunge' ? this.vel : this.vel.clone().setY(0).lengthSq() > 0.05 ? this.vel : to, this.state === 'lunge' ? 12 : 5);
    this.root.rotation.x = -Math.atan2(this.vel.y, Math.hypot(this.vel.x, this.vel.z) + 0.001) * 0.6;
    this.root.userData.anim?.(this.t, this.state === 'lunge' || this.state === 'windup');
    return true;
  }

  hurt(dmg, from) {
    if (!this.alive) return;
    this.hp -= dmg; this.flashT = 0.12;
    const k = this.pos.clone().sub(from).setY(0.3).normalize().multiplyScalar(6);
    this.vel.copy(k);
    if (this.hp <= 0) { this.state = 'dead'; this.timer = 1.6; this.vel.set(0, 1, 0); }
    else { this.state = 'hurt'; this.timer = 0.35; }
  }
}

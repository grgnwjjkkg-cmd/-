// 仲間：神殿の衛兵カシュ（盾役）。ついて歩き、近くの敵と戦う。能力「剛力」＝重い石の扉を持ち上げる
// 第1章：洞窟の牢に捕まっている → 助けると仲間になる → 盗賊団の間の前の落とし扉を持ち上げる
import * as THREE from 'three';
import { Actor, turnTowards } from './actor.js';
import { audio } from './audio.js';

export const ALLIES = {
  kash: { name: 'カシュ', role: '盾役・剛力', model: 'vrm:guard', weapon: 'Spear', tint: '#e8dcc0', atk: 9, speed: 5.0, reach: 2.4 },
};

const CELL = { x: 33.5, z: -73, bx: 32.4, z0: -76, z1: -70 };      // 洞窟の北の通路の東のくぼみ（格子は通路にそって立つ）
const GATE = { x0: 36.5, x1: 38.0, z0: -97.5, z1: -92.5 };      // 盗賊団の間へ続く通路をふさぐ落とし扉

export class Ally {
  constructor(g, id, actor) {
    this.g = g; this.id = id; this.def = ALLIES[id]; this.actor = actor;
    this.root = actor.root; this.pos = this.root.position; this.face = 0;
    this.state = 'follow'; this.cool = 0; this.target = null;
  }

  update(dt) {
    const g = this.g, P = g.player, def = this.def;
    this.actor.update(dt);
    this.cool -= dt;
    if (this.busy) return;
    // 敵をさがす：ネフィの近く8m以内で、いちばん近い敵
    if (!this.target || !this.target.alive || this.target.pos.distanceTo(P.pos) > 12) {
      this.target = null; let bd = 8;
      for (const e of g.enemies) { if (!e.alive || e.dormant) continue; const d = e.pos.distanceTo(P.pos); if (d < bd) { bd = d; this.target = e; } }
    }
    let goal, stop;
    if (this.target) { goal = this.target.pos; stop = def.reach * 0.8; }
    else {   // ネフィの斜め後ろについていく
      const back = P.face + Math.PI + 0.6;
      goal = new THREE.Vector3(P.pos.x + Math.sin(back) * 2.2, 0, P.pos.z + Math.cos(back) * 2.2); stop = 0.5;
    }
    const d = goal.clone().sub(this.pos).setY(0), L = d.length();
    if (L > 25) { this.pos.copy(P.pos).add(new THREE.Vector3(1, 0, 1)); return; }   // はぐれたら追いつく
    if (this.hitAt > 0) { this.hitAt -= dt; if (this.hitAt <= 0) this.hit(); }
    if (this.attackT > 0) { this.attackT -= dt; }
    else if (L > stop) {
      this.face = turnTowards(this.face, Math.atan2(d.x, d.z), dt * 8);
      const sp = Math.min(def.speed * (L > 5 ? 1.2 : 0.8), L * 3);
      this.pos.x += Math.sin(this.face) * sp * dt; this.pos.z += Math.cos(this.face) * sp * dt;
      this.actor.play(sp > 2.6 ? 'Jog_Fwd_Loop' : 'Walk_Loop', { fade: 0.2 }); this.actor.setSpeed(sp > 2.6 ? sp / 4.6 : Math.max(0.5, sp / 1.7));
    } else if (this.target && this.cool <= 0) {
      this.face = Math.atan2(d.x, d.z);
      this.actor.play('Sword_Attack', { fade: 0.08, loop: false, speed: 1.2, restart: true });
      this.attackT = 0.45; this.cool = 1.3;
      this.hitAt = 0.26;
    } else this.actor.play('Sword_Idle', { fade: 0.25 });
    g.colliders.resolve(this.pos, 0.45);
    const gy = g.colliders.groundAt(this.pos.x, this.pos.z, this.pos.y + 0.3); this.pos.y = Number.isFinite(gy) ? gy : 0;
    this.root.rotation.y = turnTowards(this.root.rotation.y, this.face, dt * 14);
  }

  hit() {
    const g = this.g, e = this.target;
    if (!e || !e.alive || e.pos.distanceTo(this.pos) > this.def.reach + 0.6) return;
    const dmg = Math.round(this.def.atk * (1 + g.save.level * 0.08) * (0.9 + Math.random() * 0.2));
    e.hurt(dmg, this.pos, {}); audio.sfx('hit');
    g.popNumber(e.pos, dmg, 'ally');
    // 盾役：たたいた敵の気を引く（ネフィへの攻撃を少し遅らせる）
    if (e.timer != null) e.timer = Math.max(e.timer, 0.6);
    if (!e.alive) g.onEnemyDown(e);
  }
}

/** 第1章の仲間イベント（牢・落とし扉） */
export class AllyEvents {
  constructor(g) {
    this.g = g; this.root = new THREE.Group(); g.scene.add(this.root);
    const f = g.save.flags, B = g.zone.colliders.boxes;
    const bronze = new THREE.MeshStandardMaterial({ color: '#7a5a34', metalness: 0.7, roughness: 0.45 });
    // 牢の格子
    if (!f.kashJoined) {
      this.bars = new THREE.Group();
      for (let z = CELL.z0; z <= CELL.z1 + 0.01; z += 0.42) { const b = new THREE.Mesh(new THREE.CylinderGeometry(0.045, 0.045, 3, 8), bronze); b.position.set(CELL.bx, 1.5, z); this.bars.add(b); }
      const top = new THREE.Mesh(new THREE.BoxGeometry(0.15, 0.15, CELL.z1 - CELL.z0 + 0.3), bronze); top.position.set(CELL.bx, 3, (CELL.z0 + CELL.z1) / 2); this.bars.add(top);
      this.root.add(this.bars);
      this.barBox = { minX: CELL.bx - 0.12, maxX: 34.6, minZ: CELL.z0 - 0.1, maxZ: CELL.z1 + 0.1 };
      B.push(this.barBox);
      g.puzzles.items.push({ kind: 'cell', label: '話す', x: 31.3, z: -73, r: 2.2, act: () => this.talkCell() });
    }
    // 落とし扉（重い石の格子戸）
    if (!f.gateLifted) {
      this.gate = new THREE.Mesh(new THREE.BoxGeometry(GATE.x1 - GATE.x0, 4.4, GATE.z1 - GATE.z0), new THREE.MeshStandardMaterial({ color: '#8d7658', roughness: 0.9 }));
      this.gate.position.set((GATE.x0 + GATE.x1) / 2, 2.2, (GATE.z0 + GATE.z1) / 2); this.root.add(this.gate);
      for (let z = GATE.z0 + 0.5; z < GATE.z1; z += 0.9) { const s = new THREE.Mesh(new THREE.BoxGeometry(0.08, 4.3, 0.12), bronze); s.position.set(GATE.x0 - 0.02, 2.2, z); this.root.add(s); }
      this.gateBox = { minX: GATE.x0, maxX: GATE.x1, minZ: GATE.z0, maxZ: GATE.z1 };
      B.push(this.gateBox);
      g.puzzles.items.push({ kind: 'gate', label: '調べる', x: GATE.x0 - 1.2, z: (GATE.z0 + GATE.z1) / 2, r: 2.2, act: () => this.lift() });
    }
  }

  async spawnCaptive() {
    const g = this.g;
    if (g.save.flags.kashJoined) return;
    const a = new Actor(await g.assets.makeChar('vrm:guard'), g.assets);
    a.root.position.set(CELL.x, 0, CELL.z); a.root.rotation.y = -Math.PI / 2;
    a.play('Sitting_Idle_Loop', { fade: 0 });
    this.captive = a; g.scene.add(a.root);
  }

  async talkCell() {
    const g = this.g, f = g.save.flags;
    if (f.kashJoined) return;
    const near = g.enemies.some(e => e.alive && e.pos.distanceTo(g.player.pos) < 10);
    if (near) { g.toast('まわりの敵をたおしてから！'); return; }
    await g.runSteps([
      { who: 'kash', text: 'おい、そこの……巫女さん？ こんな所で何を？' },
      { who: 'player', text: '謎解き屋。ついでに、迷子。……あなたは？' },
      { who: 'kash', text: '神殿の衛兵、カシュだ。盗賊を追って墓に入ったら、このざまさ。' },
      { who: 'narr', text: '格子の留め金は錆びついている。短剣の柄でたたくと、はずれた。' },
      { who: 'kash', text: '助かった！ 恩は返す。力仕事なら任せてくれ。重い扉だって持ち上げてみせる。' },
      { who: 'player', text: 'ありがと。いっしょに来て。' },
      { run: () => this.join() },
      { who: 'narr', text: '衛兵カシュが仲間になった！ いっしょに戦い、重い扉を持ち上げてくれる。' },
    ]);
  }

  async join() {
    const g = this.g;
    g.save.flags.kashJoined = true; (g.save.party ||= []).includes('kash') || g.save.party.push('kash');
    audio.voice('ally', { gap: 0 }); audio.sfx('rare');
    const i = g.zone.colliders.boxes.indexOf(this.barBox); if (i >= 0) g.zone.colliders.boxes.splice(i, 1);
    this.root.remove(this.bars);
    if (this.captive) { g.scene.remove(this.captive.root); this.captive = null; }
    await g.spawnAllies();
    const al = g.allies.find(a => a.id === 'kash'); if (al) al.pos.set(30.5, 0, CELL.z + 1.5);
    g.persist();
  }

  async lift() {
    const g = this.g, al = g.allies?.find(a => a.id === 'kash');
    if (g.save.flags.gateLifted) return;
    if (!al) { await g.runSteps([{ who: 'player', text: '……重い石の落とし扉。ひとりじゃ、びくともしない。' }, { who: 'player', text: '力持ちの誰かがいれば……。' }]); return; }
    al.busy = true; g.paused = true;
    al.pos.set(GATE.x0 - 0.7, 0, (GATE.z0 + GATE.z1) / 2); al.face = Math.PI / 2; al.root.rotation.y = al.face;
    al.actor.play('Push_Loop', { fade: 0.2 });
    await g.runSteps([{ who: 'kash', text: 'まかせろ。……ふんっ！' }]);
    audio.sfx('rumble'); g.shake = 0.6;
    const t0 = performance.now();
    await new Promise(res => { const step = () => { const k = Math.min(1, (performance.now() - t0) / 1600); this.gate.position.y = 2.2 + k * 3.6; if (k < 1) requestAnimationFrame(step); else res(); }; step(); });
    const i = g.zone.colliders.boxes.indexOf(this.gateBox); if (i >= 0) g.zone.colliders.boxes.splice(i, 1);
    g.save.flags.gateLifted = true; g.persist();
    al.busy = false; g.paused = false;
    await g.runSteps([{ who: 'kash', text: 'よし、通れるぞ。この先が盗賊団のアジトだ。' }]);
  }

  update(dt) { this.captive?.update(dt); }
}

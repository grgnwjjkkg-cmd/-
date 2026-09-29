// 主人公・町の人・敵
import * as THREE from 'three';
import { Actor, turnTowards } from './actor.js';
import { audio } from './audio.js';

const tmp = new THREE.Vector3();

// ------------------------------------------------------------
// 主人公
// ------------------------------------------------------------
export class Player {
  constructor(actor) {
    this.actor = actor;
    this.root = actor.root;
    this.pos = this.root.position;
    this.face = 0;
    this.state = 'move';
    this.radius = 0.4;
    this.hp = 100;
    this.invuln = 0;
    this.comboQueued = false;
    this.combo = 0;
    this.stepTimer = 0;
    this.speedNow = 0;
    this.vy = 0; this.air = false; this.plunging = false;
    this.actor.play('Idle_Loop', { fade: 0 });
  }

  get alive() { return this.state !== 'dead'; }

  /** input: { x, y }（スティック。上が y=+1）、camYaw：カメラの向き */
  update(dt, input, camYaw, stats, world) {
    this.actor.update(dt);
    this.invuln = Math.max(0, this.invuln - dt);
    if (stats.regen && this.hp > 0) this.hp = Math.min(stats.maxHP, this.hp + stats.regen * dt);

    const mag = Math.min(1, Math.hypot(input.x, input.y));
    const armed = !!stats.weaponName;
    // 高さ：地面・足場・空・水の中
    const C = world.colliders, P = this.pos;
    const ground = C.groundAt(P.x, P.z, P.y);
    this.swimming = !!world.zone?.swim; this.flight = !!world.zone?.flight;
    if (this.swimming) {
      // 水の中：ゆっくり沈み、はじくと上下に泳ぐ
      const surf = world.zone.swim.surface - 1.3;
      this.vy += (-0.5 - this.vy) * Math.min(1, dt * 1.6);
      P.y = Math.min(surf, P.y + this.vy * dt);
      if (P.y <= Math.max(0, ground)) { P.y = Math.max(0, ground); if (this.vy < 0) this.vy = 0; }
      this.air = P.y > Math.max(0, ground) + 0.3;
    } else {
      if (!this.air && P.y > ground + 0.05) { this.air = true; this.vy = 0; }   // 段や島のふちから落ちた
      if (!this.air && P.y < ground) P.y = ground;                               // 低い段は上る
      if (this.air) {
        const gs = world.zone?.gravity || 1;
        this.vy -= (this.plunging ? 40 : 19) * gs * dt;
        // ホルスの翼：空の都ではゆっくり滑空する
        this.gliding = world.zone?.flight && !this.plunging && this.vy < -2.2;
        if (this.gliding) this.vy = Math.max(this.vy, -2.4);
        P.y += this.vy * dt;
        if (P.y <= ground) {
          P.y = ground; this.air = false; this.vy = 0; this.gliding = false;
          if (this.plunging) { this.plunging = false; world.plungeHit(this); this.state = 'move'; this.actor.play('Jump_Land', { fade: 0.05, loop: false, speed: 1.6, restart: true }); }
          else if (this.state === 'move') this.actor.play('Jump_Land', { fade: 0.05, loop: false, speed: 1.8, restart: true });
          this.landTime = 0.18;
          this.safe = P.clone();
        } else if (this.state === 'move' && this.vy < 2) this.actor.play(this.gliding ? 'Swim_Fwd_Loop' : 'Jump_Loop', { fade: 0.2 });
        if (P.y < -45) world.fellOff?.(this);
      } else if (!this.safe || Math.random() < 0.05) this.safe = P.clone();
    }
    this.landTime = Math.max(0, (this.landTime || 0) - dt);

    if (this.state === 'move') {
      let target = 0;
      if (mag > 0.12) {
        // カメラから見た方向に歩く
        const ang = camYaw - Math.atan2(input.x, input.y);
        this.face = turnTowards(this.face, ang, dt * 12);
        target = (mag < 0.65 ? 2.0 * (mag / 0.65) : 5.4) * stats.speedMul;
      }
      // 急に止まらず、なめらかに加減速
      this.speedNow += (target - this.speedNow) * Math.min(1, dt * 10);
      const s = this.speedNow;
      // 凍った湖の上はすべる（向きを変えてもすぐには曲がれない）
      const ice = !this.air && (world.zone?.slippery || []).some(b => P.x > b[0] && P.x < b[1] && P.z > b[2] && P.z < b[3]);
      const sl = this.slide || (this.slide = { x: 0, z: 0 }), wx = Math.sin(this.face) * s, wz = Math.cos(this.face) * s;
      const k = ice ? Math.min(1, dt * 1.2) : 1;
      sl.x += (wx - sl.x) * k; sl.z += (wz - sl.z) * k;
      this.pos.x += sl.x * dt; this.pos.z += sl.z * dt;
      // 速さに合わせて足の動きを選ぶ（すべって見えないように再生速度も合わせる）
      if (this.swimming) { this.actor.play(s > 0.4 ? 'Swim_Fwd_Loop' : 'Swim_Idle_Loop', { fade: 0.3 }); this.actor.setSpeed(0.6 + s * 0.2); }
      else if (this.air || this.landTime > 0) { /* 空中・着地の動きのまま */ }
      else if (s < 0.25) this.actor.play(armed ? 'Sword_Idle' : 'Idle_Loop', { fade: 0.25 });
      else if (s < 2.6) { this.actor.play('Walk_Loop', { fade: 0.2 }); this.actor.setSpeed(Math.max(0.5, s / 1.7)); }
      else { this.actor.play('Jog_Fwd_Loop', { fade: 0.2 }); this.actor.setSpeed(s / 4.6); }
      if (s > 0.5) {
        this.stepTimer -= dt * s;
        if (this.stepTimer <= 0) { audio.sfx('step'); this.stepTimer = 1.4; }
      }
    } else if (this.state === 'attack') {
      const p = this.actor.progress();
      if (!this.hitDone && p > 0.32) { this.hitDone = true; if (this.charged != null) world.chargedHit(this, this.charged); else world.playerHit(this); }
      // 攻撃中は少し前に踏み込む
      if (p < 0.35) { this.pos.x += Math.sin(this.face) * 1.2 * dt; this.pos.z += Math.cos(this.face) * 1.2 * dt; }
      if (p > 0.55 && this.comboQueued) this.startAttack(stats);
      else if (p > 0.8) { this.state = 'move'; this.charged = null; }
    } else if (this.state === 'roll') {
      this.rollTime -= dt;
      const k = Math.max(0, this.rollTime / 0.55);
      this.pos.x += Math.sin(this.face) * 10.5 * k * dt;
      this.pos.z += Math.cos(this.face) * 10.5 * k * dt;
      world.sandPuff?.(this.pos, k);
      if (this.rollTime <= 0) this.state = 'move';
    } else if (this.state === 'charge') {
      // 溜め：その場で力をためる（ゆっくりなら向きを変えられる）
      this.chargeTime += dt;
      if (mag > 0.12) this.face = turnTowards(this.face, camYaw - Math.atan2(input.x, input.y), dt * 6);
      world.chargeGlow?.(this, Math.min(1, this.chargeTime / 1.2));
    } else if (this.state === 'cast') {
      const p = this.actor.progress();
      if (!this.castDone && p > 0.32) { this.castDone = true; world.castGlyph(this, this.castName); }
      if (p > 0.85) this.state = 'move';
    } else if (this.state === 'hurt') {
      this.hurtTime -= dt;
      this.pos.x += this.knock.x * dt; this.pos.z += this.knock.z * dt;
      this.knock.multiplyScalar(Math.max(0, 1 - dt * 6));
      if (this.hurtTime <= 0) this.state = 'move';
    }

    world.colliders.resolve(this.pos, this.radius);
    this.root.rotation.y = turnTowards(this.root.rotation.y, this.face, dt * 18);
  }

  attack(stats) {
    if (this.air && !this.plunging && !this.swimming && !(this.flight && this.pos.y > 2)) return this.plunge();
    if (this.state === 'attack') { this.comboQueued = true; return; }
    if (this.state !== 'move') return;
    this.combo = 0;
    this.startAttack(stats);
  }

  /** ジャンプ（地上で動ける時だけ） */
  jump() {
    if (!['move', 'attack'].includes(this.state)) return false;
    if (this.swimming) { this.vy = 5.5; audio.sfx('swim'); return true; }
    if (this.air) {
      if (!this.flight || (this.flapT || 0) > performance.now()) return false;
      this.flapT = performance.now() + 330; this.vy = 7; this.plunging = false;   // 翼で羽ばたく
      audio.sfx('flap'); return true;
    }
    this.state = 'move'; this.air = true; this.vy = 7.2;
    this.actor.play('Jump_Start', { fade: 0.05, loop: false, speed: 1.8, restart: true });
    audio.sfx('jump');
    return true;
  }

  /** 水の中で下へもぐる */
  dive() { if (this.swimming) { this.vy = -5.5; audio.sfx('swim'); } }

  /** 空中から真下へ斬りおろす */
  plunge() {
    if (!this.air || this.plunging || this.swimming) return;
    this.plunging = true; this.vy = Math.min(this.vy, -4);
    this.actor.play('Sword_Attack', { fade: 0.05, loop: false, speed: 1.4, restart: true });
    audio.sfx('swing');
  }

  /** 溜め：長押しで始まり、離すと溜め斬り */
  chargeStart() {
    if (this.state !== 'move' || this.air) return false;
    this.state = 'charge'; this.chargeTime = 0;
    this.actor.play('Sword_Idle', { fade: 0.1 });
    audio.sfx('charge');
    return true;
  }

  chargeRelease(stats, cancel) {
    if (this.state !== 'charge') return;
    if (cancel || this.chargeTime < 0.25) { this.state = 'move'; return; }
    this.charged = Math.min(1, this.chargeTime / 1.2);
    this.state = 'attack'; this.hitDone = false; this.comboQueued = false; this.combo = 0;
    this.actor.play('Sword_Attack', { fade: 0.05, loop: false, speed: 1.1 * stats.attackSpeed, restart: true });
    audio.sfx('swing');
  }

  /** 神聖文字の術（描いた形の名前） */
  cast(name) {
    if (!['move', 'attack', 'charge'].includes(this.state)) return false;
    this.state = 'cast'; this.castName = name; this.castDone = false;
    this.actor.play('Spell_Simple_Shoot', { fade: 0.06, loop: false, speed: 1.5, restart: true });
    return true;
  }

  /** 砂走り：向きを決めて素早く走り抜ける（その間は攻撃を受けない） */
  dash(angle) {
    if (!['move', 'attack', 'charge'].includes(this.state)) return false;
    if (angle != null) { this.face = angle; this.root.rotation.y = angle; }
    this.state = 'roll';
    this.rollTime = 0.55;
    this.invuln = 0.5;
    this.charged = null;
    this.actor.play('Roll', { fade: 0.05, loop: false, speed: 1.55, restart: true });
    audio.sfx('roll');
    return true;
  }

  startAttack(stats) {
    this.state = 'attack';
    this.hitDone = false;
    this.comboQueued = false;
    this.combo = (this.combo + 1) % 3;
    const armed = !!stats.weaponName;
    const name = armed ? 'Sword_Attack' : this.combo % 2 ? 'Punch_Jab' : 'Punch_Cross';
    // 3段目は少し重く
    const speed = (armed ? 1.35 : 1.5) * stats.attackSpeed * (this.combo === 0 ? 0.9 : 1.05);
    this.actor.play(name, { fade: 0.08, loop: false, speed, restart: true });
    audio.sfx('swing');
  }

  roll() {
    return this.dash(null);
  }

  rollOld() {
    if (this.state !== 'move' && this.state !== 'attack') return;
    this.state = 'roll';
    this.rollTime = 0.65;
    this.invuln = 0.55;
    this.actor.play('Roll', { fade: 0.06, loop: false, speed: 1.35, restart: true });
    audio.sfx('roll');
  }

  hurt(amount, from, stats) {
    if (this.invuln > 0 || this.state === 'dead') return false;
    if (this.pos.y - (from.y || 0) > 0.7) return false;   // 跳んでかわした（同じ高さの相手の攻撃は当たる）
    this.hp -= amount;
    this.invuln = 0.6;
    this.actor.flash('#ff3030');
    audio.sfx('hurt');
    tmp.subVectors(this.pos, from).setY(0).normalize().multiplyScalar(5);
    this.knock = tmp.clone();
    if (this.hp <= 0) {
      this.hp = 0;
      this.state = 'dead';
      this.actor.play('Death01', { fade: 0.1, loop: false });
      audio.sfx('death');
    } else {
      this.state = 'hurt';
      this.hurtTime = 0.35;
      this.actor.play('Hit_Chest', { fade: 0.05, loop: false, speed: 1.6, restart: true });
    }
    return true;
  }

  revive(maxHP) {
    this.hp = maxHP;
    this.state = 'move';
    this.invuln = 1.5;
    this.actor.play('Idle_Loop', { fade: 0.1 });
  }
}

// ------------------------------------------------------------
// 町の人
// ------------------------------------------------------------
export class NPC {
  constructor(actor, def) {
    this.actor = actor;
    this.def = def;
    this.id = def.id;
    this.root = actor.root;
    this.root.position.set(def.pos[0], 0, def.pos[1]);
    this.baseFace = def.face;
    this.root.rotation.y = def.face;
    if (def.scale) this.root.scale.setScalar(def.scale);
    this.idle = def.anim;
    actor.play(this.idle, { fade: 0 });
    // 同じ動きでもずらして、そろって動かないように
    if (actor.current) actor.current.time = Math.random() * actor.current.getClip().duration;
    this.talking = false;
  }

  update(dt, player) {
    this.actor.update(dt);
    const d = this.root.position.distanceTo(player.pos);
    // 近くに来たら主人公のほうを向く（座っている人は向かない）
    if (!this.def.sit) {
      const target = d < 4.5 ? Math.atan2(player.pos.x - this.root.position.x, player.pos.z - this.root.position.z) : this.baseFace;
      this.root.rotation.y = turnTowards(this.root.rotation.y, target, dt * 4);
    }
    return d;
  }

  startTalk() {
    this.talking = true;
    if (!this.def.sit) this.actor.play('Idle_Talking_Loop', { fade: 0.3 });
  }

  endTalk() {
    this.talking = false;
    this.actor.play(this.idle, { fade: 0.4 });
  }
}

// ------------------------------------------------------------
// 敵
// ------------------------------------------------------------
export const ENEMY_TYPES = {
  bandit: { name: '盗賊', model: 'human_bandit', hp: 48, atk: 9, speed: 3.4, reach: 1.8, aggro: 13, windup: 0.45, cooldown: 1.1, weapon: 'Dagger', attack: 'Sword_Attack', run: 'Jog_Fwd_Loop', exp: 18, ankh: 25 },
  mummy: { name: 'ミイラ', model: 'human_mummy', hp: 64, atk: 12, speed: 1.5, reach: 1.6, aggro: 10, windup: 0.6, cooldown: 1.4, attack: 'Punch_Cross', run: 'Walk_Loop', runSpeed: 0.75, exp: 24, ankh: 30 },
  jackal: { name: '盗賊団の頭「黒ジャッカル」', model: 'jackal', hp: 320, atk: 17, speed: 3.9, reach: 2.2, aggro: 16, windup: 0.5, cooldown: 0.8, weapon: 'Sword_2', weaponTint: '#e0a95a', attack: 'Sword_Attack', run: 'Jog_Fwd_Loop', exp: 160, ankh: 400, scale: 1.2, boss: true },
  guardian: { name: '王墓の番人', model: 'jackal', hp: 260, atk: 16, speed: 3.6, reach: 2.2, aggro: 12, windup: 0.5, cooldown: 0.9, weapon: 'Scythe', weaponTint: '#9aa0c8', attack: 'Sword_Attack', run: 'Jog_Fwd_Loop', exp: 140, ankh: 300, scale: 1.15 },
};

export class Enemy {
  constructor(actor, type, pos) {
    this.actor = actor;
    this.type = type;
    this.def = ENEMY_TYPES[type];
    this.root = actor.root;
    this.pos = this.root.position;
    this.pos.set(pos.x, 0, pos.z);
    this.home = new THREE.Vector3(pos.x, 0, pos.z);
    if (this.def.scale) this.root.scale.setScalar(this.def.scale);
    this.maxHP = this.def.hp;
    this.hp = this.maxHP;
    this.state = 'idle';
    this.timer = 0;
    this.face = Math.random() * Math.PI * 2;
    this.radius = 0.45 * (this.def.scale || 1);
    this.stagger = 0;
    actor.play(type === 'mummy' ? 'Idle_Loop' : 'Sword_Idle', { fade: 0 });
    if (type === 'mummy') actor.setSpeed(0.6);
  }

  get alive() { return this.state !== 'dead'; }

  update(dt, player, world) {
    { const gy = world.colliders.groundAt(this.pos.x, this.pos.z, this.pos.y + 0.2); if (Number.isFinite(gy)) this.pos.y = gy; }   // 足場の上に立つ
    this.actor.update(dt);
    if (this.state === 'dead') {
      this.timer -= dt;
      if (this.timer < 1) this.root.position.y -= dt * 0.8; // 沈んで消える
      return this.timer > 0;
    }
    const d = this.pos.distanceTo(player.pos);
    const toPlayer = Math.atan2(player.pos.x - this.pos.x, player.pos.z - this.pos.z);
    const def = this.def;

    if (this.stagger > 0) {
      this.stagger -= dt;
      this.pos.x += this.knock.x * dt; this.pos.z += this.knock.z * dt;
      this.knock.multiplyScalar(Math.max(0, 1 - dt * 6));
      world.colliders.resolve(this.pos, this.radius);
      if (this.stagger <= 0) this.state = 'chase';
      return true;
    }

    switch (this.state) {
      case 'idle':
        if (this.dormant) break;   // 封印で眠っている
        if (player.alive && d < def.aggro && !world.colliders.blocked(this.pos, player.pos)) {
          this.state = 'chase';
          if (def.boss) world.bossAwake(this);
        }
        break;
      case 'chase': {
        if (!player.alive || d > def.aggro * 1.8) { this.state = 'return'; break; }
        this.face = turnTowards(this.face, toPlayer, dt * 6);
        if (d > def.reach * 0.85) {
          const sp = def.speed;
          this.pos.x += Math.sin(this.face) * sp * dt;
          this.pos.z += Math.cos(this.face) * sp * dt;
          this.actor.play(def.run, { fade: 0.2 });
          this.actor.setSpeed(def.runSpeed || sp / 4.4);
        } else if (this.timer <= 0) {
          // 攻撃の前ぶれ（ここで回避すればかわせる）
          this.state = 'windup';
          this.timer = def.windup;
          this.actor.play(def.boss ? 'Sword_Idle' : 'Idle_Loop', { fade: 0.15 });
          world.telegraph(this, def.windup);
        } else {
          this.actor.play(def.boss || def.weapon ? 'Sword_Idle' : 'Idle_Loop', { fade: 0.2 });
        }
        break;
      }
      case 'windup':
        this.face = turnTowards(this.face, toPlayer, dt * 4);
        if ((this.timer -= dt) <= 0) {
          this.state = 'attack';
          this.hitDone = false;
          this.actor.play(def.attack, { fade: 0.08, loop: false, speed: def.boss ? 1.5 : 1.25, restart: true });
          audio.sfx('swing');
        }
        break;
      case 'attack': {
        const p = this.actor.progress();
        if (!this.hitDone && p > 0.38) {
          this.hitDone = true;
          const ahead = Math.abs(((toPlayer - this.face + Math.PI * 3) % (Math.PI * 2)) - Math.PI) < 1.1;
          if (d < def.reach + 0.5 && ahead) world.enemyHit(this, player);
        }
        if (p > 0.85) {
          this.state = 'chase';
          this.timer = def.cooldown * (0.8 + Math.random() * 0.4);
          // ボスは続けて斬りかかることがある
          if (def.boss && Math.random() < 0.45) this.timer = 0.15;
        }
        break;
      }
      case 'return': {
        const back = Math.atan2(this.home.x - this.pos.x, this.home.z - this.pos.z);
        this.face = turnTowards(this.face, back, dt * 5);
        const dh = this.pos.distanceTo(this.home);
        if (dh > 0.6) {
          this.pos.x += Math.sin(this.face) * def.speed * 0.6 * dt;
          this.pos.z += Math.cos(this.face) * def.speed * 0.6 * dt;
          this.actor.play('Walk_Loop', { fade: 0.25 });
        } else {
          this.state = 'idle';
          this.actor.play('Idle_Loop', { fade: 0.3 });
        }
        if (player.alive && d < def.aggro * 0.8) this.state = 'chase';
        break;
      }
    }
    this.timer = Math.max(-1, this.timer - (this.state === 'chase' ? dt : 0));
    world.colliders.resolve(this.pos, this.radius);
    this.root.rotation.y = turnTowards(this.root.rotation.y, this.face, dt * 12);
    return true;
  }

  hurt(amount, from, { stun = false } = {}) {
    if (this.state === 'dead') return;
    this.hp -= amount;
    this.actor.flash('#ffffff', 0.1);
    if (this.hp <= 0) {
      this.hp = 0;
      this.state = 'dead';
      this.timer = 2.4;
      this.actor.play('Death01', { fade: 0.1, loop: false });
      return;
    }
    // ボス以外はのけぞる（大鎚ならボスも）
    if (!this.def.boss || stun) {
      this.stagger = stun ? 0.7 : 0.3;
      this.knock = tmp.subVectors(this.pos, from).setY(0).normalize().multiplyScalar(stun ? 7 : 4).clone();
      this.state = 'chase';
      this.actor.play('Hit_Chest', { fade: 0.05, loop: false, speed: 1.6, restart: true });
    } else if (this.state === 'idle') {
      this.state = 'chase';
    }
  }
}

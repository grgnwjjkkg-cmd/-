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
      if (s > 0.05) {
        this.pos.x += Math.sin(this.face) * s * dt;
        this.pos.z += Math.cos(this.face) * s * dt;
      }
      // 速さに合わせて足の動きを選ぶ（すべって見えないように再生速度も合わせる）
      if (s < 0.25) this.actor.play(armed ? 'Sword_Idle' : 'Idle_Loop', { fade: 0.25 });
      else if (s < 2.6) { this.actor.play('Walk_Loop', { fade: 0.2 }); this.actor.setSpeed(Math.max(0.5, s / 1.7)); }
      else { this.actor.play('Jog_Fwd_Loop', { fade: 0.2 }); this.actor.setSpeed(s / 4.6); }
      if (s > 0.5) {
        this.stepTimer -= dt * s;
        if (this.stepTimer <= 0) { audio.sfx('step'); this.stepTimer = 1.4; }
      }
    } else if (this.state === 'attack') {
      const p = this.actor.progress();
      if (!this.hitDone && p > 0.32) { this.hitDone = true; world.playerHit(this); }
      // 攻撃中は少し前に踏み込む
      if (p < 0.35) { this.pos.x += Math.sin(this.face) * 1.2 * dt; this.pos.z += Math.cos(this.face) * 1.2 * dt; }
      if (p > 0.55 && this.comboQueued) this.startAttack(stats);
      else if (p > 0.8) this.state = 'move';
    } else if (this.state === 'roll') {
      this.rollTime -= dt;
      const k = Math.max(0, this.rollTime / 0.65);
      this.pos.x += Math.sin(this.face) * 7.5 * k * dt;
      this.pos.z += Math.cos(this.face) * 7.5 * k * dt;
      if (this.rollTime <= 0) this.state = 'move';
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
    if (this.state === 'attack') { this.comboQueued = true; return; }
    if (this.state !== 'move') return;
    this.combo = 0;
    this.startAttack(stats);
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
    if (this.state !== 'move' && this.state !== 'attack') return;
    this.state = 'roll';
    this.rollTime = 0.65;
    this.invuln = 0.55;
    this.actor.play('Roll', { fade: 0.06, loop: false, speed: 1.35, restart: true });
    audio.sfx('roll');
  }

  hurt(amount, from, stats) {
    if (this.invuln > 0 || this.state === 'dead') return false;
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
  bandit: { name: '盗賊', model: 'bandit', hp: 48, atk: 9, speed: 3.4, reach: 1.8, aggro: 13, windup: 0.45, cooldown: 1.1, weapon: 'Dagger', attack: 'Sword_Attack', run: 'Jog_Fwd_Loop', exp: 18, ankh: 25 },
  mummy: { name: 'ミイラ', model: 'mummy', hp: 64, atk: 12, speed: 1.5, reach: 1.6, aggro: 10, windup: 0.6, cooldown: 1.4, attack: 'Punch_Cross', run: 'Walk_Loop', runSpeed: 0.75, exp: 24, ankh: 30 },
  jackal: { name: '盗賊団の頭「黒ジャッカル」', model: 'jackal', hp: 320, atk: 17, speed: 3.9, reach: 2.2, aggro: 16, windup: 0.5, cooldown: 0.8, weapon: 'Sword_2', weaponTint: '#e0a95a', attack: 'Sword_Attack', run: 'Jog_Fwd_Loop', exp: 160, ankh: 400, scale: 1.2, boss: true },
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

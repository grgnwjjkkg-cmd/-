// 第1章「眠りの墓からの脱出」
// プロローグ（夜の墓地 → 床が崩れる）→ 地下の前室で目覚める（閉じこめられている）→ 石棺を調べて剣とレバー → 奥へ
// → 盗賊団の間でスカラベを取り戻す → 墓が崩れはじめる → 入口まで走って脱出 → 夜明けの外へ
import * as THREE from 'three';
import { audio } from './audio.js';

const $ = id => document.getElementById(id);
const wait = ms => new Promise(r => setTimeout(r, ms));
const V = (x, y, z) => new THREE.Vector3(x, y, z);

// ---------- ムービーの道具：黒い帯、字幕、カメラ ----------
function cineUI(on) {
  let el = $('cine');
  if (!el) {
    el = document.createElement('div'); el.id = 'cine';
    el.innerHTML = '<div class="bar top"></div><div class="bar bot"></div><div class="sub"></div><div class="tint"></div>';
    document.body.appendChild(el);
  }
  el.classList.toggle('on', on);
  $('hud')?.classList.toggle('hidden', on);
  return el;
}
function subtitle(who, text) {
  const s = $('cine')?.querySelector('.sub'); if (!s) return;
  s.innerHTML = text ? (who ? `<b>${who}</b>` : '') + text : '';
  s.classList.toggle('show', !!text);
}
function tint(color, alpha) { const t = $('cine')?.querySelector('.tint'); if (t) { t.style.background = color; t.style.opacity = alpha; } }

/** カメラを from→to へ、秒数かけて動かす（注視点も） */
function camMove(g, from, to, lookFrom, lookTo, sec) {
  return new Promise(res => {
    const t0 = performance.now();
    const step = () => {
      const k = Math.min(1, (performance.now() - t0) / (sec * 1000)), e = k * k * (3 - 2 * k);
      g.cine = { pos: from.clone().lerp(to, e), look: lookFrom.clone().lerp(lookTo, e) };
      if (k < 1) requestAnimationFrame(step); else res();
    };
    step();
  });
}
/** ネフィを歩かせる（ムービー中） */
function walkTo(g, to, speed = 1.6) {
  const P = g.player;
  return new Promise(res => {
    P.actor.play('Walk_Loop', { fade: 0.2 }); P.actor.setSpeed(speed / 1.7);
    let last = performance.now();
    const step = () => {
      const now = performance.now(), dt = Math.min(0.25, (now - last) / 1000); last = now;
      const d = to.clone().sub(P.pos).setY(0), L = d.length();
      if (L < 0.05) { P.actor.play('Idle_Loop', { fade: 0.3 }); return res(); }
      P.face = Math.atan2(d.x, d.z); P.root.rotation.y = P.face;
      P.pos.addScaledVector(d.normalize(), Math.min(L, speed * dt));
      requestAnimationFrame(step);
    };
    step();
  });
}
async function line(who, text, voice, ms = 2600) {
  subtitle(who, text); if (voice) audio.voice(voice, { gap: 0 });
  await wait(ms);
}
const fade = async on => { $('fade').classList.toggle('on', on); await wait(550); };

// ---------- プロローグ ----------
export async function prologue(g) {
  const P = g.player;
  g.paused = true; cineUI(true);
  audio.play('tomb');
  // 夜の墓地：暗く青い
  tint('#1a3a8a', 0.55); g.canvas.style.filter = 'brightness(0.62) contrast(1.25) saturate(0.7)';
  P.pos.set(0, 0, 26); P.face = Math.PI; P.root.rotation.y = P.face;
  g.cine = { pos: V(10, 9, 44), look: V(0, 6, 0) };
  await wait(300); await fade(false);
  subtitle(null, '<i>祭りの夜、神殿から秘宝「太陽のスカラベ」が盗まれた。</i>'); await wait(3200);
  subtitle(null, '<i>町の「謎解き屋」――見習い巫女のネフィは、ひとり西岸の墓地へ向かう。</i>'); await wait(3400);
  const walk = walkTo(g, V(0, 0, 6), 1.5);
  camMove(g, V(10, 9, 44), V(3, 2.2, 14), V(0, 6, 0), V(0, 1.4, 4), 11);
  await wait(1500);
  await line('ネフィ', '夜の墓地……。盗まれた太陽のスカラベ、手がかりはここにあるはず。', 'p1', 5200);
  await walk;
  // しゃがんで足あとを見る
  P.actor.play('Crouch_Idle_Loop', { fade: 0.3 });
  g.cine = { pos: V(1.8, 0.9, 7.6), look: V(0, 0.2, 5) };
  await line('ネフィ', '足あとが三つ。……ひとつは、ずいぶん急いでる。', 'p2', 4200);
  P.actor.play('Idle_Loop', { fade: 0.3 });
  // 墓の入口へ
  const w2 = walkTo(g, V(0, 0, -9), 1.4);
  camMove(g, V(3, 2.2, 10), V(0.6, 2.0, -2), V(0, 1.4, 0), V(0, 1.2, -9), 6);
  await w2;
  // 床が崩れる
  audio.sfx('rumble'); g.shake = 1.2;
  await line('ネフィ', 'えっ……床が――！', 'p3', 1400);
  P.actor.play('Hit_Head', { fade: 0.05, loop: false });
  await fade(true);
  subtitle(null, ''); audio.sfx('rumble');
  await wait(1600);
  // 地下の前室で目覚める
  tint('#000', 0); g.canvas.style.filter = '';
  P.pos.set(0.5, 0, -22.5); P.face = Math.PI; P.root.rotation.y = P.face;
  P.actor.play('Death01', { fade: 0, loop: false }); P.actor.current.time = P.actor.current.getClip().duration - 0.01;
  g.cine = { pos: V(2.6, 1.6, -20), look: V(0.5, 0.3, -22.5) };
  await wait(200); await fade(false);
  await line('ネフィ', 'いたた……。ここ、どこ……？', 'wake', 3000);
  P.actor.play('Idle_Loop', { fade: 0.8 });
  camMove(g, V(2.6, 1.6, -20), V(0.5, 2.2, -19), V(0.5, 0.3, -22.5), V(0, 1.3, -28), 3);
  await wait(1500);
  await line('ネフィ', '……閉じこめられた、みたい。', 'trapped', 2600);
  await line('ネフィ', '出口は、ない。でも、風が通ってる。……なら、道はある。', 'p4', 4600);
  subtitle(null, '');
  g.cine = null; cineUI(false); g.camYaw = P.face + Math.PI; g.camPos = null;
  g.save.flags.prologue = true; g.persist();
  g.paused = false; g.refreshHUD();
  g.toast('左側をなぞって歩く。気になる所は「調べる」');
}

// ---------- 前室（閉じこめられた部屋） ----------
export class Tomb {
  constructor(g) {
    this.g = g; this.root = new THREE.Group(); g.scene.add(this.root);
    const f = g.save.flags, B = g.zone.colliders.boxes;
    const stone = new THREE.MeshStandardMaterial({ color: '#8a7358', roughness: 0.9 });
    // 入口をふさぐ崩れた岩（脱出のときに崩れて開く）
    this.rubble = new THREE.Group();
    for (let i = 0; i < 9; i++) {
      const r = new THREE.Mesh(new THREE.DodecahedronGeometry(0.5 + Math.random() * 0.5, 0), stone);
      r.position.set(-1.4 + (i % 3) * 1.4 + Math.random() * 0.3, 0.4 + Math.floor(i / 3) * 0.8, -17.2 + Math.random() * 0.6);
      r.rotation.set(Math.random() * 3, Math.random() * 3, 0); this.rubble.add(r);
    }
    this.root.add(this.rubble);
    this.rubbleBox = { minX: -2.4, maxX: 2.4, minZ: -18.2, maxZ: -16.2 };
    if (!f.escaped) B.push(this.rubbleBox); else this.rubble.visible = false;
    // 奥への石の扉（石棺のレバーで開く）
    this.door = new THREE.Mesh(new THREE.BoxGeometry(3.4, 4.6, 0.5), new THREE.MeshStandardMaterial({ color: '#9a8466', roughness: 0.85 }));
    this.door.position.set(0, 2.3, -29.8); this.root.add(this.door);
    this.doorBox = { minX: -1.8, maxX: 1.8, minZ: -30.1, maxZ: -29.5 };
    if (!f.leverPulled) B.push(this.doorBox); else this.door.visible = false;
    // 石棺（ふたが少しずれている）
    this.lid = new THREE.Mesh(new THREE.BoxGeometry(1.5, 0.22, 2.7), new THREE.MeshStandardMaterial({ color: '#b39a78', roughness: 0.8 }));
    this.lid.position.set(-4.2, 1.12, -27); this.lid.rotation.y = 0.18;
    if (f.coffinOpen) { this.lid.position.x = -5.1; this.lid.rotation.y = 0.5; }
    this.root.add(this.lid);
    g.puzzles.items.push({ kind: 'coffin', label: '調べる', x: -2.9, z: -27, r: 1.8, act: () => this.coffin() });
    // 最初の部屋のミイラは、剣を手に入れるまで眠っている
    this.sleeper = g.enemies.find(e => Math.hypot(e.pos.x - 3, e.pos.z + 24) < 1.5);
    if (this.sleeper && !f.leverPulled) this.sleeper.dormant = true;
  }

  async coffin() {
    const g = this.g, f = g.save.flags;
    if (f.leverPulled) { g.toast('石棺はからっぽだ'); return; }
    if (!f.coffinOpen) {
      f.coffinOpen = true;
      audio.sfx('stone'); this.lid.position.x = -5.1; this.lid.rotation.y = 0.5;
      audio.voice('look', { gap: 0 });
      await g.runSteps([
        { who: 'player', text: '……ふむ。ふたがずれてる。誰かが先に開けたみたい。' },
        { who: 'narr', text: '石棺の中に、古い青銅の剣が残されていた。' },
        { run: a => { a.game.addItem('bronze_dagger'); a.game.save.weapon = a.game.save.weapon || 'bronze_dagger'; a.game.equipVisual(); } },
        { who: 'narr', text: '「青銅の短剣」を手に入れた。……底に、石のレバーがある。' },
      ]);
    }
    await g.runSteps([{ choice: [
      { label: 'レバーを引く', steps: [{ run: () => this.pull() }] },
      { label: 'やめておく', steps: [{ who: 'player', text: 'もう少し、まわりを調べてからにしよう。' }] },
    ] }]);
  }

  pull() {
    const g = this.g;
    g.save.flags.leverPulled = true;
    audio.sfx('rumble'); g.shake = 0.5;
    const a = g.zone.colliders.boxes, i = a.indexOf(this.doorBox); if (i >= 0) a.splice(i, 1);
    this.sinkDoor = 0;
    setTimeout(() => audio.voice('solved', { gap: 0 }), 900);
    g.toast('ゴゴゴ……北の石の扉が沈んでいく');
    if (this.sleeper) { this.sleeper.dormant = false; setTimeout(() => g.toast('何かが動いた……！'), 1400); }
    g.persist();
  }

  // ---------- 崩れる墓からの脱出 ----------
  startCollapse() {
    const g = this.g;
    this.run = { t: 110, rockT: 0 };
    audio.sfx('rumble'); g.shake = 1.0; audio.voice('run', { gap: 0 });
    // 入口の岩も崩れて、外の光が見える
    const a = g.zone.colliders.boxes, i = a.indexOf(this.rubbleBox); if (i >= 0) a.splice(i, 1);
    this.rubble.visible = false;
    g.checkpoint = { zone: 'necropolis', x: 57, z: -95, face: -Math.PI / 2 };
    g.toast('墓が崩れはじめた！ 入口まで走れ！');
  }

  update(dt) {
    const g = this.g, P = g.player;
    if (this.sinkDoor != null && this.door.visible) { this.sinkDoor += dt; this.door.position.y = 2.3 - this.sinkDoor * 1.6; if (this.sinkDoor > 3) this.door.visible = false; }
    if (!this.run || g.paused) return;
    const R = this.run;
    R.t -= dt;
    // ときどき揺れて、天井から石が落ちてくる
    R.rockT -= dt;
    if (R.rockT <= 0) {
      R.rockT = 0.35 + Math.random() * 0.5;
      if (Math.random() < 0.3) { g.shake = 0.35; audio.sfx('rumble'); }
      const rock = new THREE.Mesh(new THREE.DodecahedronGeometry(0.25 + Math.random() * 0.35, 0), new THREE.MeshStandardMaterial({ color: '#8a7358', roughness: 0.9 }));
      rock.position.set(P.pos.x + (Math.random() - 0.5) * 7, 7, P.pos.z + (Math.random() - 0.5) * 7);
      rock.userData.v = 0; this.root.add(rock); (R.rocks ||= []).push(rock);
    }
    for (const r of R.rocks || []) {
      if (r.userData.done) continue;
      r.userData.v += 18 * dt; r.position.y -= r.userData.v * dt;
      if (r.position.y < 0.3) {
        r.userData.done = true; r.position.y = 0.25; g.fx?.puff(r.position.clone(), 5, 0.6, 1.4);
        if (Math.hypot(r.position.x - P.pos.x, r.position.z - P.pos.z) < 0.9 && P.alive) g.hazards?.hit(P, g, 8, '落ちてきた石に当たった！', null);
        setTimeout(() => { this.root.remove(r); r.geometry.dispose(); }, 2500);
      }
    }
    if (P.pos.z > -12 && Math.abs(P.pos.x) < 3) return this.escaped();
    if (R.t <= 0) { this.run = null; g.toast('墓が崩れた……！'); P.hp = 0; P.state = 'dead'; P.actor.play('Death01', { fade: 0.1, loop: false }); g.onPlayerDown(); }
  }

  async escaped() {
    const g = this.g, P = g.player;
    this.run = null; g.checkpoint = null;
    g.save.flags.escaped = true; g.save.flags.gateOpen = true;
    g.paused = true;
    await fade(true);
    cineUI(true);
    P.pos.set(0, 0, 4); P.face = 0; P.root.rotation.y = 0; P.actor.play('Idle_Loop', { fade: 0 });
    tint('#ff9a50', 0.18);
    g.cine = { pos: V(-3, 1.6, 9), look: V(0, 1.2, 3) };
    await fade(false);
    audio.sfx('rumble'); g.shake = 0.6;
    await line(null, '<i>揺れがおさまった。東の空が白みはじめている。</i>', null, 2800);
    camMove(g, V(-3, 1.6, 9), V(-4, 3, 16), V(0, 1.2, 3), V(0, 3, -20), 5);
    await line('ネフィ', '事件、解決。……たぶんね。', 'win', 3400);
    subtitle(null, ''); tint('#000', 0);
    g.cine = null; cineUI(false); g.camYaw = Math.PI; g.camPos = null;
    g.paused = false; g.persist(); g.refreshHUD();
    g.toast('夜が明けた。町へ戻って、神官長メリトにスカラベを届けよう（南の道）');
  }
}

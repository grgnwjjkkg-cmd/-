// ケメトの秘宝：ゲーム全体のまとめ役
import * as THREE from 'three';
import { Assets, Actor } from './actor.js';
import { Player, NPC, Enemy, ENEMY_TYPES } from './entities.js';
import { buildTown } from './world/zones.js';
import { loadBakedZone } from './world/baked.js';
import { skyTexture } from './world/textures.js';
import * as B from './world/builders.js';
import { PEOPLE, TOWN_NPCS, CLUES, FINDS, objective, script } from './story.js';
import { WEAPONS, AMULETS, RARITY, GACHA, itemDef, pull, pull10, gachaTable, playerStats, expToNext } from './items.js';
import { audio } from './audio.js';
// 主人公の見た目（MakeHuman で作ったリアルな人。tools/chars/make_human.py）
const HERO_MODEL = 'human_hero';
import { EffectComposer } from '../lib/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from '../lib/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from '../lib/jsm/postprocessing/UnrealBloomPass.js';
import { OutputPass } from '../lib/jsm/postprocessing/OutputPass.js';

const $ = id => document.getElementById(id);
const SAVE_KEY = 'kemet-save-v1';
const WEAPON_LENGTH = { Dagger: 0.5, Sword: 1.0, Sword_2: 0.95, Spear: 2.0, Axe_Small: 0.75, Axe: 1.15, Hammer_Small: 0.85, Sword_Golden: 1.1, Scythe: 1.8 };

const newSave = () => ({
  zone: 'town', x: 0, z: 30, face: Math.PI, flags: {}, clues: [], ankh: 0, level: 1, exp: 0,
  weapon: null, amulets: [null, null], inventory: {}, items: {}, pityCount: 0, chests: [], finds: [], bgm: true,
});

class Game {
  constructor() {
    this.canvas = $('view');
    this.renderer = new THREE.WebGLRenderer({ canvas: this.canvas, antialias: true, powerPreference: 'high-performance' });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.05;
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;

    this.scene = new THREE.Scene();
    const sky = skyTexture(); sky.mapping = THREE.EquirectangularReflectionMapping;
    this.sky = sky;
    this.scene.background = sky;
    this.fogOut = new THREE.Fog('#ecd2a0', 70, 380);
    this.scene.fog = this.fogOut;
    this.camera = new THREE.PerspectiveCamera(55, 1, 0.1, 3000);

    this.sun = new THREE.DirectionalLight('#fff0d6', 2.8);
    this.sun.castShadow = true;
    this.sun.shadow.mapSize.set(2048, 2048);
    Object.assign(this.sun.shadow.camera, { left: -28, right: 28, top: 28, bottom: -28, near: 1, far: 120 });
    this.sun.shadow.bias = -0.0004;
    this.sun.shadow.normalBias = 0.03;
    this.scene.add(this.sun, this.sun.target);
    this.hemi = new THREE.HemisphereLight('#cfe2ff', '#c9a06a', 1.0);
    this.scene.add(this.hemi);
    this.lantern = new THREE.PointLight('#ffb15c', 0, 12, 1.4);
    this.scene.add(this.lantern);
    this.inside = 0; // 0=外 1=墓の中（明るさを徐々に切り替える）

    this.assets = new Assets('assets/');
    this.clock = new THREE.Clock();
    this.time = 0;
    this.paused = true;
    this.input = { x: 0, y: 0 };
    this.camYaw = Math.PI;
    this.camPitch = 0.38;
    this.camDist = 6.5;
    this.lastDrag = 0;
    this.hitStop = 0;
    this.shake = 0;
    this.npcs = [];
    this.enemies = [];
    this.chests = [];
    this.pickups = [];
    this.telegraphs = [];
    this.icons = new Map();
    this.save = this.load() || newSave();

    // 光のにじみ（ブルーム）
    this.composer = new EffectComposer(this.renderer);
    this.composer.addPass(new RenderPass(this.scene, this.camera));
    this.bloom = new UnrealBloomPass(new THREE.Vector2(innerWidth, innerHeight), 0.35, 0.6, 0.85);
    this.composer.addPass(this.bloom);
    this.composer.addPass(new OutputPass());
    this.resize();
    window.addEventListener('resize', () => this.resize());
    this.setupInput();
    this.loop();
  }

  // ---------- 保存 ----------
  load() {
    try { const s = JSON.parse(localStorage.getItem(SAVE_KEY)); return s && s.flags ? { ...newSave(), ...s } : null; } catch { return null; }
  }
  persist() {
    if (this.player) { this.save.x = this.player.pos.x; this.save.z = this.player.pos.z; this.save.face = this.player.face; this.save.hp = this.player.hp; }
    try { localStorage.setItem(SAVE_KEY, JSON.stringify(this.save)); } catch {}
    try { window.webkit?.messageHandlers?.save?.postMessage(JSON.stringify(this.save)); } catch {}
  }

  get colliders() { return this.zone.colliders; }

  get stats() {
    const s = playerStats(this.save);
    s.weaponName = this.save.weapon;
    return s;
  }

  // ---------- 起動 ----------
  async boot() {
    const bar = $('loadBar');
    const set = p => { bar.style.width = Math.round(p * 100) + '%'; };
    await this.assets.init(set);
    const models = [...new Set(Object.values(WEAPONS).map(w => w.model))];
    await this.assets.preload([HERO_MODEL, ...TOWN_NPCS.map(n => n.model), 'human_bandit', 'human_mummy', 'jackal'], models, set);
    await this.makeIcons(models);
    await this.enterZone(this.save.zone, true);
    $('loadText').textContent = 'ナイルのほとり、古代の都メンネフェル。';
    $('startBtn').classList.remove('hidden');
    if (localStorage.getItem(SAVE_KEY)) $('continueBtn').classList.remove('hidden');
    this.titleMode = true;
    $('startBtn').onclick = () => this.start(true);
    $('continueBtn').onclick = () => this.start(false);
    window.GAME_READY = true;
  }

  async start(fresh) {
    audio.unlock();
    audio.setMuted(!this.save.bgm);
    if (fresh) {
      const bgm = this.save.bgm;
      this.save = newSave(); this.save.bgm = bgm;
      await this.enterZone('town', true);
    }
    this.titleMode = false;
    $('title').classList.add('hidden');
    $('hud').classList.remove('hidden');
    this.paused = false;
    this.refreshHUD();
    audio.play(this.zone.music);
    if (fresh) {
      await this.runSteps([
        { who: 'narr', text: '古代エジプト、ナイルのほとりの都メンネフェル。' },
        { who: 'narr', text: '祭りの夜、神殿から秘宝「太陽のスカラベ」が盗まれた。' },
        { who: 'narr', text: '駆け出しの宝探し屋のあなたのもとに、神殿から呼び出しが届く――。' },
      ]);
      this.toast('左下のスティックで歩く／右側をなぞって見回す');
    }
  }

  /** 武器のアイコン（3Dモデルを小さく撮影） */
  async makeIcons(models) {
    const r = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
    r.setSize(128, 128); r.outputColorSpace = THREE.SRGBColorSpace;
    const sc = new THREE.Scene();
    sc.add(new THREE.HemisphereLight('#fff', '#886', 2.2));
    const dl = new THREE.DirectionalLight('#fff', 2); dl.position.set(2, 3, 4); sc.add(dl);
    const cam = new THREE.PerspectiveCamera(30, 1, 0.1, 10); cam.position.set(0, 0, 2.2); cam.lookAt(0, 0, 0);
    for (const [id, w] of Object.entries(WEAPONS)) {
      const m = await this.assets.makeWeapon(w.model, w.tint);
      m.rotation.z = -Math.PI / 4;
      const holder = new THREE.Group(); holder.add(m); sc.add(holder);
      const box = new THREE.Box3().setFromObject(holder), c = box.getCenter(new THREE.Vector3());
      m.position.sub(c);
      r.render(sc, cam);
      this.icons.set(id, r.domElement.toDataURL());
      sc.remove(holder);
    }
    r.dispose();
  }

  icon(id) {
    if (this.icons.has(id)) return `<img src="${this.icons.get(id)}" alt="">`;
    const emoji = { scarab_charm: '🪲', lotus_charm: '🪷', feather_charm: '🪶', eye_charm: '👁️', ankh_charm: '☥', sun_disk: '☀️', candy: '🍯', scarab: '🪲' };
    return `<span>${emoji[id] || '?'}</span>`;
  }

  // ---------- 場所の切り替え ----------
  async enterZone(name, initial = false, arrivalFrom = null) {
    if (!initial) { $('fade').classList.add('on'); await wait(500); }
    if (this.zone) this.scene.remove(this.zone.root);
    for (const e of [...this.npcs, ...this.enemies]) this.scene.remove(e.root);
    for (const c of this.chests) this.scene.remove(c.group);
    for (const p of this.pickups) this.scene.remove(p.mesh);
    this.npcs = []; this.enemies = []; this.chests = []; this.pickups = [];
    this.boss = null; $('bossbar').classList.add('hidden');

    // 光を焼き付けた地図があればそれを使い、なければコードで作る町
    this.zone = await loadBakedZone(name, this).catch(e => { if (name !== 'town') throw e; return buildTown(); });
    this.scene.add(this.zone.root);
    this.save.zone = name;

    if (!this.player) {
      this.player = new Player(new Actor(await this.assets.makeChar(HERO_MODEL), this.assets));
      this.scene.add(this.player.root);
    }
    await this.equipVisual();
    const spot = arrivalFrom ? this.zone.arrivals[arrivalFrom] : (initial && this.save.x !== undefined && this.save.zone === name ? { x: this.save.x, z: this.save.z, face: this.save.face } : this.zone.spawn);
    this.player.pos.set(spot.x, 0, spot.z);
    this.player.face = spot.face ?? 0;
    this.player.root.rotation.y = this.player.face;
    this.camYaw = this.player.face + Math.PI;
    this.player.revive(this.stats.maxHP);
    if (this.save.hp && initial) this.player.hp = Math.min(this.save.hp, this.stats.maxHP);

    if (name === 'town') {
      if (this.save.flags.gateOpen) this.zone.openGate(true);
      for (const def of TOWN_NPCS) {
        const npc = new NPC(new Actor(await this.assets.makeChar(def.model), this.assets), def);
        this.npcs.push(npc); this.scene.add(npc.root);
        const label = document.createElement('div'); label.className = 'label';
        $('labels').appendChild(label); npc.label = label;
      }
    } else {
      for (const s of this.zone.enemySpawns) {
        if (s.boss && this.save.flags.bossDown) continue;
        await this.spawnEnemy(s.type, s);
      }
      this.zone.chests.forEach((c, i) => this.makeChest(c, i));
      const sc = this.zone.scarab || { x: 25, z: -118 };
      if (name === 'necropolis' && this.save.flags.bossDown && !this.save.flags.gotScarab) this.dropScarab(new THREE.Vector3(sc.x, 0, sc.z));
    }
    this.makeFinds(name);
    this.setupPyramid(!initial);
    if (!initial && ['necropolis', 'giza'].includes(name) && !this.save.flags.tipLookUp) {
      this.save.flags.tipLookUp = true;
      setTimeout(() => this.toast('画面の右側を上下になぞると、見上げたり見下ろしたりできる'), 1200);
    }
    for (const el of [...$('labels').children]) if (!this.npcs.some(n => n.label === el)) el.remove();
    this.inside = 0;
    if (!initial) { audio.play(this.zone.music); await wait(100); $('fade').classList.remove('on'); }
    this.persist();
  }

  async spawnEnemy(type, pos) {
    const def = ENEMY_TYPES[type];
    const actor = new Actor(await this.assets.makeChar(def.model), this.assets);
    if (def.weapon) actor.hold(await this.assets.makeWeapon(def.weapon, def.weaponTint), WEAPON_LENGTH[def.weapon]);
    const e = new Enemy(actor, type, pos);
    this.enemies.push(e); this.scene.add(e.root);
  }

  /** 探索で見つける物：かすかにきらめく */
  makeFinds(zoneName) {
    for (const f of this.finds || []) this.scene.remove(f.fx);
    this.finds = [];
    for (const def of FINDS[zoneName] || []) {
      if ((this.save.finds || []).includes(def.id)) continue;
      const pts = [];
      for (let i = 0; i < 18; i++) pts.push((Math.random() - 0.5) * 0.6, Math.random() * 0.8 + 0.1, (Math.random() - 0.5) * 0.6);
      const fx = new THREE.Points(new THREE.BufferGeometry().setAttribute('position', new THREE.Float32BufferAttribute(pts, 3)),
        new THREE.PointsMaterial({ color: '#ffe8a0', size: 0.07, transparent: true, opacity: 0.9, blending: THREE.AdditiveBlending, depthWrite: false }));
      fx.position.set(def.x, 0, def.z);
      this.scene.add(fx);
      this.finds.push({ def, fx });
    }
  }

  makeChest(c, index) {
    if (this.zone.name !== 'necropolis') index = `${this.zone.name}:${index}`;
    const opened = this.save.chests.includes(index);
    const group = new THREE.Group();
    const body = new THREE.Mesh(new THREE.BoxGeometry(1.1, 0.6, 0.7), B.M.wood()); body.position.y = 0.3;
    const lid = new THREE.Group(); lid.position.set(0, 0.6, -0.35);
    const lidMesh = new THREE.Mesh(new THREE.BoxGeometry(1.14, 0.22, 0.74), B.M.gold()); lidMesh.position.set(0, 0.11, 0.35);
    lid.add(lidMesh);
    if (opened) lid.rotation.x = -1.8;
    group.add(body, lid); group.position.set(c.x, 0, c.z);
    group.traverse(o => { if (o.isMesh) o.castShadow = true; });
    this.scene.add(group);
    this.zone.colliders.circle(c.x, c.z, 0.6);
    this.chests.push({ group, lid, index, ankh: c.ankh, opened, x: c.x, z: c.z });
  }

  /** ピラミッド：石板の数で封印の印が光り、3つそろうと扉が開く。開いていれば王の間に秘宝 */
  setupPyramid() {
    const seal = this.zone.seal;
    if (!seal) return;
    const n = this.pyramidTablets();
    seal.setCount(n);
    if (n >= 3 || this.save.flags.pyrSeal) seal.openNow(true);
    if (seal.open && !this.save.flags.pyrRelic && this.zone.relic) this.dropRelic();
  }

  pyramidTablets() { return (FINDS.pyramid || []).filter(d => (this.save.finds || []).includes(d.id)).length; }

  dropRelic() {
    const r = this.zone.relic;
    const mesh = new THREE.Group();
    const eye = new THREE.Mesh(new THREE.SphereGeometry(0.26, 24, 16), new THREE.MeshStandardMaterial({ color: '#3fa0ff', emissive: '#2a7bff', emissiveIntensity: 1.4, metalness: 0.4, roughness: 0.15 }));
    const ring = new THREE.Mesh(new THREE.TorusGeometry(0.42, 0.06, 12, 40), new THREE.MeshStandardMaterial({ color: '#ffd35a', emissive: '#ff9a20', emissiveIntensity: 0.8, metalness: 0.9, roughness: 0.2 }));
    mesh.add(eye, ring); mesh.add(new THREE.PointLight('#7ab8ff', 25, 9));
    mesh.position.set(r.x, 1.6, r.z);
    this.scene.add(mesh);
    this.pickups.push({ mesh, kind: 'relic', baseY: 1.6 });
  }

  /** 秘宝を取ったあと：ピラミッドが崩れはじめる。時間内に外へ出る */
  startEscape() {
    this.escape = { t: 100, rock: 0 };
    audio.sfx('rumble');
  }

  updateEscape(dt) {
    const E = this.escape;
    if (!E || this.paused) return;
    E.t -= dt;
    this.shake = Math.max(this.shake, 0.18 + (E.t < 30 ? 0.12 : 0));
    E.rock -= dt;
    if (E.rock <= 0) {   // 天井から石が落ちてくる
      E.rock = 0.35 + Math.random() * 0.5;
      const p = this.player.pos, a = Math.random() * Math.PI * 2, d = Math.random() * 5;
      const s = 0.25 + Math.random() * 0.4;
      const m = new THREE.Mesh(new THREE.DodecahedronGeometry(s, 0), new THREE.MeshStandardMaterial({ color: '#b9a078', roughness: 1 }));
      m.position.set(p.x + Math.sin(a) * d, 9, p.z + Math.cos(a) * d);
      this.scene.add(m);
      (this.falling ||= []).push({ m, v: 0, s });
      if (Math.random() < 0.3) audio.sfx('rumble');
    }
    const sec = Math.max(0, Math.ceil(E.t));
    $('objText').textContent = `崩れる前に外へ脱出しろ！ 残り ${sec} 秒`;
    if (E.t <= 0) this.escapeFailed();
  }

  updateFalling(dt) {
    if (!this.falling) return;
    this.falling = this.falling.filter(f => {
      f.v += 20 * dt; f.m.position.y -= f.v * dt; f.m.rotation.x += dt * 3;
      if (f.m.position.y <= f.s * 0.6) {
        f.m.position.y = f.s * 0.6;
        if (!f.landed) {
          f.landed = true; f.life = 3;
          const d = Math.hypot(f.m.position.x - this.player.pos.x, f.m.position.z - this.player.pos.z);
          if (d < 0.9 && this.player.hp > 0) { this.player.hp -= 6; this.player.actor.flash(); audio.sfx('hurt'); this.refreshHUD(); }
        }
        f.life -= dt;
        if (f.life <= 0) { this.scene.remove(f.m); return false; }
      }
      return true;
    });
  }

  async escapeSucceeded() {
    this.save.flags.pyrEscaped = true;
    this.shake = 0.8; audio.sfx('rumble');
    await this.runSteps([{ who: 'narr', text: '外へ飛び出した直後、背後で通路が崩れ落ちた。' },
      { who: 'narr', text: '脱出成功！ 秘宝「ホルスの眼」を持ち帰った。' },
      { run: a => { a.giveItem('horus_eye'); a.giveAnkh(600); } }]);
    this.refreshHUD(); this.persist();
  }

  async escapeFailed() {
    this.escape = null; this.paused = true;
    await this.runSteps([{ who: 'narr', text: '出口が岩でふさがれた……！' }, { who: 'narr', text: '気がつくと、秘宝は石棺の上に戻っていた。もう一度挑戦しよう。' }]);
    this.save.flags.pyrRelic = false;
    await this.enterZone('pyramid', false, 'giza');
    this.paused = false; this.refreshHUD();
  }

  dropScarab(pos) {
    const mesh = new THREE.Mesh(new THREE.SphereGeometry(0.35, 20, 14), new THREE.MeshStandardMaterial({ color: '#ffd35a', emissive: '#ff9a20', emissiveIntensity: 1.2, metalness: 0.8, roughness: 0.2 }));
    mesh.scale.set(1, 0.6, 1.3);
    const light = new THREE.PointLight('#ffb040', 20, 8); mesh.add(light);
    mesh.position.copy(pos).setY(1);
    this.scene.add(mesh);
    this.pickups.push({ mesh, kind: 'scarab' });
  }

  async equipVisual() {
    const id = this.save.weapon;
    if (!id) { this.player?.actor.hold(null); return; }
    const w = WEAPONS[id];
    const mesh = await this.assets.makeWeapon(w.model, w.tint);
    if (w.glow) mesh.traverse(o => { if (o.isMesh) [].concat(o.material).forEach(m => { m.emissive = new THREE.Color(w.glow); m.emissiveIntensity = 0.5; }); });
    this.player.actor.hold(mesh, WEAPON_LENGTH[w.model]);
  }

  // ---------- 入力 ----------
  setupInput() {
    const zone = $('stickZone'), base = $('stickBase'), knob = $('stickKnob');
    let stickId = null, cx = 0, cy = 0;
    zone.addEventListener('pointerdown', e => {
      audio.unlock();
      stickId = e.pointerId; zone.setPointerCapture(e.pointerId);
      const r = base.getBoundingClientRect();
      // 触ったところにスティックを移動
      const zr = zone.getBoundingClientRect();
      base.style.left = (e.clientX - zr.left - r.width / 2) + 'px';
      base.style.bottom = (zr.bottom - e.clientY - r.height / 2) + 'px';
      cx = e.clientX; cy = e.clientY;
    });
    zone.addEventListener('pointermove', e => {
      if (e.pointerId !== stickId) return;
      let dx = e.clientX - cx, dy = e.clientY - cy;
      const len = Math.hypot(dx, dy), max = 52;
      if (len > max) { dx *= max / len; dy *= max / len; }
      knob.style.transform = `translate(${dx}px, ${dy}px)`;
      this.input.x = dx / max; this.input.y = -dy / max;
    });
    const end = e => {
      if (e.pointerId !== stickId) return;
      stickId = null; knob.style.transform = ''; this.input.x = 0; this.input.y = 0;
      base.style.left = ''; base.style.bottom = '';
    };
    zone.addEventListener('pointerup', end); zone.addEventListener('pointercancel', end);

    // 画面の右側をなぞってカメラを回す
    let camId = null, lx = 0, ly = 0;
    this.canvas.addEventListener('pointerdown', e => {
      audio.unlock();
      if (camId !== null) return;
      camId = e.pointerId; lx = e.clientX; ly = e.clientY; this.canvas.setPointerCapture(e.pointerId);
    });
    this.canvas.addEventListener('pointermove', e => {
      if (e.pointerId !== camId) return;
      this.camYaw -= (e.clientX - lx) * 0.008;
      this.camPitch = THREE.MathUtils.clamp(this.camPitch + (e.clientY - ly) * 0.005, -0.75, 1.2);  // 上下になぞって見上げる・見下ろす
      lx = e.clientX; ly = e.clientY; this.lastDrag = this.time;
    });
    const endCam = e => { if (e.pointerId === camId) camId = null; };
    this.canvas.addEventListener('pointerup', endCam); this.canvas.addEventListener('pointercancel', endCam);

    const tap = (el, fn) => el.addEventListener('pointerdown', e => { e.stopPropagation(); e.preventDefault(); audio.unlock(); fn(); });
    tap($('atkBtn'), () => { if (!this.paused) this.player.attack(this.stats); });
    tap($('rollBtn'), () => { if (!this.paused) this.player.roll(); });
    tap($('actBtn'), () => this.interact());
    tap($('menuBtn'), () => this.openMenu());

    // パソコンで試すとき用のキー操作
    const keys = new Set();
    const upd = () => {
      this.input.x = (keys.has('d') ? 1 : 0) - (keys.has('a') ? 1 : 0);
      this.input.y = (keys.has('w') ? 1 : 0) - (keys.has('s') ? 1 : 0);
      if (keys.has('shift')) { this.input.x *= 0.5; this.input.y *= 0.5; }
    };
    window.addEventListener('keydown', e => {
      const k = e.key.toLowerCase(); keys.add(k); upd();
      if (k === 'j' && !this.paused) this.player.attack(this.stats);
      if (k === 'k' && !this.paused) this.player.roll();
      if (k === 'e') this.interact();
      // 矢印キーでカメラ（上下＝見上げる・見下ろす、左右＝回す）
      if (k === 'arrowup') this.camPitch = Math.max(-0.75, this.camPitch - 0.12);
      if (k === 'arrowdown') this.camPitch = Math.min(1.2, this.camPitch + 0.12);
      if (k === 'arrowleft') { this.camYaw += 0.15; this.lastDrag = this.time; }
      if (k === 'arrowright') { this.camYaw -= 0.15; this.lastDrag = this.time; }
    });
    window.addEventListener('keyup', e => { keys.delete(e.key.toLowerCase()); upd(); });
  }

  // ---------- 調べる・話す ----------
  nearest() {
    if (!this.player) return null;
    const p = this.player.pos;
    let best = null, bd = Infinity;
    for (const n of this.npcs) { const d = n.root.position.distanceTo(p); if (d < 3.2 && d < bd) { bd = d; best = { kind: 'npc', npc: n, label: '話す' }; } }
    if (this.zone.pot) { const d = Math.hypot(p.x - this.zone.pot.x, p.z - this.zone.pot.z); if (d < 4 && d < bd) { bd = d; best = { kind: 'pot', label: '祈る' }; } }
    for (const c of this.chests) if (!c.opened) { const d = Math.hypot(p.x - c.x, p.z - c.z); if (d < 2 && d < bd) { bd = d; best = { kind: 'chest', chest: c, label: '開ける' }; } }
    for (const f of this.finds || []) { const d = Math.hypot(p.x - f.def.x, p.z - f.def.z); if (d < 2.2 && d < bd) { bd = d; best = { kind: 'find', find: f, label: '調べる' }; } }
    for (const k of this.pickups) { const d = Math.hypot(p.x - k.mesh.position.x, p.z - k.mesh.position.z); if (d < 2.2 && d < bd) { bd = d; best = { kind: 'pickup', pickup: k, label: '拾う' }; } }
    return best;
  }

  async interact() {
    if (this.paused || !this.player.alive) return;
    const t = this.nearest();
    if (!t) return;
    audio.sfx('ui');
    if (t.kind === 'npc') {
      const npc = t.npc;
      npc.startTalk();
      this.player.face = Math.atan2(npc.root.position.x - this.player.pos.x, npc.root.position.z - this.player.pos.z);
      await this.runSteps(script(npc.id, this.save), npc.id);
      npc.endTalk();
    } else if (t.kind === 'pot') {
      this.openGacha();
    } else if (t.kind === 'chest') {
      const c = t.chest;
      c.opened = true; this.save.chests.push(c.index);
      const start = this.time;
      const anim = () => { const k = Math.min(1, (this.time - start) / 0.5); c.lid.rotation.x = -1.8 * k; if (k < 1) requestAnimationFrame(anim); };
      anim();
      this.gainAnkh(c.ankh);
      this.persist();
    } else if (t.kind === 'find') {
      const f = t.find;
      this.scene.remove(f.fx);
      this.finds.splice(this.finds.indexOf(f), 1);
      (this.save.finds ||= []).push(f.def.id);
      audio.sfx('clue');
      const all = (FINDS[this.zone.name] || []).every(d => this.save.finds.includes(d.id));
      const steps = [{ who: 'narr', text: `${f.def.title}を見つけた。` }, { who: 'narr', text: f.def.text }];
      if (this.zone.seal) {
        this.zone.seal.setCount(this.pyramidTablets());
        if (all) steps.push({ who: 'narr', text: '3枚の石板がそろった。遠くで重い石が動く音がする……' },
          { run: a => { const g = a.game; g.save.flags.pyrSeal = true; g.zone.seal.openNow(false); g.shake = 0.6; audio.sfx('rumble'); g.dropRelic(); } },
          { who: 'narr', text: '王の間の封印が解けた！' });
        else steps.push({ who: 'narr', text: `封印の扉の印が ${this.pyramidTablets()} つ光った。（あと ${3 - this.pyramidTablets()} 枚）` });
      } else if (all) steps.push({ who: 'narr', text: '3つのかけらがそろった。石板の言葉が読める……' },
        { run: g => { g.addClue('tablet'); g.giveItem('eye_charm'); } },
        { who: 'narr', text: 'かけらの裏に「ウアジェトの目」のお守りが埋め込まれていた！' });
      await this.runSteps(steps);
    } else if (t.kind === 'pickup' && t.pickup.kind === 'relic') {
      this.scene.remove(t.pickup.mesh);
      this.pickups.splice(this.pickups.indexOf(t.pickup), 1);
      this.save.flags.pyrRelic = true;
      audio.sfx('rare');
      await this.runSteps([{ who: 'narr', text: '秘宝「ホルスの眼」を手に入れた！' },
        { who: 'narr', text: '……ピラミッド全体が揺れはじめた！ 崩れる前に外へ脱出しろ！' }]);
      this.startEscape();
    } else if (t.kind === 'pickup') {
      this.scene.remove(t.pickup.mesh);
      this.pickups.splice(this.pickups.indexOf(t.pickup), 1);
      this.save.items.scarab = 1;
      this.save.flags.gotScarab = true;
      audio.sfx('rare');
      await this.runSteps([{ who: 'narr', text: '太陽のスカラベを取り戻した！' }, { who: 'narr', text: '神殿のネフェルに届けよう。' }]);
      this.refreshHUD(); this.persist();
    }
  }

  /** 会話を進める */
  async runSteps(steps, speaker) {
    this.paused = true;
    this.input.x = this.input.y = 0;
    $('dialog').classList.remove('hidden');
    $('buttons').classList.add('hidden');
    const api = this.api();
    for (const step of steps) {
      if (step.run) { step.run(api); continue; }
      if (step.choice) {
        const picked = await this.choose(step.choice);
        await this.runStepsInner(picked.steps, api);
        continue;
      }
      await this.say(step.who, step.text);
    }
    $('dialog').classList.add('hidden');
    $('buttons').classList.remove('hidden');
    this.paused = !!this.panelOpen;
    this.refreshHUD();
    this.persist();
  }

  async runStepsInner(steps, api) {
    for (const step of steps) {
      if (step.run) step.run(api);
      else if (step.choice) await this.runStepsInner((await this.choose(step.choice)).steps, api);
      else await this.say(step.who, step.text);
    }
  }

  say(who, text) {
    return new Promise(resolve => {
      const p = PEOPLE[who];
      $('dlgName').innerHTML = who === 'narr' ? '―' : `${p?.name || who}${p?.title ? `<small>${p.title}</small>` : ''}`;
      $('dlgName').style.visibility = who === 'narr' ? 'hidden' : 'visible';
      $('dlgChoices').innerHTML = '';
      const el = $('dlgText');
      el.textContent = '';
      let i = 0, done = false;
      const timer = setInterval(() => {
        el.textContent = text.slice(0, ++i);
        if (i % 3 === 0 && who !== 'narr') audio.sfx('talk');
        if (i >= text.length) { clearInterval(timer); done = true; }
      }, 28);
      const next = e => {
        e.stopPropagation();
        if (!done) { clearInterval(timer); el.textContent = text; done = true; return; }
        $('dialog').removeEventListener('pointerdown', next);
        resolve();
      };
      setTimeout(() => $('dialog').addEventListener('pointerdown', next), 60);
    });
  }

  choose(options) {
    return new Promise(resolve => {
      const box = $('dlgChoices');
      box.innerHTML = '';
      $('dlgNext').classList.add('hidden');
      for (const o of options) {
        const b = document.createElement('button');
        b.textContent = o.label;
        b.addEventListener('pointerdown', e => { e.stopPropagation(); audio.sfx('ui'); box.innerHTML = ''; $('dlgNext').classList.remove('hidden'); resolve(o); });
        box.appendChild(b);
      }
    });
  }

  /** 会話の中から呼べる処理 */
  api() {
    const g = this;
    return {
      game: g,
      setFlag(name, value = true) { g.save.flags[name] = value; },
      addClue(id) { if (!g.save.clues.includes(id)) { g.save.clues.push(id); g.toast(`ヒント帳に「${CLUES[id].title}」を書いた`); audio.sfx('clue'); } },
      giveAnkh(n) { g.gainAnkh(n); },
      giveExp(n) { g.gainExp(n); },
      takeItem(id) { delete g.save.items[id]; },
      giveItem(id) { g.addItem(id); g.toast(`${itemDef(id).name}を手に入れた`); },
      buyCandy() {
        if (g.save.ankh < 10) { g.toast('アンクが足りない'); return; }
        g.save.ankh -= 10; g.save.items.candy = 1; g.save.flags.hasCandy = true;
        g.toast('デーツの蜜菓子を買った'); audio.sfx('coin');
      },
      openShop() { setTimeout(() => g.openShop(), 50); },
      openGate() { g.zone.openGate?.(); g.toast('西門が開いた！'); },
      chapterClear() { setTimeout(() => g.showClear(), 300); },
    };
  }

  // ---------- 戦闘 ----------
  playerHit(player) {
    const s = this.stats;
    let hitAny = false;
    for (const e of this.enemies) {
      if (!e.alive) continue;
      const dx = e.pos.x - player.pos.x, dz = e.pos.z - player.pos.z, d = Math.hypot(dx, dz);
      if (d > s.reach + e.radius) continue;
      const ang = Math.atan2(dx, dz) - player.face;
      const diff = Math.abs(Math.atan2(Math.sin(ang), Math.cos(ang)));
      if (diff > 1.25 && d > 0.9) continue;
      const crit = Math.random() < s.crit;
      const dmg = Math.round(s.atk * (0.9 + Math.random() * 0.2) * (crit ? 1.8 : 1) * (player.combo === 0 ? 1.3 : 1));
      e.hurt(dmg, player.pos, { stun: s.stun });
      this.popNumber(e.pos, dmg, crit ? 'crit' : '');
      if (s.drain) this.player.hp = Math.min(s.maxHP, this.player.hp + dmg * s.drain);
      hitAny = true;
      if (!e.alive) this.onEnemyDown(e);
    }
    if (hitAny) { audio.sfx('hit'); this.hitStop = 0.06; this.shake = 0.12; }
  }

  enemyHit(enemy, player) {
    const dmg = Math.round(enemy.def.atk * (0.9 + Math.random() * 0.2) * (1 + (this.save.flags.bossDown ? 0 : 0)));
    if (player.hurt(dmg, enemy.pos, this.stats)) {
      this.popNumber(player.pos, dmg, 'hurt');
      this.shake = 0.25;
      if (!player.alive) this.onPlayerDown();
    }
  }

  telegraph(enemy, time) {
    const ring = new THREE.Mesh(new THREE.RingGeometry(0.2, 0.35, 32), new THREE.MeshBasicMaterial({ color: '#ff3b2f', transparent: true, opacity: 0.8, depthWrite: false }));
    ring.rotation.x = -Math.PI / 2;
    this.scene.add(ring);
    this.telegraphs.push({ ring, enemy, time, left: time });
  }

  bossAwake(e) {
    this.boss = e;
    $('bossName').textContent = e.def.name;
    $('bossbar').classList.remove('hidden');
    audio.play('battle');
  }

  onEnemyDown(e) {
    audio.sfx('death');
    this.gainExp(e.def.exp);
    this.gainAnkh(e.def.ankh);
    if (e.def.boss) {
      this.save.flags.bossDown = true;
      $('bossbar').classList.add('hidden');
      this.boss = null;
      audio.play('tomb');
      this.dropScarab(e.pos.clone());
      this.toast('黒ジャッカルを倒した！');
    }
    this.persist();
  }

  async onPlayerDown() {
    await wait(1600);
    const lost = Math.floor(this.save.ankh * 0.1);
    this.save.ankh -= lost;
    this.toast(`力尽きた…（${lost}アンクを落とした）`);
    await this.enterZone(this.zone.name, false, null);
    this.player.revive(this.stats.maxHP);
  }

  gainAnkh(n) {
    this.save.ankh += n;
    this.toast(`+${n} ☥`);
    audio.sfx('coin');
    this.refreshHUD();
  }

  gainExp(n) {
    this.save.exp += n;
    let up = false;
    while (this.save.exp >= expToNext(this.save.level)) { this.save.exp -= expToNext(this.save.level); this.save.level++; up = true; }
    if (up) { this.player.hp = this.stats.maxHP; this.toast(`レベルアップ！ Lv.${this.save.level}`); audio.sfx('rare'); }
    this.refreshHUD();
  }

  popNumber(pos, value, cls) {
    const v = pos.clone().setY(pos.y + 2).project(this.camera);
    const el = document.createElement('div');
    el.className = 'dmg ' + cls;
    el.textContent = value;
    el.style.left = ((v.x + 1) / 2 * innerWidth + (Math.random() - 0.5) * 30) + 'px';
    el.style.top = ((1 - v.y) / 2 * innerHeight) + 'px';
    $('labels').appendChild(el);
    setTimeout(() => el.remove(), 900);
  }

  toast(text) {
    const el = document.createElement('div');
    el.className = 'toast'; el.textContent = text;
    $('toasts').appendChild(el);
    setTimeout(() => el.remove(), 2600);
  }

  // ---------- 画面表示 ----------
  refreshHUD() {
    const s = this.stats;
    $('lv').textContent = `Lv.${this.save.level}`;
    const hp = Math.ceil(this.player?.hp ?? s.maxHP);
    $('hpText').textContent = `${hp}/${s.maxHP}`;
    $('hpBar').style.width = (hp / s.maxHP * 100) + '%';
    $('expBar').style.width = (this.save.exp / expToNext(this.save.level) * 100) + '%';
    $('ankhText').textContent = this.save.ankh.toLocaleString();
    $('objText').textContent = this.zoneObjective() || objective(this.save);
  }

  zoneObjective() {
    const f = this.save.flags, z = this.zone?.name;
    if (this.escape) return `崩れる前に外へ脱出しろ！ 残り ${Math.ceil(this.escape.t)} 秒`;
    if (z === 'pyramid' && !f.pyrRelic) {
      const n = this.pyramidTablets();
      return n < 3 ? `ピラミッドの中で石板を探せ（${n}/3）。封印の扉が開く` : '王の間へ。石棺の上の秘宝を手に入れよう';
    }
    if (z === 'giza' && !f.pyrEscaped) return '大ピラミッドのふもとの「盗掘者の穴」から中へ入ろう';
    return null;
  }

  /** 次に話すべき人に「！」 */
  important(id) {
    const f = this.save.flags;
    switch (id) {
      case 'nefer': return !f.metNefer || (f.gotScarab && !f.chapterClear);
      case 'amen': return f.metNefer && !f.clueDocks && !!f.hasCandy;
      case 'tawi': return f.metNefer && !f.clueDocks && !f.hasCandy;
      case 'seti': return f.clueDocks && !f.clueCloth;
      case 'kash': return f.clueCloth && !f.gateOpen && !!this.save.weapon;
      case 'hatra': return f.clueCloth && !this.save.weapon;
      case 'kem': return f.metNefer && !f.clueTwo;
    }
    return false;
  }

  openPanel(html, bind) {
    this.panelOpen = true;
    this.paused = true;
    this.input.x = this.input.y = 0;
    $('panelBody').innerHTML = html;
    $('panel').classList.remove('hidden');
    $('panelBody').querySelectorAll('.close').forEach(b => b.onclick = () => this.closePanel());
    bind?.($('panelBody'));
  }

  closePanel() {
    audio.sfx('ui');
    $('panel').classList.add('hidden');
    this.panelOpen = false;
    this.paused = !$('dialog').classList.contains('hidden');
    this.refreshHUD();
    this.persist();
  }

  // メニュー：装備・ヒント帳・設定
  openMenu(tab = 'equip') {
    if (!this.player || this.titleMode) return;
    audio.sfx('ui');
    const s = this.stats, save = this.save;
    const tabs = `<div class="tabs">${[['equip', '装備'], ['clues', 'ヒント帳'], ['settings', '設定']].map(([k, l]) => `<button data-tab="${k}" class="${k === tab ? 'on' : ''}">${l}</button>`).join('')}</div>`;
    let body = '';
    if (tab === 'equip') {
      const slot = (cap, id, key) => {
        const d = id && itemDef(id);
        return `<div class="slot ${d ? 'filled' : ''}" style="border-color:${d ? RARITY[d.rarity].color : ''}" data-slot="${key}"><div class="cap">${cap}</div>${d ? `<div class="icon">${this.icon(id)}</div><b>${d.name}</b>` : '<div class="icon">＋</div>なし'}</div>`;
      };
      const owned = Object.keys(save.inventory);
      const row = id => {
        const d = itemDef(id), eq = save.weapon === id || save.amulets.includes(id);
        const lv = save.inventory[id] - 1;
        const info = d.kind === 'weapon' ? `攻撃${d.atk}・速さ${d.speed}・リーチ${d.reach}m` : d.desc;
        return `<button class="item ${eq ? 'equipped' : ''}" data-item="${id}"><div class="icon">${this.icon(id)}</div><div class="t"><b>${d.name}${lv > 0 ? ` +${Math.min(5, lv)}` : ''}</b>${info}</div><div class="r" style="color:${RARITY[d.rarity].color}">${RARITY[d.rarity].label}${eq ? '<br>装備中' : ''}</div></button>`;
      };
      body = `<div class="slots">${slot('武器', save.weapon, 'weapon')}${slot('お守り1', save.amulets[0], 'a0')}${slot('お守り2', save.amulets[1], 'a1')}</div>
        <div class="stats"><div>攻撃<b>${s.atk}</b></div><div>HP<b>${s.maxHP}</b></div><div>会心<b>${Math.round(s.crit * 100)}%</b></div><div>リーチ<b>${s.reach}m</b></div></div>
        <div class="note" style="margin-bottom:8px">タップで装備／外す。同じものを重ねて手に入れると強化されます（最大+5）。</div>
        <div class="list">${owned.length ? owned.sort((a, b) => itemDef(b).rarity - itemDef(a).rarity).map(row).join('') : '<div class="note">まだ何も持っていません。ハトラの店か、神殿前の神託の壺へ。</div>'}</div>`;
    } else if (tab === 'clues') {
      body = save.clues.length ? save.clues.map(id => `<div class="clue"><b>${CLUES[id].title}</b>${CLUES[id].text}</div>`).join('') : '<div class="note">まだ手がかりはありません。</div>';
      body = `<div class="clue" style="border-color:#6fd39a"><b>いまやること</b>${objective(save)}</div>` + body;
    } else {
      body = `<button class="btn sub" id="bgmBtn">BGM・効果音：${save.bgm ? 'オン' : 'オフ'}</button>
        <div class="note" style="margin-top:14px">操作：左下のスティックで移動（倒す量で歩く／走る）。右側をなぞるとカメラを回せます。<br>敵が赤い輪を出したら攻撃の合図。「回避」でかわせます。</div>
        <div class="note" style="margin-top:14px">3Dモデル・アニメーション：Quaternius（CC0）／実写素材：Poly Haven（CC0）</div>
        <div class="clue" style="margin-top:16px;border-color:#ff8a5a"><b>テスト用（完成版では消します）</b>
          <button class="btn sub" id="warpNecro">墓地へワープ</button>
          <button class="btn sub" id="warpTown">町へ戻る</button>
          <button class="btn sub" id="warpGiza">ギザへワープ</button>
          <button class="btn sub" id="warpPyramid">ピラミッドの中へ</button>
          <button class="btn sub" id="addAnkh">+1000 アンク</button></div>`;
    }
    this.openPanel(`<div class="pHead"><h2>メニュー</h2><button class="close">✕</button></div>${tabs}${body}`, root => {
      root.querySelectorAll('[data-tab]').forEach(b => b.onclick = () => this.openMenu(b.dataset.tab));
      root.querySelectorAll('[data-item]').forEach(b => b.onclick = () => this.toggleEquip(b.dataset.item));
      root.querySelectorAll('[data-slot]').forEach(b => b.onclick = () => {
        const k = b.dataset.slot;
        if (k === 'weapon') save.weapon = null; else save.amulets[+k[1]] = null;
        this.equipVisual(); this.openMenu('equip');
      });
      const warp = async to => {
        this.closePanel();
        if (to !== 'town') {
          Object.assign(save.flags, { metNefer: true, clueDocks: true, clueCloth: true, gateOpen: true });
          if (!save.weapon) { this.addItem('travel_sword'); save.weapon = 'travel_sword'; }
        }
        this.paused = true;
        await this.enterZone(to, false, { necropolis: 'town', town: 'necropolis', giza: 'necropolis', pyramid: 'giza' }[to]);
        this.paused = false;
        this.refreshHUD();
      };
      root.querySelector('#warpNecro')?.addEventListener('click', () => warp('necropolis'));
      root.querySelector('#warpTown')?.addEventListener('click', () => warp('town'));
      root.querySelector('#warpGiza')?.addEventListener('click', () => warp('giza'));
      root.querySelector('#warpPyramid')?.addEventListener('click', () => warp('pyramid'));
      root.querySelector('#addAnkh')?.addEventListener('click', () => { this.gainAnkh(1000); this.openMenu('settings'); });
      const bgm = root.querySelector('#bgmBtn');
      if (bgm) bgm.onclick = () => { save.bgm = !save.bgm; audio.setMuted(!save.bgm); this.openMenu('settings'); };
    });
  }

  toggleEquip(id) {
    const d = itemDef(id), save = this.save;
    audio.sfx('ui');
    if (d.kind === 'weapon') save.weapon = save.weapon === id ? null : id;
    else {
      const i = save.amulets.indexOf(id);
      if (i >= 0) save.amulets[i] = null;
      else { const free = save.amulets.indexOf(null); save.amulets[free >= 0 ? free : 1] = id; }
    }
    this.equipVisual();
    this.player.hp = Math.min(this.player.hp, this.stats.maxHP);
    this.openMenu('equip');
  }

  // 武器屋
  openShop() {
    const stock = [['bronze_dagger', 60], ['travel_sword', 150], ['fisher_spear', 140], ['hand_axe', 180]];
    const html = `<div class="pHead"><h2>ハトラの武器屋</h2><button class="close">✕</button></div>
      <div class="note" style="margin-bottom:10px">所持：☥ ${this.save.ankh}</div>
      <div class="list">${stock.map(([id, price]) => {
        const d = itemDef(id), have = this.save.inventory[id];
        return `<button class="item" data-buy="${id}" data-price="${price}"><div class="icon">${this.icon(id)}</div><div class="t"><b>${d.name}</b>攻撃${d.atk}・速さ${d.speed}・リーチ${d.reach}m<br>${d.desc}</div><div class="r">☥${price}${have ? '<br>所持' : ''}</div></button>`;
      }).join('')}</div>`;
    this.openPanel(html, root => root.querySelectorAll('[data-buy]').forEach(b => b.onclick = () => {
      const id = b.dataset.buy, price = +b.dataset.price;
      if (this.save.ankh < price) { this.toast('アンクが足りない'); return; }
      this.save.ankh -= price;
      this.addItem(id);
      if (!this.save.weapon) { this.save.weapon = id; this.equipVisual(); }
      audio.sfx('coin');
      this.toast(`${itemDef(id).name}を買った`);
      this.openShop();
    }));
  }

  addItem(id) { this.save.inventory[id] = (this.save.inventory[id] || 0) + 1; }

  // 神託の壺（ガチャ）
  openGacha(results = null) {
    const save = this.save;
    const res = results ? `<div class="results ${results.length === 1 ? 'one' : ''}">${results.map((id, i) => {
      const d = itemDef(id);
      return `<div class="card r${d.rarity}" style="border-color:${RARITY[d.rarity].color};animation-delay:${i * 0.12}s"><div class="icon">${this.icon(id)}</div><div style="color:${RARITY[d.rarity].color};font-weight:900">${RARITY[d.rarity].label}</div>${d.name}</div>`;
    }).join('')}</div>` : '';
    const html = `<div class="pHead"><h2>${GACHA.name}</h2><button class="close">✕</button></div>
      <div class="gachaStage" id="stage"><div class="pot">🏺</div></div>
      ${res}
      <div class="note" style="margin:8px 0">所持：☥ ${save.ankh}　／　★5まであと ${GACHA.pity - (save.pityCount || 0)} 回（天井）</div>
      <button class="btn" id="g1" ${save.ankh < GACHA.cost1 ? 'disabled' : ''}>1回祈る（☥${GACHA.cost1}）</button>
      <button class="btn" id="g10" ${save.ankh < GACHA.cost10 ? 'disabled' : ''}>10回祈る（☥${GACHA.cost10}・★4以上1つ確定）</button>
      <button class="btn sub" id="rates">提供割合を見る</button>`;
    this.openPanel(html, root => {
      const go = async n => {
        const cost = n === 1 ? GACHA.cost1 : GACHA.cost10;
        if (save.ankh < cost) return;
        save.ankh -= cost;
        const got = n === 1 ? [pull(save)] : pull10(save);
        got.forEach(id => this.addItem(id));
        this.persist();
        root.querySelector('#stage').classList.add('shake');
        root.querySelectorAll('.btn').forEach(b => b.disabled = true);
        audio.sfx('pot');
        await wait(1000);
        if (got.some(id => itemDef(id).rarity >= 4)) audio.sfx('rare'); else audio.sfx('coin');
        this.openGacha(got);
      };
      root.querySelector('#g1').onclick = () => go(1);
      root.querySelector('#g10').onclick = () => go(10);
      root.querySelector('#rates').onclick = () => this.openRates();
    });
  }

  openRates() {
    const rows = gachaTable().map(r => `<tr><td style="color:${RARITY[r.rarity].color}">${RARITY[r.rarity].label}</td><td>${itemDef(r.id).name}</td><td style="text-align:right">${(r.rate * 100).toFixed(2)}%</td></tr>`).join('');
    this.openPanel(`<div class="pHead"><h2>提供割合</h2><button class="close">✕</button></div>
      <div class="note">★5：${GACHA.rates[5] * 100}%　★4：${GACHA.rates[4] * 100}%　★3：${GACHA.rates[3] * 100}%<br>${GACHA.pity}回引いて★5が出なかった場合、次は必ず★5になります。10回祈ると★4以上が1つ以上出ます。アンクはゲーム内で手に入る通貨で、現実のお金では買えません。</div>
      <table class="rates">${rows}</table><button class="btn sub" id="back">もどる</button>`, root => root.querySelector('#back').onclick = () => this.openGacha());
  }

  showClear() {
    this.openPanel(`<div class="pHead"><h2>第1章 クリア</h2><button class="close">✕</button></div>
      <div class="clue"><b>盗まれた太陽のスカラベ</b>秘宝は神殿に戻り、メンネフェルに祭りの灯がともった。</div>
      <div class="clue"><b>つづく…</b>盗賊団はなぜ「1つだけ」盗んだのか。対になる「月のスカラベ」の行方とは――。</div>
      <button class="btn close">町を歩く</button>`);
  }

  // ---------- 毎フレーム ----------
  resize() {
    const w = innerWidth, h = innerHeight;
    this.renderer.setSize(w, h, false);
    this.composer?.setSize(w, h);
    this.camera.aspect = w / h;
    this.camera.fov = w < h ? 62 : 50;
    this.camera.updateProjectionMatrix();
  }

  loop() {
    requestAnimationFrame(() => this.loop());
    this.tick(Math.min(0.05, this.clock.getDelta()), true);
  }

  /** テスト用：描画せずに時間だけ進める */
  simulate(seconds, step = 1 / 30) {
    for (let t = 0; t < seconds; t += step) this.tick(step, false);
  }

  tick(dt, render) {
    this.time += dt;
    if (!this.zone || !this.player) return;
    if (this.hitStop > 0) { this.hitStop -= dt; dt *= 0.08; }

    this.zone.update(dt, this.time, this.player);
    if (this.titleMode) {
      // タイトル：町をゆっくり見わたす
      const a = this.time * 0.06;
      this.camera.position.set(Math.sin(a) * 38, 16, Math.cos(a) * 38 - 10);
      this.camera.lookAt(0, 4, -12);
      for (const n of this.npcs) n.update(dt, this.player);
      this.player.actor.update(dt);
      this.updateLight();
      if (render) this.composer.render();
      return;
    }

    if (!this.paused) {
      const inp = this.underwater ? { ...this.input, x: this.input.x * 0.62, y: this.input.y * 0.62 } : this.input;
      this.player.update(dt, inp, this.camYaw + Math.PI, this.stats, this);
      this.enemies = this.enemies.filter(e => { const keep = e.update(dt, this.player, this); if (!keep) this.scene.remove(e.root); return keep; });
      // 敵どうしが重ならないように
      for (let i = 0; i < this.enemies.length; i++) for (let j = i + 1; j < this.enemies.length; j++) {
        const a = this.enemies[i].pos, b = this.enemies[j].pos, d = a.distanceTo(b), min = 1.0;
        if (d < min && d > 1e-4) { const push = (min - d) / 2 / d; const dx = (a.x - b.x) * push, dz = (a.z - b.z) * push; a.x += dx; a.z += dz; b.x -= dx; b.z -= dz; }
      }
      // 出口
      for (const ex of this.zone.exits) {
        if (Math.hypot(this.player.pos.x - ex.x, this.player.pos.z - ex.z) < ex.r && (!ex.requires || this.save.flags[ex.requires])) {
          this.paused = true;
          const escaped = this.escape && ex.to === 'giza';
          if (escaped) this.escape = null;
          this.enterZone(ex.to, false, this.zone.name).then(async () => {
            if (escaped) await this.escapeSucceeded();
            this.paused = false;
          });
          break;
        }
      }
    } else {
      this.player.actor.update(dt);
    }
    for (const n of this.npcs) n.update(dt, this.player);
    for (const f of this.finds || []) { f.fx.rotation.y += dt * 0.8; f.fx.material.opacity = 0.55 + Math.sin(this.time * 3 + f.def.x) * 0.35; }
    for (const k of this.pickups) { k.mesh.rotation.y += dt * 1.5; k.mesh.position.y = (k.baseY ?? 1) + Math.sin(this.time * 2) * 0.15; }
    this.updateEscape(dt); this.updateFalling(dt);
    this.telegraphs = this.telegraphs.filter(t => {
      t.left -= dt;
      const k = 1 - Math.max(0, t.left) / t.time;
      t.ring.position.set(t.enemy.pos.x, 0.05, t.enemy.pos.z);
      t.ring.scale.setScalar(1 + k * 4 * (t.enemy.def.scale || 1));
      t.ring.material.opacity = 0.9 - k * 0.3;
      if (t.left <= 0 || !t.enemy.alive) { this.scene.remove(t.ring); return false; }
      return true;
    });

    this.updateCamera(dt);
    this.updateLight();
    if (render) { this.updateHUD(); this.composer.render(); }
  }

  updateCamera(dt) {
    const p = this.player.pos;
    // 歩いている間は、ゆっくり主人公の後ろへ回り込む
    const moving = Math.hypot(this.input.x, this.input.y) > 0.3;
    if (moving && this.time - this.lastDrag > 1.2 && Math.abs(this.input.x) > 0.2) {
      let d = (this.player.face + Math.PI) - this.camYaw;
      d = Math.atan2(Math.sin(d), Math.cos(d));
      this.camYaw += d * Math.min(1, dt * 0.8);
    }
    const inside = this.inside > 0.5;
    const want = inside ? 5.2 : 6.8;
    this.camDist += (want - this.camDist) * Math.min(1, dt * 3);
    const target = new THREE.Vector3(p.x, 1.45, p.z);
    let dist = this.camDist;
    // 壁にさえぎられたら近づく
    const dirX = Math.sin(this.camYaw) * Math.cos(this.camPitch), dirZ = Math.cos(this.camYaw) * Math.cos(this.camPitch), dirY = Math.sin(this.camPitch);
    for (let t = 0.6; t < dist; t += 0.3) {
      const x = target.x + dirX * t, z = target.z + dirZ * t, y = target.y + dirY * t;
      if (y < 6 && this.zone.colliders.boxes.some(b => x > b.minX && x < b.maxX && z > b.minZ && z < b.maxZ)) { dist = Math.max(1.6, t - 0.4); break; }
      if (inside && y > 7.4) { dist = Math.max(1.6, t); break; }
    }
    // 見上げるとき：カメラは地面より下に行かず、低い位置から上を向く
    if (this.camPitch < 0) dist = Math.min(dist, Math.max(1.2, (target.y - 0.35) / Math.sin(-this.camPitch)));
    const want3 = new THREE.Vector3(target.x + dirX * dist, target.y + dirY * dist, target.z + dirZ * dist);
    if (!this.camPos) this.camPos = want3.clone();
    this.camPos.lerp(want3, Math.min(1, dt * 10));
    this.camera.position.copy(this.camPos);
    if (this.shake > 0) {
      this.shake -= dt;
      const s = this.shake * 0.4;
      this.camera.position.x += (Math.random() - 0.5) * s; this.camera.position.y += (Math.random() - 0.5) * s;
    }
    // 見上げるほど視線を上へ（巨像やピラミッドを下から見上げられる）
    const up = Math.max(0, -this.camPitch);
    this.camera.lookAt(target.x - dirX * up * 4, target.y + up * 9, target.z - dirZ * up * 4);
  }

  updateLight() {
    const p = this.player?.pos ?? new THREE.Vector3();
    if (this.zone?.baked) return this.updateBakedLight(p);
    this.sun.castShadow = true;
    const inside = this.zone?.isInside?.(p) ? 1 : 0;
    this.inside += (inside - this.inside) * 0.05;
    const k = this.inside;
    this.sun.position.set(p.x + 30, 45, p.z + 18);
    this.sun.target.position.set(p.x, 0, p.z);
    this.sun.intensity = 2.8 * (1 - k);
    this.hemi.intensity = 1.0 * (1 - k) + 0.35 * k;
    this.lantern.intensity = 18 * k;
    this.lantern.position.set(p.x, 2.4, p.z);
    this.renderer.toneMappingExposure = 1.05;
    this.scene.environment = null;
    audio.ambience(this.zone?.name === 'town' ? 'town' : k > 0.5 ? 'tomb' : 'desert');
    audio.surface = this.zone?.name === 'town' || k > 0.5 ? 'stone' : 'sand';
    if (k > 0.5) {
      if (this.scene.fog !== this.fogIn) { this.fogIn = this.fogIn || new THREE.Fog('#140c06', 4, 34); this.scene.fog = this.fogIn; this.scene.background = new THREE.Color('#0c0704'); }
      if (this.zone.name === 'necropolis' && !this.boss) audio.play('tomb');
    } else if (this.scene.fog !== this.fogOut) {
      this.scene.fog = this.fogOut; this.scene.background = this.sky;
      if (!this.titleMode && !this.boss) audio.play(this.zone.music);
    }
  }

  /** 光を計算済みの場所：屋外は明るく、墓や洞窟は暗く（場所に合わせてなめらかに切り替え） */
  updateBakedLight(p) {
    const z = this.zone, look = z.look(p), a = 0.06;
    const lerp = (x, y) => x + (y - x) * a;
    this.inside = lerp(this.inside, look.sky ? 0 : 1);
    if (!this.bakedFog) { this.bakedFog = new THREE.Fog(look.fog[0], look.fog[1], look.fog[2]); }
    if (this.scene.fog !== this.bakedFog) this.scene.fog = this.bakedFog;
    this.bakedFog.color.lerp(new THREE.Color(look.fog[0]), a);
    this.bakedFog.near = lerp(this.bakedFog.near, look.fog[1]);
    this.bakedFog.far = lerp(this.bakedFog.far, look.fog[2]);
    this.sun.castShadow = false;
    this.sun.position.set(p.x, 0, p.z).addScaledVector(z.sunDir, -40);
    this.sun.target.position.set(p.x, 0, p.z);
    this.sun.intensity = lerp(this.sun.intensity, look.sun);
    this.hemi.intensity = lerp(this.hemi.intensity, look.hemi);
    this.lantern.intensity = lerp(this.lantern.intensity, look.lantern);
    this.lantern.position.set(p.x, 2.6, p.z);
    this.renderer.toneMappingExposure = lerp(this.renderer.toneMappingExposure, look.exposure);
    if (z.sky) {
      this.scene.environment = z.sky;
      this.scene.environmentIntensity = lerp(this.scene.environmentIntensity ?? 1, look.env);
      this.scene.environmentRotation.y = z.skyRot;
      this.scene.backgroundRotation.y = z.skyRot;
    }
    if (look.bg && !this.bgCache?.[look.bg]) (this.bgCache ||= {})[look.bg] = new THREE.Color(look.bg);
    const wantBg = look.sky && z.sky ? z.sky : look.bg ? this.bgCache[look.bg] : this.darkBg || (this.darkBg = new THREE.Color('#050302'));
    if (this.scene.background !== wantBg) this.scene.background = wantBg;
    // 場所ごとの曲
    const region = z.region(p);
    if (!this.titleMode && !this.boss && region.name !== this.lastRegion) { this.lastRegion = region.name; audio.play(region.music); }
    // 環境音と足音の種類
    const amb = region.name === 'town' || this.zone.name === 'town' ? 'town' : region.kind === 'outdoor' ? 'desert' : region.kind === 'cave' ? 'cave' : region.kind === 'underwater' ? 'underwater' : 'tomb';
    audio.ambience(this.titleMode ? (this.zone.name === 'town' ? 'town' : 'desert') : amb);
    const inWater = (z.waters || []).some(w => p.x > w.x0 && p.x < w.x1 && p.z > w.z0 && p.z < w.z1);
    audio.surface = inWater ? 'water' : (region.kind === 'outdoor' && amb !== 'town') || amb === 'underwater' ? 'sand' : 'stone';
    this.underwater = amb === 'underwater';
  }

  updateHUD() {
    // HP
    const s = this.stats, hp = Math.ceil(this.player.hp);
    if (hp !== this.lastHP) { this.lastHP = hp; $('hpText').textContent = `${hp}/${s.maxHP}`; $('hpBar').style.width = (hp / s.maxHP * 100) + '%'; }
    if (this.boss) $('bossHp').style.width = (this.boss.hp / this.boss.maxHP * 100) + '%';
    // 話す・調べるボタン
    const t = this.paused ? null : this.nearest();
    const act = $('actBtn');
    if (t) { act.textContent = t.label; act.classList.remove('hidden'); } else act.classList.add('hidden');
    // 名前ラベル
    for (const n of this.npcs) {
      const v = n.root.position.clone().setY(2.15 * (n.def.scale || 1)).project(this.camera);
      const d = n.root.position.distanceTo(this.player.pos);
      const show = v.z < 1 && d < 22 && !this.paused;
      n.label.style.display = show ? 'block' : 'none';
      if (show) {
        n.label.style.left = ((v.x + 1) / 2 * innerWidth) + 'px';
        n.label.style.top = ((1 - v.y) / 2 * innerHeight) + 'px';
        const html = `${PEOPLE[n.id].name}${this.important(n.id) ? '<span class="mark">！</span>' : ''}`;
        if (n.label.innerHTML !== html) n.label.innerHTML = html;
        n.label.style.opacity = d < 12 ? 1 : 0.6;
      }
    }
  }
}

const wait = ms => new Promise(r => setTimeout(r, ms));

const game = new Game();
window.game = game;
game.boot().catch(e => { $('loadText').textContent = '読み込みに失敗しました：' + e.message; console.error(e); });

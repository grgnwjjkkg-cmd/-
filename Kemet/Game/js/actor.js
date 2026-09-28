// 3Dキャラの読み込みと、アニメーション（動きのなめらかな切り替え）
import * as THREE from 'three';
import { GLTFLoader } from '../lib/jsm/loaders/GLTFLoader.js';
import * as SkeletonUtils from '../lib/jsm/utils/SkeletonUtils.js';

const loader = new GLTFLoader();
const load = url => new Promise((res, rej) => loader.load(url, res, undefined, rej));

export class Assets {
  constructor(base = 'assets/') {
    this.base = base;
    this.chars = new Map();
    this.weapons = new Map();
    this.clips = new Map();
  }

  async init(onProgress = () => {}) {
    const anims = await load(this.base + 'anims.glb');
    for (const clip of anims.animations) {
      // 腰の位置の移動（ルートモーション）は消して、その場で動くようにする
      clip.tracks = clip.tracks.filter(t => !/^root\.position/.test(t.name));
      this.clips.set(clip.name, clip);
    }
    onProgress(0.2);
  }

  async preload(ids, weapons, onProgress = () => {}) {
    const all = [...ids.map(id => ['c', id]), ...weapons.map(w => ['w', w])];
    let done = 0;
    await Promise.all(all.map(async ([kind, id]) => {
      if (kind === 'c') await this.charTemplate(id); else await this.weaponTemplate(id);
      onProgress(0.2 + 0.8 * (++done / all.length));
    }));
  }

  async charTemplate(id) {
    if (!this.chars.has(id)) this.chars.set(id, load(`${this.base}chars/${id}.glb`).then(g => g.scene));
    return this.chars.get(id);
  }

  async weaponTemplate(name) {
    if (!this.weapons.has(name)) this.weapons.set(name, load(`${this.base}weapons/${name}.glb`).then(g => g.scene));
    return this.weapons.get(name);
  }

  /** キャラを複製（材質も複製して、ダメージの点滅を個別にできるように） */
  async makeChar(id) {
    const model = SkeletonUtils.clone(await this.charTemplate(id));
    model.traverse(o => {
      if (o.isMesh) {
        o.castShadow = true; o.receiveShadow = false;
        o.frustumCulled = false;
        o.material = o.material.clone();
      }
    });
    return model;
  }

  async makeWeapon(name, tint) {
    const w = (await this.weaponTemplate(name)).clone(true);
    w.traverse(o => {
      if (o.isMesh) {
        o.castShadow = true;
        o.material = [].concat(o.material).map(m => {
          const c = m.clone();
          // 刃（明るい色）だけに色をつける
          if (tint && c.color.getHSL({}).l > 0.55) c.color.set(tint);
          return c;
        });
        if (o.material.length === 1) o.material = o.material[0];
      }
    });
    return w;
  }
}

// 足もとのやわらかい影（計算済みの光の場所でも、キャラが地面に立って見えるように）
let blobTex = null;
function blobShadow() {
  if (!blobTex) {
    const c = document.createElement('canvas'); c.width = c.height = 64;
    const x = c.getContext('2d'), g = x.createRadialGradient(32, 32, 2, 32, 32, 30);
    g.addColorStop(0, 'rgba(0,0,0,0.55)'); g.addColorStop(1, 'rgba(0,0,0,0)');
    x.fillStyle = g; x.fillRect(0, 0, 64, 64);
    blobTex = new THREE.CanvasTexture(c);
  }
  const m = new THREE.Mesh(new THREE.PlaneGeometry(1.3, 1.3).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ map: blobTex, transparent: true, depthWrite: false }));
  m.position.y = 0.03; m.renderOrder = 1;
  return m;
}

/** アニメーションつきのキャラ1体 */
export class Actor {
  constructor(model, assets) {
    this.root = new THREE.Group();
    this.model = model;
    this.root.add(model);
    this.root.add(blobShadow());
    this.assets = assets;
    this.mixer = new THREE.AnimationMixer(model);
    this.actions = new Map();
    this.current = null;
    this.materials = [];
    model.traverse(o => { if (o.isMesh) this.materials.push(...[].concat(o.material)); });
    this.flashTime = 0;
    this.mixer.addEventListener('finished', e => {
      const cb = this.onceCallbacks?.get(e.action);
      if (cb) { this.onceCallbacks.delete(e.action); cb(); }
    });
    this.onceCallbacks = new Map();
  }

  action(name) {
    if (!this.actions.has(name)) {
      const clip = this.assets.clips.get(name);
      if (!clip) return null;
      this.actions.set(name, this.mixer.clipAction(clip));
    }
    return this.actions.get(name);
  }

  /** 動きを切り替える（fade 秒かけて前の動きから溶けるように） */
  play(name, { fade = 0.22, loop = true, speed = 1, restart = false, onDone } = {}) {
    const next = this.action(name);
    if (!next) return null;
    next.timeScale = speed;
    if (this.current === next && !restart) return next;
    next.enabled = true;
    next.setLoop(loop ? THREE.LoopRepeat : THREE.LoopOnce, loop ? Infinity : 1);
    next.clampWhenFinished = !loop;
    next.reset();
    next.setEffectiveWeight(1);
    if (this.current && this.current !== next) next.crossFadeFrom(this.current, fade, true);
    next.play();
    this.current = next;
    this.currentName = name;
    if (onDone) this.onceCallbacks.set(next, onDone);
    return next;
  }

  /** いまの動きが何割すすんだか（0〜1） */
  progress() {
    const a = this.current;
    return a ? a.time / a.getClip().duration : 0;
  }

  setSpeed(s) { if (this.current) this.current.timeScale = s; }

  /** 手に武器を持たせる */
  hold(weapon, length = 1) {
    if (this.weapon) this.weapon.removeFromParent();
    this.weapon = weapon;
    if (!weapon) return;
    let hand = null;
    this.model.traverse(o => { if (!hand && o.isBone && /^hand_r$/i.test(o.name)) hand = o; });
    if (!hand) return;
    // 骨の大きさの影響を打ち消して、実寸（m）で持たせる
    const holder = new THREE.Group();
    hand.add(holder);
    const ws = new THREE.Vector3(); hand.getWorldScale(ws);
    holder.scale.setScalar(1 / (ws.x || 1));
    holder.rotation.set(0, 0, -Math.PI / 2);
    holder.position.set(0.02, 0.03, 0);
    weapon.scale.setScalar(length);
    weapon.rotation.set(0, Math.PI / 2, 0);
    holder.add(weapon);
    this.weaponHolder = holder;
  }

  /** ダメージを受けた時の赤い点滅 */
  flash(color = '#ff3b3b', time = 0.15) {
    this.flashTime = time;
    this.flashColor = new THREE.Color(color);
  }

  update(dt) {
    this.mixer.update(dt);
    if (this.flashTime > 0) {
      this.flashTime -= dt;
      const k = Math.max(0, this.flashTime) > 0 ? 1 : 0;
      for (const m of this.materials) if (m.emissive) m.emissive.copy(this.flashColor).multiplyScalar(k * 0.8);
    }
  }
}

/** 角度を a から b へ、近い方向に t だけ近づける */
export function turnTowards(a, b, t) {
  let d = b - a;
  while (d > Math.PI) d -= Math.PI * 2;
  while (d < -Math.PI) d += Math.PI * 2;
  return a + d * Math.min(1, t);
}

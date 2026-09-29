// 3Dキャラの読み込みと、アニメーション（動きのなめらかな切り替え）
import * as THREE from 'three';
import { GLTFLoader } from '../lib/jsm/loaders/GLTFLoader.js';
import * as SkeletonUtils from '../lib/jsm/utils/SkeletonUtils.js';
import { mergeGeometries } from '../lib/jsm/utils/BufferGeometryUtils.js';
import { VRMLoaderPlugin, VRMUtils } from '../lib/three-vrm.module.js';
import { dressNefi } from './costume.js';

// VRM（アニメ風のキャラ）の骨の名前を、動きのデータ（UAL）の骨の名前にそろえる
const VRM_TO_UAL = { hips: 'pelvis', spine: 'spine_01', chest: 'spine_02', upperChest: 'spine_03', neck: 'neck_01', head: 'Head' };
for (const [s, t] of [['left', 'l'], ['right', 'r']]) {
  Object.assign(VRM_TO_UAL, { [s + 'Shoulder']: 'clavicle_' + t, [s + 'UpperArm']: 'upperarm_' + t, [s + 'LowerArm']: 'lowerarm_' + t, [s + 'Hand']: 'hand_' + t,
    [s + 'UpperLeg']: 'thigh_' + t, [s + 'LowerLeg']: 'calf_' + t, [s + 'Foot']: 'foot_' + t, [s + 'Toes']: 'ball_' + t,
    [s + 'ThumbMetacarpal']: 'thumb_01_' + t, [s + 'ThumbProximal']: 'thumb_02_' + t, [s + 'ThumbDistal']: 'thumb_03_' + t });
  for (const [f, u] of [['Index', 'index'], ['Middle', 'middle'], ['Ring', 'ring'], ['Little', 'pinky']])
    Object.assign(VRM_TO_UAL, { [s + f + 'Proximal']: `${u}_01_${t}`, [s + f + 'Intermediate']: `${u}_02_${t}`, [s + f + 'Distal']: `${u}_03_${t}` });
}
const vrmLoader = new GLTFLoader(); vrmLoader.register(p => new VRMLoaderPlugin(p));

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
    this.animRig = anims.scene;
    this.retargeted = new Map();
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
    if (!this.weapons.has(name)) this.weapons.set(name, load(`${this.base}weapons/${name}.glb`).then(g => mergeByMaterial(g.scene)));
    return this.weapons.get(name);
  }

  /** アニメ風の主人公（VRM）：骨の名前をそろえ、髪やスカートのゆれ（スプリングボーン）も動かす */
  async makeVRM(id) {
    const g = await new Promise((res, rej) => vrmLoader.load(`${this.base}chars/${id}.vrm`, res, undefined, rej));
    const vrm = g.userData.vrm;
    VRMUtils.rotateVRM0(vrm);
    vrm.humanoid.autoUpdateHumanBones = false;       // 動きは骨に直接あてる
    if (id === 'nefi') dressNefi(vrm);
    for (const [k, n] of Object.entries(VRM_TO_UAL)) { const b = vrm.humanoid.getRawBoneNode(k); if (b) b.name = n; }
    const model = vrm.scene;
    const tpl = SkeletonUtils.clone(model);   // 動きの乗せかえは、画面に置く前の姿勢で計算する
    model.userData.vrm = vrm;
    model.rotation.y += Math.PI;   // 動きを乗せると体が後ろ向きになるので、見た目だけ前へ向け直す
    model.userData.rig = { tpl, clips: new Map(), handFix: restFix(this.animRig, tpl, 'hand_r') };
    model.traverse(o => { if (o.isMesh) { o.castShadow = true; o.frustumCulled = false; for (const m of [].concat(o.material)) m.toneMapped = false; } });   // アニメの色をそのまま出す
    model.scale.setScalar(1.08);
    return model;
  }

  /** キャラを複製（材質も複製して、ダメージの点滅を個別にできるように） */
  async makeChar(id) {
    if (id.startsWith('vrm:')) return this.makeVRM(id.slice(4));
    const tpl = await this.charTemplate(id);
    const model = SkeletonUtils.clone(tpl);
    // 別の骨組みのリアルな人（MakeHuman）は、アニメをその骨に合わせて変換して使う
    let real = false; tpl.traverse(o => { if (o.userData?.realHuman) real = true; });
    if (real) {
      if (!this.retargeted.has(id)) this.retargeted.set(id, { tpl, clips: new Map(), handFix: restFix(this.animRig, tpl, 'hand_r') });
      model.userData.rig = this.retargeted.get(id);
    }
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

/** 武器は小さな部品が数十個に分かれていて描く回数が多い → 同じ材質どうしを1つにまとめる */
function mergeByMaterial(root) {
  root.updateMatrixWorld(true);
  const groups = new Map();
  root.traverse(o => {
    if (!o.isMesh || Array.isArray(o.material)) return;
    const m = o.material, key = m.name + '|' + (m.color?.getHexString() || '') + '|' + (m.map?.uuid || '');
    if (!groups.has(key)) groups.set(key, { mat: m, geos: [], meshes: [] });
    const gg = o.geometry.clone().applyMatrix4(o.matrixWorld);
    for (const k of Object.keys(gg.attributes)) if (!['position', 'normal', 'uv'].includes(k)) gg.deleteAttribute(k);
    if (!gg.index) gg.setIndex([...Array(gg.attributes.position.count).keys()]);
    groups.get(key).geos.push(gg); groups.get(key).meshes.push(o);
  });
  const out = new THREE.Group(); out.name = root.name;
  for (const { mat, geos, meshes } of groups.values()) {
    const same = geos.every(q => Object.keys(q.attributes).sort().join() === Object.keys(geos[0].attributes).sort().join());
    const merged = same ? mergeGeometries(geos, false) : null;
    if (merged) out.add(new THREE.Mesh(merged, mat));
    else for (const o of meshes) { const c = o.clone(); c.applyMatrix4(o.matrixWorld); out.add(c); }
  }
  return out;
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
      const rig = this.model.userData.rig;
      let clip = this.assets.clips.get(name);
      if (clip && rig) {
        if (!rig.clips.has(name)) rig.clips.set(name, retargetClip(clip, this.assets.animRig, rig.tpl));
        clip = rig.clips.get(name);
      }
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
    const fix = this.model.userData.rig?.handFix;
    if (fix) { holder.quaternion.premultiply(fix); holder.position.applyQuaternion(fix); }
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
    this.model.userData.vrm?.update(dt);   // 髪・スカートのゆれ、まばたき
    this.model.userData.vrm?.costumeUpdate?.(dt);   // ツインテールのゆれ
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

// ---------- アニメの乗せかえ（骨の向きがちがうキャラに、同じ動きをさせる） ----------
function restWorld(root) {
  root.updateMatrixWorld(true);
  const m = new Map();
  root.traverse(o => { if (o.name) m.set(o.name, { q: o.getWorldQuaternion(new THREE.Quaternion()), p: o.getWorldPosition(new THREE.Vector3()), o }); });
  return m;
}

/** 基本の姿勢で、src の骨の向きを dst の骨の向きへ直す回転 */
function restFix(src, dst, name) {
  const a = restWorld(src).get(name), b = restWorld(dst).get(name);
  if (!a || !b) return null;
  return b.q.clone().invert().multiply(a.q);
}

/** 基本の姿勢からの「世界での回転の差」を同じにして、動きを別の骨組みへ移す */
function retargetClip(clip, srcRoot, dstRoot) {
  const src = SkeletonUtils.clone(srcRoot), dst = dstRoot;
  const sRest = restWorld(src), dRest = restWorld(dst);
  const sLocal = new Map(); src.traverse(o => sLocal.set(o.name, { q: o.quaternion.clone(), p: o.position.clone() }));
  const byName = new Map(); src.traverse(o => byName.set(o.name, o));
  const bones = []; dst.traverse(o => { if (o.isBone) bones.push(o); });
  const tracks = clip.tracks.filter(t => /\.(quaternion|position)$/.test(t.name));
  const interp = tracks.map(t => {
    const [node, prop] = t.name.split('.');
    return { node: byName.get(node), prop, f: t.createInterpolant() };
  }).filter(x => x.node);
  const animated = new Set(interp.filter(x => x.prop === 'quaternion').map(x => x.node.name));
  let times = [];
  for (const t of tracks) if (t.times.length > times.length) times = Array.from(t.times);
  const hip = 'pelvis', ratio = dRest.get(hip) && sRest.get(hip) ? dRest.get(hip).p.y / sRest.get(hip).p.y : 1;
  const outQ = new Map(bones.map(b => [b.name, []])), outP = [];
  const wq = new Map(), tmp = new THREE.Quaternion(), wqS = new THREE.Quaternion(), wp = new THREE.Vector3();
  for (const t of times) {
    for (const [n, r] of sLocal) { const o = byName.get(n); o.quaternion.copy(r.q); o.position.copy(r.p); }
    for (const x of interp) {
      const v = x.f.evaluate(t);
      if (x.prop === 'quaternion') x.node.quaternion.fromArray(v);
      else if (x.node.name !== 'root') x.node.position.fromArray(v);
    }
    src.updateMatrixWorld(true);
    wq.clear();
    for (const b of bones) {
      const pq = b.parent?.isBone ? wq.get(b.parent.name) : dRest.get(b.parent?.name)?.q || new THREE.Quaternion();
      let w;
      const sb = byName.get(b.name);
      if (sb && animated.has(b.name) && sRest.get(b.name)) {
        sb.getWorldQuaternion(wqS);
        w = wqS.clone().multiply(sRest.get(b.name).q.clone().invert()).multiply(dRest.get(b.name).q);
      } else {
        w = pq.clone().multiply(b.quaternion);
      }
      wq.set(b.name, w);
      tmp.copy(pq).invert().multiply(w);
      outQ.get(b.name).push(tmp.x, tmp.y, tmp.z, tmp.w);
      if (b.name === hip && sb) {
        // 腰の上下の動き：身長の比でのばして、骨の親の向きで表す
        sb.getWorldPosition(wp).sub(sRest.get(hip).p).multiplyScalar(ratio).add(dRest.get(hip).p);
        const par = b.parent, pp = par.isBone ? null : dRest.get(par.name);
        const parentPos = par.isBone ? par.getWorldPosition(new THREE.Vector3()) : pp.p;
        const s = new THREE.Vector3(); par.getWorldScale(s);
        wp.sub(parentPos).applyQuaternion(pq.clone().invert()).divideScalar(s.x || 1);
        outP.push(wp.x, wp.y, wp.z);
      }
    }
  }
  const out = [];
  for (const b of bones) out.push(new THREE.QuaternionKeyframeTrack(`${b.name}.quaternion`, times, outQ.get(b.name)));
  if (outP.length) out.push(new THREE.VectorKeyframeTrack(`${hip}.position`, times, outP));
  return new THREE.AnimationClip(clip.name, clip.duration, out);
}

// Blender で光を計算（ベイク）した場所を読み込む。
// tools/bake/*.py が書き出した level.glb・lm_*.png・meta.json を使う。
import * as THREE from 'three';
import { GLTFLoader } from '../../lib/jsm/loaders/GLTFLoader.js';
import { RGBELoader } from '../../lib/jsm/loaders/RGBELoader.js';
import { Reflector } from '../../lib/jsm/objects/Reflector.js';
import { Colliders } from './builders.js';
import { addTownProps } from './zones.js';

const texLoader = new THREE.TextureLoader();
const texCache = new Map();
function tex(url, srgb = true) {
  if (!texCache.has(url)) {
    const t = texLoader.load(url);
    t.wrapS = t.wrapT = THREE.RepeatWrapping;
    t.anisotropy = 8;
    if (srgb) t.colorSpace = THREE.SRGBColorSpace;
    texCache.set(url, t);
  }
  return texCache.get(url);
}
/** 場所を出るときに、その場所の形と画像をGPUから消す（iPhoneのメモリ不足を防ぐ） */
export function disposeZone(zone) {
  if (!zone?.root) return;
  const texs = new Set();
  zone.root.traverse(o => {
    if (o.geometry) o.geometry.dispose();
    o.getRenderTarget?.()?.dispose();                       // 水面の映り込み
    for (const m of [].concat(o.material || [])) {
      for (const v of Object.values(m)) if (v?.isTexture) texs.add(v);
      for (const u of Object.values(m.uniforms || {})) if (u?.value?.isTexture) texs.add(u.value);
      m.dispose();
    }
  });
  for (const t of texs) {
    for (const [url, c] of texCache) if (c === t) texCache.delete(url);
    t.dispose();
  }
  zone.sky?.dispose?.();
}
const loadTex = url => new Promise((res, rej) => texLoader.load(url, t => res(t), undefined, rej));

// 場所の種類ごとの明るさ（キャラ用のリアルタイムの光）
const LOOKS = {
  outdoor: { sun: 2.2, hemi: 0.8, lantern: 0, torch: 0, exposure: 0.42, fog: ['#d8c6a4', 260, 2600], env: 0.8, sky: true },
  indoor: { sun: 0, hemi: 0.18, lantern: 6, torch: 14, exposure: 1.25, fog: ['#120c07', 8, 80], env: 0.15, sky: false },
  cave: { sun: 0, hemi: 0.14, lantern: 7, torch: 14, exposure: 1.3, fog: ['#0e0b08', 5, 50], env: 0.12, sky: false },
  heaven: { sun: 2.2, hemi: 1.0, lantern: 0, torch: 0, exposure: 0.48, fog: ['#c9dcf0', 150, 1400], env: 0.9, sky: false, open: true, bg: '#8fbde6' },
  // 火山：煙で赤くくすむ／氷山：白く冷たい／夜の東京：暗い青にネオン／宇宙：まっ黒な空に星
  ember: { sun: 1.8, hemi: 0.9, lantern: 2.5, torch: 0, exposure: 0.85, fog: ['#4a2216', 50, 650], env: 0.4, sky: false, open: true, bg: '#2a120c' },
  frost: { sun: 2.0, hemi: 1.0, lantern: 0, torch: 0, exposure: 0.4, fog: ['#c8d8e8', 60, 700], env: 0.9, sky: false, open: true, bg: '#b4cbe0' },
  night: { sun: 0.35, hemi: 0.35, lantern: 3.5, torch: 0, exposure: 1.1, fog: ['#0b1128', 60, 650], env: 0.2, sky: false, open: true, bg: '#060a1a' },
  space: { sun: 2.4, hemi: 0.3, lantern: 1.5, torch: 0, exposure: 0.55, fog: ['#02030a', 400, 4000], env: 0.25, sky: false, open: true, bg: '#010208' },
  underwater: { sun: 0.5, hemi: 0.4, lantern: 2, torch: 0, exposure: 1.15, fog: ['#0d4556', 1, 48], env: 0.25, sky: false, bg: '#0d4556' },
};

// 水の中：水面でゆれた光の模様（コースティクス）を、床や壁に重ねる
function addCaustics(m, uni) {
  m.onBeforeCompile = sh => {
    sh.uniforms.cTime = uni.cTime;
    sh.vertexShader = sh.vertexShader.replace('#include <common>', '#include <common>\nvarying vec3 vWPos;')
      .replace('#include <project_vertex>', '#include <project_vertex>\nvWPos = (modelMatrix * vec4(transformed, 1.0)).xyz;');
    sh.fragmentShader = sh.fragmentShader.replace('#include <common>', `#include <common>
varying vec3 vWPos; uniform float cTime;
float cst(vec2 p) {
  float c = 0.0;
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    vec2 q = p * (0.55 + fi * 0.37) + vec2(cTime * (0.3 + fi * 0.13), -cTime * (0.21 + fi * 0.07));
    c += abs(sin(q.x + sin(q.y * 1.3 + cTime * 0.5)) * sin(q.y + sin(q.x * 1.1 - cTime * 0.4)));
  }
  return pow(1.0 - c / 3.0, 5.0);
}`).replace('#include <fog_fragment>', `float up = clamp(1.0 - vWPos.y * 0.06, 0.2, 1.0);
gl_FragColor.rgb += gl_FragColor.rgb * cst(vWPos.xz * 0.9) * 2.2 * up;
#include <fog_fragment>`);
  };
}

export async function loadBakedZone(name, game) {
  const base = `assets/levels/${name}/`;
  const meta = await (await fetch(base + 'meta.json')).json();
  const [gltf, sky, ...lightmaps] = await Promise.all([
    new GLTFLoader().loadAsync(base + 'level.glb'),
    meta.sky ? new RGBELoader().loadAsync(`assets/hdri/${meta.sky.hdri}`) : Promise.resolve(null),
    ...Object.values(meta.groups).map(g => loadTex(base + g.lightmap)),
  ]);
  const lm = {};
  // スマホでは大きな光の画像を2048に縮める（光はなめらかなので見た目はほぼ同じ、メモリは1/4）
  const phone = /iPhone|iPad|Android/i.test(navigator.userAgent) || navigator.maxTouchPoints > 1;
  const shrink = t => {
    const img = t.image;
    if (!phone || !img || img.width <= 2048) return t;
    const c = document.createElement('canvas'); c.width = c.height = 2048;
    c.getContext('2d').drawImage(img, 0, 0, 2048, 2048);
    const n = new THREE.CanvasTexture(c); t.dispose(); return n;
  };
  Object.keys(meta.groups).forEach((g, i) => {
    const t = lightmaps[i] = shrink(lightmaps[i]);
    t.channel = 1; t.flipY = false; t.colorSpace = THREE.SRGBColorSpace;
    lm[g] = t;
  });

  const root = new THREE.Group();
  root.add(gltf.scene);
  // 材質：実写の模様 × 計算済みの光
  const matCache = new Map();
  gltf.scene.traverse(o => {
    if (!o.isMesh) return;
    const [group, matName] = o.name.split('__').map(s => s.replace(/[._]\d+$/, ''));
    // 遠景の地面が地下の部屋（墓・洞窟・山の中の神殿）に突き出ないよう、その下の頂点を沈める
    if (group === 'far' && meta.sink) {
      const a = o.geometry.attributes.position;
      for (let i = 0; i < a.count; i++) {
        const x = a.getX(i), z = a.getZ(i);
        for (const [x0, x1, z0, z1, y] of meta.sink) if (x >= x0 && x <= x1 && z >= z0 && z <= z1 && a.getY(i) > y) a.setY(i, y);
      }
      a.needsUpdate = true; o.geometry.computeBoundingSphere();
    }
    const g = meta.groups[group];
    const info = g?.materials?.[matName];
    const key = group + '/' + matName;
    if (!matCache.has(key)) {
      let m;
      if (!info) m = new THREE.MeshBasicMaterial({ color: '#777' });
      else if (info.emit) m = new THREE.MeshBasicMaterial({ color: new THREE.Color(...info.emit).multiplyScalar(4) });
      else m = new THREE.MeshBasicMaterial({
        map: tex(`assets/tex/${info.tex}_diff.jpg`),
        color: new THREE.Color(...info.tint),
        lightMap: lm[group],
        lightMapIntensity: g.k * Math.PI,
      });
      matCache.set(key, m);
    }
    o.material = matCache.get(key);
    o.matrixAutoUpdate = false; o.updateMatrix();
  });
  const underwater = meta.regions.some(r => r.kind === 'underwater');
  const cUni = { cTime: { value: 0 } };
  if (underwater) for (const m of matCache.values()) if (m.map) addCaustics(m, cUni);
  // 泡：足もとから立ちのぼる
  let bubbles = null;
  if (underwater) {
    const N = 260, pos = new Float32Array(N * 3), spd = new Float32Array(N);
    for (let i = 0; i < N; i++) { pos[i * 3] = (Math.random() - 0.5) * 30; pos[i * 3 + 1] = Math.random() * 14; pos[i * 3 + 2] = (Math.random() - 0.5) * 30; spd[i] = 0.6 + Math.random() * 1.2; }
    const geo = new THREE.BufferGeometry().setAttribute('position', new THREE.BufferAttribute(pos, 3));
    const bc = document.createElement('canvas'); bc.width = bc.height = 32;
    const bx = bc.getContext('2d'); bx.strokeStyle = 'rgba(220,245,255,0.9)'; bx.lineWidth = 3; bx.beginPath(); bx.arc(16, 16, 11, 0, Math.PI * 2); bx.stroke();
    bx.fillStyle = 'rgba(255,255,255,0.8)'; bx.beginPath(); bx.arc(12, 11, 3, 0, Math.PI * 2); bx.fill();
    bubbles = new THREE.Points(geo, new THREE.PointsMaterial({ map: new THREE.CanvasTexture(bc), size: 0.09, transparent: true, opacity: 0.75, depthWrite: false }));
    bubbles.userData.spd = spd; bubbles.frustumCulled = false;
    root.add(bubbles);
  }

  // 当たり判定
  const C = new Colliders();
  for (const [x0, x1, z0, z1, top] of meta.colliders.boxes) C.boxes.push({ minX: x0, maxX: x1, minZ: z0, maxZ: z1, top });
  for (const [x0, x1, z0, z1, top] of meta.platforms || []) C.platforms.push({ minX: x0, maxX: x1, minZ: z0, maxZ: z1, top });
  C.groundless = !!meta.groundless;
  for (const [x, z, r] of meta.colliders.circles) C.circles.push({ x, z, r });

  // 町：あとから置く物と、開け閉めする門
  let props = null, gateBlock = null;
  if (meta.gateBlock) {
    const [x0, x1, z0, z1] = meta.gateBlock;
    gateBlock = { minX: x0, maxX: x1, minZ: z0, maxZ: z1 };
    C.boxes.push(gateBlock);
  }
  if (name === 'town') props = addTownProps(root, C);

  // 水面
  const murks = [], mirrors = [];
  for (const w of meta.waters) {
    const sx = w.x1 - w.x0, sz = w.z1 - w.z0;
    const water = new Reflector(new THREE.PlaneGeometry(sx, sz), { textureWidth: 384, textureHeight: 384, color: '#8a8270', clipBias: 0.003 });
    water.rotation.x = -Math.PI / 2; water.position.set((w.x0 + w.x1) / 2, w.y, (w.z0 + w.z1) / 2);
    root.add(water);
    // 映りこみは場面をもう一度描くので重い → 近くにいるときだけ。遠くからは暗い水面で代わりに見せる
    const plain = new THREE.Mesh(new THREE.PlaneGeometry(sx, sz).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ color: '#23231c' }));
    plain.position.copy(water.position); root.add(plain);
    mirrors.push({ water, plain, w });
    const murk = new THREE.Mesh(new THREE.PlaneGeometry(sx, sz).rotateX(-Math.PI / 2), new THREE.ShaderMaterial({
      transparent: true, depthWrite: false, uniforms: { time: { value: 0 } },
      vertexShader: 'varying vec3 vW; void main(){ vec4 w = modelMatrix*vec4(position,1.); vW = w.xyz; gl_Position = projectionMatrix*viewMatrix*w; }',
      fragmentShader: 'uniform float time; varying vec3 vW; void main(){ float r = sin(vW.x*1.7+time*.8)*sin(vW.z*1.3-time*.6) + sin((vW.x-vW.z)*3.1+time*1.4)*.4; gl_FragColor = vec4(vec3(.08,.1,.07)+r*.02, .4 + r*.05); }',
    }));
    murk.position.set(water.position.x, w.y + 0.02, water.position.z);
    root.add(murk); murks.push(murk);
  }
  // 光の筋
  const beamMat = new THREE.MeshBasicMaterial({ color: '#ffe7b0', transparent: true, opacity: 0.07, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, fog: false });
  const sunDir = new THREE.Vector3(...(meta.sun?.dir || [0, -1, 0]));
  for (const [x, z, h] of meta.beams) {
    const beam = new THREE.Mesh(new THREE.CylinderGeometry(0.7, 1.3, h, 24, 1, true), beamMat);
    const top = new THREE.Vector3(x, h, z), dir = sunDir.clone().normalize();
    const mid = top.clone().addScaledVector(dir, h / 2 / Math.max(0.3, -dir.y));
    beam.position.copy(mid);
    beam.quaternion.setFromUnitVectors(new THREE.Vector3(0, -1, 0), dir);
    root.add(beam);
  }
  // たいまつの火
  const flameMat = new THREE.MeshBasicMaterial({ color: '#ffb347', transparent: true, blending: THREE.AdditiveBlending, depthWrite: false });
  const flames = meta.torches.map(([x, y, z], i) => {
    const f = new THREE.Mesh(new THREE.ConeGeometry(0.13, 0.45, 8), flameMat);
    f.position.set(x, y, z); root.add(f);
    const stick = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.07, 0.7, 6), new THREE.MeshBasicMaterial({ color: '#2a1a10' }));
    stick.position.set(x, y - 0.5, z); root.add(stick);
    return { f, phase: i * 1.7, pos: new THREE.Vector3(x, y, z) };
  });
  // ちり
  const dustPos = [];
  for (const r of meta.regions) if (!LOOKS[r.kind]?.sky && !LOOKS[r.kind]?.open) {
    const [x0, x1, z0, z1] = r.box;
    const n = Math.min(900, Math.round((x1 - x0) * (z1 - z0) * 0.8));
    for (let i = 0; i < n; i++) dustPos.push(x0 + Math.random() * (x1 - x0), Math.random() * 6, z0 + Math.random() * (z1 - z0));
  }
  const dust = new THREE.Points(new THREE.BufferGeometry().setAttribute('position', new THREE.Float32BufferAttribute(dustPos, 3)),
    new THREE.PointsMaterial({ color: '#fff0c8', size: 0.03, transparent: true, opacity: 0.45, depthWrite: false }));
  root.add(dust);

  // 天気：雪（氷山）・火の粉（火山）・星（宇宙・夜）
  const kind0 = meta.regions[0].kind;
  let weather = null;
  if (kind0 === 'frost' || kind0 === 'ember') {
    const N = kind0 === 'frost' ? 1400 : 500, pos = new Float32Array(N * 3), spd = new Float32Array(N);
    for (let i = 0; i < N; i++) { pos[i * 3] = (Math.random() - 0.5) * 60; pos[i * 3 + 1] = Math.random() * 24; pos[i * 3 + 2] = (Math.random() - 0.5) * 60; spd[i] = 0.5 + Math.random(); }
    const frost = kind0 === 'frost';
    weather = new THREE.Points(new THREE.BufferGeometry().setAttribute('position', new THREE.BufferAttribute(pos, 3)),
      new THREE.PointsMaterial({ color: frost ? '#ffffff' : '#ff9a3a', size: frost ? 0.09 : 0.07, transparent: true, opacity: frost ? 0.85 : 0.9, depthWrite: false, blending: frost ? THREE.NormalBlending : THREE.AdditiveBlending }));
    weather.userData = { spd, dir: frost ? -1.6 : 1.4 }; weather.frustumCulled = false;
    root.add(weather);
  }
  if (kind0 === 'space' || kind0 === 'night') {
    const N = kind0 === 'space' ? 3000 : 600, pos = [];
    for (let i = 0; i < N; i++) {
      const u = Math.random() * 2 - 1, a = Math.random() * Math.PI * 2, r = 2600;
      const y = kind0 === 'space' ? u : Math.abs(u) * 0.9 + 0.1;
      const q = Math.sqrt(1 - y * y);
      pos.push(Math.cos(a) * q * r, y * r, Math.sin(a) * q * r);
    }
    const stars = new THREE.Points(new THREE.BufferGeometry().setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)),
      new THREE.PointsMaterial({ color: '#ffffff', size: kind0 === 'space' ? 2.2 : 1.4, sizeAttenuation: false, transparent: true, opacity: kind0 === 'space' ? 0.95 : 0.5, fog: false, depthWrite: false }));
    stars.frustumCulled = false; stars.renderOrder = -1;
    root.add(stars);
  }
  if (kind0 === 'space') root.add(makeEarth());

  // 出入口のしるし：足もとから立ちのぼる淡い光
  const exitMat = new THREE.MeshBasicMaterial({ color: '#ffe2a8', transparent: true, opacity: 0.16, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide });
  const exitFx = (meta.exits || []).map(ex => {
    const m = new THREE.Mesh(new THREE.CylinderGeometry(ex.r * 0.7, ex.r * 0.8, 3.2, 28, 1, true), exitMat);
    m.position.set(ex.x, 1.6, ex.z); root.add(m); return m;
  });

  // 封印の扉（石板を3つ集めると床へ沈む）。表に3つの丸い印があり、見つけた数だけ金色に光る
  let seal = null;
  if (meta.seal) {
    const S = meta.seal, w = S.x1 - S.x0, d = S.z1 - S.z0;
    const cv = document.createElement('canvas'); cv.width = 256; cv.height = 352;
    const tx = new THREE.CanvasTexture(cv); tx.colorSpace = THREE.SRGBColorSpace;
    const draw = n => {
      const g = cv.getContext('2d');
      g.fillStyle = '#6a3b32'; g.fillRect(0, 0, 256, 352);
      for (let i = 0; i < 900; i++) { g.fillStyle = `rgba(${Math.random() < 0.5 ? '20,10,8' : '190,150,140'},${Math.random() * 0.25})`; g.fillRect(Math.random() * 256, Math.random() * 352, 2, 2); }
      g.strokeStyle = 'rgba(20,10,8,0.6)'; g.lineWidth = 4; g.strokeRect(10, 10, 236, 332);
      for (let i = 0; i < 3; i++) {
        const lit = i < n;
        g.beginPath(); g.arc(128, 80 + i * 96, 30, 0, Math.PI * 2);
        g.fillStyle = lit ? '#ffcf5a' : '#2a1510'; g.fill();
        g.lineWidth = 5; g.strokeStyle = lit ? '#fff0b0' : '#8a5a48'; g.stroke();
        if (lit) { g.shadowColor = '#ffb640'; g.shadowBlur = 24; g.fill(); g.shadowBlur = 0; }
      }
      tx.needsUpdate = true;
    };
    draw(0);
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, S.h, d), new THREE.MeshStandardMaterial({ map: tx, roughness: 0.75, emissive: '#ffffff', emissiveMap: tx, emissiveIntensity: 0.35 }));
    mesh.position.set((S.x0 + S.x1) / 2, S.h / 2, (S.z0 + S.z1) / 2); root.add(mesh);
    const block = { minX: S.x0, maxX: S.x1, minZ: S.z0 - 0.2, maxZ: S.z1 + 0.2 };
    C.boxes.push(block);
    seal = { mesh, draw, open: false, t: 0, h: S.h,
      setCount(n) { draw(Math.min(3, n)); },
      openNow(instant) {
        if (this.open) return; this.open = true;
        const i = C.boxes.indexOf(block); if (i >= 0) C.boxes.splice(i, 1);
        if (instant) this.mesh.visible = false;
      } };
  }

  // キャラを照らすたいまつの光（近い4つだけ動かして使う）
  const pool = Array.from({ length: 4 }, () => { const l = new THREE.PointLight('#ff9a4a', 0, 10, 1.6); root.add(l); return l; });

  if (sky) { sky.mapping = THREE.EquirectangularReflectionMapping; }
  const skyRot = -(meta.sky?.rotation || 0);

  const regionAt = p => meta.regions.find(r => p.x >= r.box[0] && p.x <= r.box[1] && p.z >= r.box[2] && p.z <= r.box[3]) || meta.regions[0];
  const toXZ = s => ({ x: s.x, z: s.z, face: s.face });

  return {
    name, baked: true, root, colliders: C,
    music: meta.regions[0].music,
    spawn: toXZ(meta.spawns.default),
    arrivals: Object.fromEntries(Object.entries(meta.spawns).map(([k, v]) => [k, toXZ(v)])),
    exits: meta.exits,
    enemySpawns: meta.enemies,
    chests: meta.chests,
    scarab: meta.scarab,
    sunDir,
    region: regionAt,
    isInside: p => { const l = LOOKS[regionAt(p).kind]; return !(l?.sky || l?.open); },
    look: p => LOOKS[regionAt(p).kind],
    pot: props?.pot,
    gate: props ? { object: props.gate } : null,
    openGate(instant) {
      props?.gate.userData.open(instant);
      const i = C.boxes.indexOf(gateBlock);
      if (i >= 0) C.boxes.splice(i, 1);
    },
    sky, skyRot,
    seal, relic: meta.relic, waters: meta.waters, exposureMul: meta.exposureMul || 1,
    swim: meta.swim || null, flight: !!meta.flight, gravity: meta.gravity || 1, hazards: meta.hazards || [], jets: meta.jets || [], slippery: meta.slippery || [],
    update(dt, t, player) {
      for (const m of murks) m.material.uniforms.time.value = t;
      if (player) for (const r of mirrors) {
        const dx = Math.max(r.w.x0 - player.pos.x, 0, player.pos.x - r.w.x1), dz = Math.max(r.w.z0 - player.pos.z, 0, player.pos.z - r.w.z1);
        const near = Math.hypot(dx, dz) < 26;
        r.water.visible = near; r.plain.visible = !near;
      }
      exitFx.forEach((m, i) => { m.material.opacity = 0.12 + Math.sin(t * 2 + i) * 0.05; });
      cUni.cTime.value = t;
      if (bubbles && player) {
        const a = bubbles.geometry.attributes.position, sp = bubbles.userData.spd, P = player.pos;
        for (let i = 0; i < sp.length; i++) {
          let y = a.getY(i) + sp[i] * dt, x = a.getX(i) + Math.sin(t * 2 + i) * dt * 0.15;
          if (y > 14 || Math.abs(x - P.x) > 16 || Math.abs(a.getZ(i) - P.z) > 16) { y = 0; x = P.x + (Math.random() - 0.5) * 30; a.setZ(i, P.z + (Math.random() - 0.5) * 30); }
          a.setX(i, x); a.setY(i, y);
        }
        a.needsUpdate = true;
      }
      if (weather && player) {
        const a = weather.geometry.attributes.position, sp = weather.userData.spd, P = player.pos, dir = weather.userData.dir;
        for (let i = 0; i < sp.length; i++) {
          let y = a.getY(i) + sp[i] * dir * dt, x = a.getX(i) + Math.sin(t * 0.8 + i) * dt * 0.4, z = a.getZ(i);
          if (y < P.y - 2 || y > P.y + 24 || Math.abs(x - P.x) > 30 || Math.abs(z - P.z) > 30) {
            x = P.x + (Math.random() - 0.5) * 60; z = P.z + (Math.random() - 0.5) * 60; y = dir < 0 ? P.y + 20 + Math.random() * 4 : P.y - 1 + Math.random() * 2;
          }
          a.setXYZ(i, x, y, z);
        }
        a.needsUpdate = true;
      }
      if (seal?.open && seal.mesh.visible) { seal.t += dt; seal.mesh.position.y = seal.h / 2 - seal.t * 1.4; if (seal.t * 1.4 > seal.h) seal.mesh.visible = false; }
      if (props) {
        props.water.userData.water.uniforms.time.value = t;
        props.gate.userData.update(dt);
        props.pot.glow.material.opacity = 0.25 + Math.sin(t * 2) * 0.1;
        props.pot.object.rotation.y = Math.sin(t * 0.5) * 0.05;
      }
      for (const fl of flames) { const k = 0.85 + Math.sin(t * 13 + fl.phase) * 0.1 + Math.sin(t * 7.3 + fl.phase) * 0.08; fl.f.scale.set(k, k * 1.15, k); }
      if (!player) return;
      const look = LOOKS[regionAt(player.pos).kind];
      const near = flames.map(f => [f, f.pos.distanceToSquared(player.pos)]).sort((a, b) => a[1] - b[1]).slice(0, pool.length);
      pool.forEach((l, i) => {
        const f = near[i]?.[0];
        if (!f) { l.intensity = 0; return; }
        l.position.copy(f.pos);
        l.intensity = look.torch * (0.9 + Math.sin(t * 11 + f.phase) * 0.1);
      });
    },
  };
}

/** 宇宙から見た地球（海・大陸・雲を絵でかく。ファイルを増やさない） */
function makeEarth() {
  const W = 1024, H = 512, cv = document.createElement('canvas'); cv.width = W; cv.height = H;
  const g = cv.getContext('2d'), img = g.createImageData(W, H), d = img.data;
  const hash = (x, y) => { const h = Math.sin(x * 127.1 + y * 311.7) * 43758.5453; return h - Math.floor(h); };
  const noise = (x, y) => {
    const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi, u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
    const a = hash(xi, yi), b = hash(xi + 1, yi), c = hash(xi, yi + 1), e = hash(xi + 1, yi + 1);
    return a + (b - a) * u + (c - a) * v + (a - b - c + e) * u * v;
  };
  const fbm = (x, y) => { let s = 0, k = 0.5; for (let i = 0; i < 5; i++) { s += noise(x, y) * k; x *= 2.03; y *= 2.03; k *= 0.5; } return s; };
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const lat = Math.abs(y / H - 0.5) * 2, i = (y * W + x) * 4;
    const land = fbm(x / 110, y / 110) - 0.02 * lat, cloud = fbm(x / 40 + 50, y / 70);
    let r, gg, b;
    if (lat > 0.86) { r = gg = b = 235; }
    else if (land > 0.52) { const k = fbm(x / 30, y / 30); r = 70 + k * 90 + lat * 40; gg = 95 + k * 60; b = 45 + k * 30; if (lat < 0.35 && k > 0.55) { r += 70; gg += 40; b += 10; } }
    else { const deep = Math.min(1, (0.52 - land) * 4); r = 12 + 10 * (1 - deep); gg = 45 + 40 * (1 - deep); b = 110 + 40 * (1 - deep); }
    const c = Math.max(0, cloud - 0.5) * 2.4;
    d[i] = r + (255 - r) * Math.min(1, c); d[i + 1] = gg + (255 - gg) * Math.min(1, c); d[i + 2] = b + (255 - b) * Math.min(1, c); d[i + 3] = 255;
  }
  g.putImageData(img, 0, 0);
  const tx = new THREE.CanvasTexture(cv); tx.colorSpace = THREE.SRGBColorSpace;
  const grp = new THREE.Group();
  const earth = new THREE.Mesh(new THREE.SphereGeometry(900, 64, 32), new THREE.MeshBasicMaterial({ map: tx, fog: false, color: '#b8c4d0' }));
  earth.rotation.set(0.35, 1.2, 0.2); grp.add(earth);
  // 大気のふち（青く光る輪）
  const atm = new THREE.Mesh(new THREE.SphereGeometry(940, 64, 32), new THREE.ShaderMaterial({
    fog: false, transparent: true, depthWrite: false, side: THREE.BackSide, blending: THREE.AdditiveBlending,
    vertexShader: 'varying vec3 vN; varying vec3 vV; void main(){ vec4 mv = modelViewMatrix * vec4(position,1.0); vN = normalize(normalMatrix * normal); vV = normalize(-mv.xyz); gl_Position = projectionMatrix * mv; }',
    fragmentShader: 'varying vec3 vN; varying vec3 vV; void main(){ float k = pow(1.0 - abs(dot(vN, vV)), 3.0); gl_FragColor = vec4(0.35, 0.65, 1.0, 1.0) * k * 1.6; }',
  }));
  grp.add(atm);
  grp.position.set(600, -700, -1500);
  grp.userData.spin = earth;
  return grp;
}

export { LOOKS };

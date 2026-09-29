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
  heaven: { sun: 2.2, hemi: 1.0, lantern: 0, torch: 0, exposure: 0.48, fog: ['#c9dcf0', 150, 1400], env: 0.9, sky: false, bg: '#8fbde6' },
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
  Object.keys(meta.groups).forEach((g, i) => {
    const t = lightmaps[i];
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
  const murks = [];
  for (const w of meta.waters) {
    const sx = w.x1 - w.x0, sz = w.z1 - w.z0;
    const water = new Reflector(new THREE.PlaneGeometry(sx, sz), { textureWidth: 512, textureHeight: 512, color: '#8a8270', clipBias: 0.003 });
    water.rotation.x = -Math.PI / 2; water.position.set((w.x0 + w.x1) / 2, w.y, (w.z0 + w.z1) / 2);
    root.add(water);
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
  for (const r of meta.regions) if (r.kind !== 'outdoor') {
    const [x0, x1, z0, z1] = r.box;
    const n = Math.min(900, Math.round((x1 - x0) * (z1 - z0) * 0.8));
    for (let i = 0; i < n; i++) dustPos.push(x0 + Math.random() * (x1 - x0), Math.random() * 6, z0 + Math.random() * (z1 - z0));
  }
  const dust = new THREE.Points(new THREE.BufferGeometry().setAttribute('position', new THREE.Float32BufferAttribute(dustPos, 3)),
    new THREE.PointsMaterial({ color: '#fff0c8', size: 0.03, transparent: true, opacity: 0.45, depthWrite: false }));
  root.add(dust);

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
    isInside: p => regionAt(p).kind !== 'outdoor',
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
    swim: meta.swim || null, flight: !!meta.flight, gravity: meta.gravity || 1, hazards: meta.hazards || [],
    update(dt, t, player) {
      for (const m of murks) m.material.uniforms.time.value = t;
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

export { LOOKS };

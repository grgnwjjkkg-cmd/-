// 2つの場所：町「メンネフェル」と「西岸の墓地」
import * as THREE from 'three';
import * as B from './builders.js';
import * as T from './textures.js';

function ground(size, material, y = 0) {
  const g = new THREE.PlaneGeometry(size, size, 1, 1);
  g.rotateX(-Math.PI / 2);
  const uv = g.attributes.uv;
  for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * size / 8, uv.getY(i) * size / 8);
  const m = new THREE.Mesh(g, material);
  m.position.y = y; m.receiveShadow = true;
  return m;
}

/** 町の外に広がる砂丘（中心は平ら） */
function dunes(radius, flat, seed = 1) {
  const g = new THREE.PlaneGeometry(radius * 2, radius * 2, 120, 120);
  g.rotateX(-Math.PI / 2);
  const p = g.attributes.position;
  for (let i = 0; i < p.count; i++) {
    const x = p.getX(i), z = p.getZ(i), d = Math.hypot(x, z);
    const k = THREE.MathUtils.smoothstep(d, flat, flat + 40);
    const h = (Math.sin(x * 0.035 + seed) * 3 + Math.sin(z * 0.05 + x * 0.02) * 2.2 + Math.sin(x * 0.11 - z * 0.07) * 0.7 + 3) * k;
    p.setY(i, h - 0.02);
  }
  g.computeVertexNormals();
  const uv = g.attributes.uv;
  for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * radius / 5, uv.getY(i) * radius / 5);
  const m = new THREE.Mesh(g, new THREE.MeshStandardMaterial({ map: T.sand(), color: '#ffffff', roughness: 1 }));
  m.receiveShadow = true;
  return m;
}

/** ナイル川（ゆらぐ水面） */
function river(x1, x2, z1, z2) {
  const w = x2 - x1, d = z2 - z1;
  const g = new THREE.PlaneGeometry(w, d, 1, 1); g.rotateX(-Math.PI / 2);
  const m = new THREE.ShaderMaterial({
    uniforms: { time: { value: 0 }, fogColor: { value: new THREE.Color('#f0d7a6') } },
    vertexShader: `varying vec3 vW; void main(){ vec4 w = modelMatrix * vec4(position,1.0); vW = w.xyz; gl_Position = projectionMatrix * viewMatrix * w; }`,
    fragmentShader: `uniform float time; varying vec3 vW;
      void main(){
        float a = sin(vW.x*0.35 + time*1.1) * sin(vW.z*0.28 - time*0.8);
        float b = sin((vW.x+vW.z)*0.9 - time*2.0) * 0.5;
        float wave = a*0.5 + b*0.25;
        vec3 deep = vec3(0.13,0.36,0.46), light = vec3(0.35,0.62,0.66);
        vec3 c = mix(deep, light, 0.5 + wave*0.5);
        float spark = smoothstep(0.62, 0.7, a*0.5+b*0.5+0.4);
        c += vec3(1.0,0.95,0.8) * spark * 0.35;
        gl_FragColor = vec4(c, 0.92);
      }`,
    transparent: true,
  });
  const mesh = new THREE.Mesh(g, m);
  mesh.position.set((x1 + x2) / 2, 0.05, (z1 + z2) / 2);
  mesh.userData.water = m;
  return mesh;
}

/** 門の扉（開け閉めできる） */
function gateDoors(x, z) {
  const group = new THREE.Group();
  group.position.set(x, 0, z);
  const doors = [];
  for (const s of [-1, 1]) {
    const pivot = new THREE.Group();
    pivot.position.set(0, 0, s * 2.2);
    const door = new THREE.Mesh(new THREE.BoxGeometry(0.25, 4.2, 2.2), B.M.wood());
    door.position.set(0, 2.1, -s * 1.1);
    door.castShadow = true;
    const band = new THREE.Mesh(new THREE.BoxGeometry(0.3, 0.2, 2.2), B.M.gold());
    band.position.set(0, 3.2, -s * 1.1);
    pivot.add(door, band);
    group.add(pivot);
    doors.push({ pivot, side: s });
  }
  group.userData.open = (instant = false) => {
    for (const d of doors) d.target = -d.side * 1.6;
    if (instant) for (const d of doors) d.pivot.rotation.y = d.target;
  };
  group.userData.update = dt => {
    for (const d of doors) if (d.target !== undefined) d.pivot.rotation.y += (d.target - d.pivot.rotation.y) * Math.min(1, dt * 2);
  };
  return group;
}

// ------------------------------------------------------------
// 町：メンネフェル
// 北：神殿、中央：市場と井戸、東：ナイルと船着き場、西：城壁と西門
// ------------------------------------------------------------
export function buildTown() {
  const root = new THREE.Group();
  const batch = new B.Batcher(), C = new B.Colliders();

  root.add(dunes(420, 75, 2));
  const plaza = ground(40, B.M.paving(), 0.02);
  root.add(plaza);
  const street = new THREE.Mesh(new THREE.PlaneGeometry(8, 90).rotateX(-Math.PI / 2), B.M.paving());
  street.position.set(0, 0.015, -5); street.receiveShadow = true; root.add(street);

  // 町を囲む城壁（東はナイルなので開いている）
  B.wall(batch, C, -50, -75, -50, -3.4, 6);
  B.wall(batch, C, -50, 3.4, -50, 55, 6);
  B.wall(batch, C, -50, 55, 36, 55, 6);
  B.wall(batch, C, -50, -75, 36, -75, 6);
  C.box(-48, 0, 1, 7); // 門（閉じている間）
  const gateBlock = C.boxes[C.boxes.length - 1];
  // 門の両わきの塔
  for (const s of [-1, 1]) {
    batch.box(4, 8, 4, B.M.hieroPlain(), [-50, 4, s * 5.4]);
    C.box(-50, s * 5.4, 4, 4);
  }
  const gate = gateDoors(-50, 0);
  root.add(gate);

  // 神殿（北）：塔門、オベリスク、列柱の中庭
  B.pylon(batch, C, 0, -38, 28, 14);
  B.obelisk(batch, C, -9, -31, 13);
  B.obelisk(batch, C, 9, -31, 13);
  for (const z of [-46, -52, -58, -64]) for (const x of [-7, 7]) B.column(batch, C, x, z, 8, 0.7);
  const court = ground(26, B.M.paving(), 0.03); court.position.z = -56; root.add(court);
  // 中庭の囲い
  B.wall(batch, C, -13, -41, -13, -70, 7, 1.2, B.M.hieroPlain());
  B.wall(batch, C, 13, -41, 13, -70, 7, 1.2, B.M.hieroPlain());
  B.wall(batch, C, -13, -70, 13, -70, 7, 1.2, B.M.hiero());
  // 祭壇（スカラベが置かれていた台）
  batch.box(3, 1.2, 2, B.M.sandstoneDark(), [0, 0.6, -66]);
  batch.box(3.2, 0.2, 2.2, B.M.gold(), [0, 1.3, -66]);
  C.box(0, -66, 3, 2);

  // 市場（中央）：井戸と屋台
  B.well(batch, C, 0, 0);
  B.stall(batch, C, -12, -9, Math.PI / 2, ['#b8432f', '#f1e3c4']);   // ハトラの武器屋
  B.stall(batch, C, 13, 5, -Math.PI / 2, ['#2f6fb8', '#f1e3c4']);    // タウィの菓子屋
  B.stall(batch, C, 13, -6, -Math.PI / 2, ['#2f8a6a', '#f4d27a']);
  B.stall(batch, C, -12, 7, Math.PI / 2, ['#d9a13a', '#7a3a8a']);
  for (const [x, z] of [[-14, -12], [-14.5, -11], [15, 8], [15.4, 9], [-15, 10], [16, -9]]) B.jar(batch, C, x, z, 0.9);

  // 家並み
  const houses = [
    [-26, 32, 8, 7, 4, 0, { upper: true }], [-26, 18, 7, 6, 3.6, 0], [-28, 4, 9, 8, 4.2, Math.PI / 2, { awning: ['#b8432f', '#f1e3c4'] }],
    [-26, -12, 8, 7, 4, 0, { upper: true, mat: B.M.mudWhite() }], [-34, -30, 10, 8, 4.5, 0], [-38, 20, 7, 7, 3.8, 0, { mat: B.M.mudRose() }],
    [26, 32, 8, 7, 4, 0, { mat: B.M.mudWhite() }], [24, 18, 7, 6, 3.6, 0, { upper: true }], [26, -18, 8, 8, 4.2, Math.PI, { awning: ['#2f6fb8', '#f1e3c4'] }],
    [27, -32, 9, 7, 4, Math.PI, { mat: B.M.mudRose() }], [-12, 38, 7, 6, 3.6, Math.PI, { upper: true }], [12, 40, 7, 7, 3.8, Math.PI],
    [-40, -52, 12, 10, 5, 0, { upper: true }], [-26, -60, 8, 8, 4, 0, { mat: B.M.mudWhite() }], [28, -52, 10, 8, 4.2, 0, { upper: true, mat: B.M.mudRose() }],
    [-38, 42, 9, 8, 4, 0], [-18, 48, 8, 5, 3.6, Math.PI],
  ];
  for (const h of houses) B.house(batch, C, ...h);
  // 学者の家（書庫）
  B.house(batch, C, -26, -22, 7, 6, 4.4, Math.PI / 2, { mat: B.M.hieroPlain() });

  // ヤシの木
  const palms = [[-6, 20, 7], [6, 22, 6.5], [-18, -2, 7.5], [18, 12, 6.8], [33, 10, 8], [34, -12, 7.2], [36, 26, 7], [-40, 6, 6.5], [-44, -20, 7], [20, -40, 8], [-20, -42, 7.4], [33, -44, 6.6], [3, 46, 7], [-32, 50, 6]];
  palms.forEach(([x, z, h], i) => B.palm(batch, C, x, z, h, 0.15 + (i % 3) * 0.08, i * 1.3));

  // 神託の壺（ガチャ）：神殿の前
  const pot = new THREE.Group();
  const potGeo = new THREE.LatheGeometry([[0, 0], [0.6, 0.05], [1.05, 0.6], [1.1, 1.2], [0.8, 1.9], [0.45, 2.1], [0.55, 2.3]].map(([a, b]) => new THREE.Vector2(a, b)), 24);
  const potMesh = new THREE.Mesh(potGeo, new THREE.MeshStandardMaterial({ color: '#2a5fa8', roughness: 0.35, metalness: 0.2 }));
  potMesh.castShadow = true;
  const band = new THREE.Mesh(new THREE.TorusGeometry(1.08, 0.08, 8, 32), B.M.gold()); band.rotation.x = Math.PI / 2; band.position.y = 1.2;
  const glowMat = new THREE.MeshBasicMaterial({ color: '#ffd76a', transparent: true, opacity: 0.35, depthWrite: false, blending: THREE.AdditiveBlending });
  const glow = new THREE.Mesh(new THREE.CylinderGeometry(0.45, 0.2, 5, 16, 1, true), glowMat); glow.position.y = 4.4;
  pot.add(potMesh, band, glow);
  pot.position.set(6, 0, -27);
  batch.box(3, 0.4, 3, B.M.sandstoneDark(), [6, 0.2, -27]);
  pot.position.y = 0.4;
  C.circle(6, -27, 1.4);
  root.add(pot);

  // 船着き場とナイル（東）
  const water = river(44, 140, -120, 120);
  root.add(water);
  // 漁師が座る木箱
  batch.box(0.9, 0.5, 0.9, B.M.wood(), [41, 0.25, 1.35]);
  batch.box(8, 0.35, 5, B.M.wood(), [42, 0.2, 1], 0, 2);
  for (const [x, z] of [[38.5, -1.2], [38.5, 3.2], [45.5, -1.2], [45.5, 3.2]]) batch.add(new THREE.CylinderGeometry(0.15, 0.15, 1.6, 6), B.M.wood(), B.trs([x, 0.3, z]));
  B.boat(batch, 49, 6, 0);
  B.boat(batch, 50, -6, 0.3);
  // 川に入れないように
  C.box(47.5, -60, 7, 120); C.box(47.5, 62, 7, 116);
  C.box(46.5, 1, 1, 5);

  // 遠くのピラミッド（西の砂漠）
  B.pyramid(batch, -230, -60, 120);
  B.pyramid(batch, -300, 60, 150, 0.2);
  B.pyramid(batch, -190, 120, 70, 0.4);

  // 町の外に出られないように
  C.box(0, 60, 120, 6); C.box(0, -80, 120, 6); C.box(-56, 0, 6, 200);

  batch.build(root);

  return {
    name: 'town', music: 'town', root, colliders: C,
    spawn: { x: 0, z: 30, face: Math.PI },
    arrivals: { necropolis: { x: -44, z: 0, face: Math.PI / 2 } },
    pot: { x: 6, z: -27, object: pot, glow },
    gate: { object: gate, block: gateBlock, x: -50, z: 0 },
    exits: [{ x: -53, z: 0, r: 3, to: 'necropolis', requires: 'gateOpen' }],
    update(dt, t) {
      water.userData.water.uniforms.time.value = t;
      gate.userData.update(dt);
      glow.material.opacity = 0.25 + Math.sin(t * 2) * 0.1;
      pot.rotation.y = Math.sin(t * 0.5) * 0.05;
    },
    openGate(instant) {
      gate.userData.open(instant);
      C.boxes.splice(C.boxes.indexOf(gateBlock), 1);
    },
  };
}

// ------------------------------------------------------------
// 西岸の墓地：砂漠の道 → 墓の入口 → 通路 → 盗賊団の間
// ------------------------------------------------------------
export function buildNecropolis() {
  const root = new THREE.Group();
  const batch = new B.Batcher(), C = new B.Colliders();

  root.add(dunes(420, 30, 7));
  B.pyramid(batch, -60, -170, 110);
  B.pyramid(batch, 90, -210, 150, 0.3);
  B.pyramid(batch, -170, -60, 80, 0.5);

  // 砂漠の道：両側に崩れた柱と岩
  for (let z = 30; z > -24; z -= 9) {
    for (const s of [-1, 1]) {
      const h = 3 + ((z * 7) % 5 + 5) % 5;
      B.column(batch, C, s * 7, z, h, 0.55, false);
    }
  }
  for (const [x, z, s] of [[-14, 10, 2.5], [15, -6, 3], [-18, -15, 2], [18, 20, 2.2], [-9, 36, 1.5]]) {
    batch.add(new THREE.DodecahedronGeometry(s, 0), B.M.sandstoneDark(), B.trs([x, s * 0.5, z], x, [1, 0.7, 1]));
    C.circle(x, z, s * 0.9);
  }

  // 墓の入口（崖に掘られた門）
  batch.box(60, 16, 10, B.M.sandstoneDark(), [0, 8, -34], 0, 6);
  C.box(-17, -34, 26, 10); C.box(17, -34, 26, 10);
  batch.box(8, 9, 1, B.M.hiero(), [0, 4.5, -28.8]);
  for (const s of [-1, 1]) { batch.box(1.4, 8, 1.4, B.M.hieroPlain(), [s * 4.6, 4, -28.6]); C.box(s * 4.6, -28.6, 1.4, 1.4); }
  batch.box(11, 1.4, 2, B.M.gold(), [0, 8.4, -29]);

  // 墓の中：暗い通路（天井つき）。z = -34 から -120
  const corridor = (x1, x2, z1, z2) => {
    const w = x2 - x1, d = z1 - z2, cx = (x1 + x2) / 2, cz = (z1 + z2) / 2;
    batch.box(w, 0.3, d, B.M.sandstoneDark(), [cx, 6.15, cz], 0, 4);
  };
  const tombWall = (x1, z1, x2, z2) => B.wall(batch, C, x1, z1, x2, z2, 6, 1.2, B.M.hiero());
  // 1本目の通路
  tombWall(-3.5, -39, -3.5, -70); tombWall(3.5, -39, 3.5, -62);
  corridor(-4, 4, -39, -70);
  // 右に折れて広間へ
  tombWall(3.5, -62, 24, -62); tombWall(-3.5, -70, 10, -70);
  corridor(4, 24, -62, -70);
  // 広間（ミイラの間）
  tombWall(24, -62, 24, -50); tombWall(10, -70, 10, -96); tombWall(24, -50, 40, -50); tombWall(40, -50, 40, -96);
  corridor(10, 40, -50, -96);
  for (const [x, z, r] of [[16, -58, 0], [34, -58, 0], [16, -88, 0], [34, -88, 0]]) B.sarcophagus(batch, C, x, z, r);
  for (const x of [18, 32]) for (const z of [-66, -80]) B.column(batch, C, x, z, 6, 0.6);
  // 奥の間（盗賊団の頭）へ
  tombWall(10, -96, 22, -96); tombWall(28, -96, 40, -96);
  tombWall(22, -96, 22, -104); tombWall(28, -96, 28, -104);
  corridor(22, 28, -96, -104);
  tombWall(8, -104, 22, -104); tombWall(28, -104, 42, -104);
  tombWall(8, -104, 8, -126); tombWall(42, -104, 42, -126); tombWall(8, -126, 42, -126);
  corridor(8, 42, -104, -126);
  // 盗んだ宝の山
  for (let i = 0; i < 14; i++) B.jar(batch, null, 12 + (i % 7) * 2.4, -122 + Math.floor(i / 7) * 1.6, 0.8 + (i % 3) * 0.2, i % 3 ? B.M.clay() : B.M.gold());
  C.box(20, -121.5, 18, 4);

  // 墓の床（暗めの石）
  const floor = ground(60, new THREE.MeshStandardMaterial({ map: T.paving(), color: '#8a7a66', roughness: 1 }), 0.03);
  floor.position.set(22, 0.03, -82); root.add(floor);

  // 外の端
  C.box(0, 48, 80, 4); C.box(-26, 10, 4, 80); C.box(26, 10, 4, 80);

  batch.build(root);

  // たいまつ（ゆらぐ明かり）
  const torches = [];
  const torchSpots = [[-3, -45], [3, -55], [-3, -65], [14, -66], [23, -54], [39, -60], [11, -80], [39, -80], [11, -92], [39, -92], [21, -100], [9, -110], [41, -110], [9, -122], [41, -122]];
  const flameMat = new THREE.MeshBasicMaterial({ color: '#ffb347', transparent: true, blending: THREE.AdditiveBlending, depthWrite: false });
  torchSpots.forEach(([x, z], i) => {
    const t = new THREE.Group();
    const stick = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.08, 0.8, 6), B.M.wood());
    const flame = new THREE.Mesh(new THREE.ConeGeometry(0.16, 0.5, 8), flameMat);
    flame.position.y = 0.55;
    t.add(stick, flame);
    t.position.set(x + (x < 20 ? 0.4 : -0.4) * (Math.abs(x) > 3 || i % 2 ? 1 : -1), 2.6, z);
    root.add(t);
    torches.push({ flame, phase: i * 1.7 });
    // 光は数を絞る（スマホの負担を減らす）
    if (i % 3 === 0) {
      const light = new THREE.PointLight('#ff9a3c', 14, 13, 1.6);
      light.position.set(t.position.x, 3.3, z);
      root.add(light);
      torches[torches.length - 1].light = light;
    }
  });

  return {
    name: 'necropolis', music: 'desert', root, colliders: C,
    spawn: { x: 0, z: 40, face: Math.PI },
    arrivals: { town: { x: 0, z: 40, face: Math.PI } },
    exits: [{ x: 0, z: 46, r: 3, to: 'town' }],
    /** 墓の中に入ったか（曲と明るさを変える） */
    isInside: p => p.z < -36,
    enemySpawns: [
      { type: 'bandit', x: -3, z: 12 }, { type: 'bandit', x: 4, z: -8 },
      { type: 'mummy', x: 0, z: -52 }, { type: 'mummy', x: 14, z: -66 },
      { type: 'mummy', x: 20, z: -75 }, { type: 'mummy', x: 30, z: -72 }, { type: 'mummy', x: 26, z: -86 },
      { type: 'bandit', x: 18, z: -115 }, { type: 'bandit', x: 32, z: -115 },
      { type: 'jackal', x: 25, z: -118, boss: true },
    ],
    chests: [{ x: 36, z: -54, ankh: 150 }, { x: 12, z: -92, ankh: 200 }, { x: -12, z: 25, ankh: 80 }],
    update(dt, t) {
      for (const tr of torches) {
        const f = 0.85 + Math.sin(t * 13 + tr.phase) * 0.1 + Math.sin(t * 7.3 + tr.phase) * 0.08;
        tr.flame.scale.set(f, f * 1.1, f);
        if (tr.light) tr.light.intensity = 14 * f;
      }
    },
  };
}

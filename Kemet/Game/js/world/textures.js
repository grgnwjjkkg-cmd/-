// コードで描くテクスチャ（砂岩・日干しレンガ・ヒエログリフの壁・砂・布など）
import * as THREE from 'three';

function seeded(seed) {
  let s = seed >>> 0 || 1;
  return () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; };
}

function canvas(w, h) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  return [c, c.getContext('2d')];
}

function toTexture(c, repeat = [1, 1]) {
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.repeat.set(...repeat);
  t.anisotropy = 4;
  return t;
}

function grain(ctx, w, h, rand, amount, alpha = 0.08) {
  for (let i = 0; i < amount; i++) {
    const v = rand() < 0.5 ? 0 : 255;
    ctx.fillStyle = `rgba(${v},${v},${v},${alpha * rand()})`;
    ctx.fillRect(rand() * w, rand() * h, 1 + rand() * 2, 1 + rand() * 2);
  }
}

const cache = new Map();
const once = (key, make) => { if (!cache.has(key)) cache.set(key, make()); return cache.get(key); };

/** 砂岩の石積み */
export const sandstone = (tint = '#d9b98a') => once('sandstone' + tint, () => {
  const [c, x] = canvas(256, 256), r = seeded(3);
  x.fillStyle = tint; x.fillRect(0, 0, 256, 256);
  grain(x, 256, 256, r, 5000, 0.12);
  x.strokeStyle = 'rgba(90,60,30,0.35)'; x.lineWidth = 2;
  const rows = 6;
  for (let i = 0; i < rows; i++) {
    const y = (i * 256) / rows;
    x.beginPath(); x.moveTo(0, y); x.lineTo(256, y); x.stroke();
    const off = i % 2 ? 0 : 42;
    for (let j = off; j < 256; j += 84) { x.beginPath(); x.moveTo(j, y); x.lineTo(j, y + 256 / rows); x.stroke(); }
  }
  return toTexture(c);
});

/** 日干しレンガの家の壁（しっくい塗り） */
export const mudbrick = (tint = '#d8b787') => once('mud' + tint, () => {
  const [c, x] = canvas(256, 256), r = seeded(9);
  x.fillStyle = tint; x.fillRect(0, 0, 256, 256);
  for (let i = 0; i < 60; i++) {
    x.fillStyle = `rgba(${150 + r() * 60},${110 + r() * 40},${70 + r() * 30},0.18)`;
    x.beginPath(); x.ellipse(r() * 256, r() * 256, 10 + r() * 40, 6 + r() * 20, r() * 3, 0, Math.PI * 2); x.fill();
  }
  grain(x, 256, 256, r, 4000, 0.1);
  // ところどころレンガが見える
  x.strokeStyle = 'rgba(110,70,40,0.25)';
  for (let i = 0; i < 6; i++) {
    const bx = r() * 220, by = r() * 220;
    for (let k = 0; k < 3; k++) x.strokeRect(bx + (k % 2) * 12, by + k * 10, 26, 10);
  }
  return toTexture(c);
});

/** 砂地（さざ波模様） */
export const sand = () => once('sand', () => {
  const [c, x] = canvas(512, 512), r = seeded(5);
  x.fillStyle = '#e2c28e'; x.fillRect(0, 0, 512, 512);
  for (let i = 0; i < 140; i++) {
    x.strokeStyle = `rgba(${r() < 0.5 ? '160,120,70' : '255,240,210'},${0.08 + r() * 0.1})`;
    x.lineWidth = 1 + r() * 2;
    const y = r() * 512;
    x.beginPath();
    for (let px = 0; px <= 512; px += 16) x.lineTo(px, y + Math.sin(px * 0.03 + i) * 6);
    x.stroke();
  }
  grain(x, 512, 512, r, 12000, 0.1);
  return toTexture(c, [1, 1]);
});

/** 石畳 */
export const paving = () => once('paving', () => {
  const [c, x] = canvas(256, 256), r = seeded(11);
  x.fillStyle = '#cdb087'; x.fillRect(0, 0, 256, 256);
  const n = 4, s = 256 / n;
  for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) {
    const l = 180 + r() * 40;
    x.fillStyle = `rgb(${l + 20},${l},${l - 40})`;
    x.fillRect(i * s + 2, j * s + 2, s - 4, s - 4);
  }
  grain(x, 256, 256, r, 5000, 0.12);
  return toTexture(c);
});

/** ヒエログリフの壁（彫り＋彩色） */
export const hieroglyphs = (tint = '#d9b98a', painted = true, seed = 21) => once(`hiero${tint}${painted}${seed}`, () => {
  const [c, x] = canvas(512, 512), r = seeded(seed);
  x.fillStyle = tint; x.fillRect(0, 0, 512, 512);
  grain(x, 512, 512, r, 9000, 0.1);
  const colors = painted ? ['#2f5fa8', '#b8432f', '#2f8a6a', '#d9a13a', '#222'] : ['rgba(80,50,20,0.55)'];
  // 上下の帯
  if (painted) {
    for (const y of [8, 492]) {
      for (let i = 0; i < 512; i += 24) { x.fillStyle = colors[(i / 24) % 3]; x.fillRect(i, y, 20, 12); }
    }
  }
  const cols = 8, cw = 512 / cols;
  for (let col = 0; col < cols; col++) {
    x.strokeStyle = 'rgba(80,50,20,0.4)'; x.lineWidth = 2;
    x.beginPath(); x.moveTo(col * cw, 30); x.lineTo(col * cw, 482); x.stroke();
    for (let y = 40; y < 470; y += 50) {
      const cx = col * cw + cw / 2, cy = y + 22;
      x.fillStyle = colors[Math.floor(r() * colors.length)];
      x.strokeStyle = x.fillStyle; x.lineWidth = 4; x.lineCap = 'round';
      glyph(x, Math.floor(r() * 9), cx, cy, 17);
    }
  }
  return toTexture(c);
});

// 簡単なヒエログリフ風の記号
function glyph(x, kind, cx, cy, s) {
  x.beginPath();
  switch (kind) {
    case 0: // アンク
      x.ellipse(cx, cy - s * 0.6, s * 0.35, s * 0.45, 0, 0, Math.PI * 2);
      x.moveTo(cx, cy - s * 0.15); x.lineTo(cx, cy + s); x.moveTo(cx - s * 0.6, cy); x.lineTo(cx + s * 0.6, cy); x.stroke(); return;
    case 1: // 目
      x.ellipse(cx, cy, s * 0.8, s * 0.4, 0, 0, Math.PI * 2); x.stroke();
      x.beginPath(); x.arc(cx, cy, s * 0.2, 0, Math.PI * 2); x.fill();
      x.beginPath(); x.moveTo(cx - s * 0.2, cy + s * 0.4); x.lineTo(cx - s * 0.4, cy + s); x.stroke(); return;
    case 2: // 波（水）
      for (let k = -1; k <= 1; k++) { x.moveTo(cx - s, cy + k * s * 0.5); for (let t = -s; t <= s; t += 4) x.lineTo(cx + t, cy + k * s * 0.5 + Math.sin(t * 0.5) * 3); }
      x.stroke(); return;
    case 3: // 鳥
      x.ellipse(cx, cy, s * 0.7, s * 0.4, -0.3, 0, Math.PI * 2); x.fill();
      x.beginPath(); x.arc(cx + s * 0.6, cy - s * 0.5, s * 0.22, 0, Math.PI * 2); x.fill();
      x.beginPath(); x.moveTo(cx - s * 0.2, cy + s * 0.3); x.lineTo(cx - s * 0.3, cy + s); x.moveTo(cx + s * 0.2, cy + s * 0.3); x.lineTo(cx + s * 0.1, cy + s); x.stroke(); return;
    case 4: // 太陽
      x.arc(cx, cy, s * 0.5, 0, Math.PI * 2); x.fill(); return;
    case 5: // 足
      x.moveTo(cx - s * 0.2, cy - s); x.lineTo(cx - s * 0.2, cy + s * 0.6); x.lineTo(cx + s * 0.8, cy + s * 0.6); x.stroke(); return;
    case 6: // 蛇
      x.moveTo(cx - s, cy + s * 0.5);
      for (let t = -s; t <= s; t += 3) x.lineTo(cx + t, cy + Math.sin(t * 0.3) * s * 0.4);
      x.stroke(); return;
    case 7: // パン（半円）
      x.arc(cx, cy + s * 0.4, s * 0.8, Math.PI, 0); x.closePath(); x.fill(); return;
    default: // 杖
      x.moveTo(cx, cy - s); x.lineTo(cx, cy + s); x.moveTo(cx, cy - s); x.lineTo(cx + s * 0.5, cy - s * 0.7); x.stroke();
  }
}

/** しま模様の布（屋台の日よけ） */
export const cloth = (a, b) => once('cloth' + a + b, () => {
  const [c, x] = canvas(128, 128);
  for (let i = 0; i < 8; i++) { x.fillStyle = i % 2 ? a : b; x.fillRect(i * 16, 0, 16, 128); }
  const r = seeded(2); grain(x, 128, 128, r, 1500, 0.1);
  return toTexture(c);
});

/** 木の板 */
export const wood = () => once('wood', () => {
  const [c, x] = canvas(128, 128), r = seeded(4);
  x.fillStyle = '#8a5a34'; x.fillRect(0, 0, 128, 128);
  for (let i = 0; i < 4; i++) {
    x.fillStyle = `rgb(${120 + r() * 30},${80 + r() * 20},${45 + r() * 15})`;
    x.fillRect(0, i * 32 + 1, 128, 30);
    x.strokeStyle = 'rgba(60,35,15,0.35)';
    for (let k = 0; k < 6; k++) { x.beginPath(); const y = i * 32 + r() * 30; x.moveTo(0, y); x.bezierCurveTo(40, y + 3, 80, y - 3, 128, y); x.stroke(); }
  }
  return toTexture(c);
});

/** ヤシの葉（透明な部分つき） */
export const palmLeaf = () => once('palmLeaf', () => {
  const [c, x] = canvas(64, 256);
  x.clearRect(0, 0, 64, 256);
  x.strokeStyle = '#5a7a2a'; x.lineWidth = 3;
  x.beginPath(); x.moveTo(32, 256); x.lineTo(32, 0); x.stroke();
  for (let y = 8; y < 250; y += 7) {
    const len = 28 * Math.sin((y / 256) * Math.PI) + 4;
    x.strokeStyle = y % 14 ? '#6f9a36' : '#5f8a2e'; x.lineWidth = 3;
    x.beginPath(); x.moveTo(32, y); x.lineTo(32 - len, y + 10); x.moveTo(32, y); x.lineTo(32 + len, y + 10); x.stroke();
  }
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
  return t;
});

/** 空（上が青、地平線が黄土色） */
export function skyTexture() {
  const [c, x] = canvas(4, 256);
  const g = x.createLinearGradient(0, 0, 0, 256);
  g.addColorStop(0, '#3f7fcf'); g.addColorStop(0.45, '#8fc0e8'); g.addColorStop(0.62, '#f3d9a4'); g.addColorStop(1, '#e8b877');
  x.fillStyle = g; x.fillRect(0, 0, 4, 256);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

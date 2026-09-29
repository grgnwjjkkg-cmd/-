// 画面の右側のなぞり操作：タップ＝斬る／長押し→離す＝溜め斬り／はじく＝砂走り（上ならジャンプ）
// 円を描く＝ラーの円環／ジグザグを描く＝セトの雷／ゆっくりなぞる＝カメラ
// 指のあとに金色の光の線を描く（神聖文字を書いているように見える）

const TAP_MS = 230, TAP_PX = 14, HOLD_MS = 360, FLICK_MS = 260, FLICK_PX = 42, CAM_DELAY = 150;

export class Gestures {
  /** h: { camera(dx, dy), cameraSnapshot(), cameraRestore(s), tap(), holdStart(), holdEnd(sec), flick(dx, dy), jump(), glyph(name), enabled() } */
  constructor(target, overlay, h) {
    this.h = h;
    this.cv = overlay; this.g = overlay.getContext('2d');
    this.trail = [];            // 描いている線（消えていく）
    this.cur = null;
    const resize = () => { const r = window.devicePixelRatio || 1; overlay.width = innerWidth * r; overlay.height = innerHeight * r; this.g.setTransform(r, 0, 0, r, 0, 0); };
    resize(); addEventListener('resize', resize);
    target.addEventListener('pointerdown', e => this.down(e));
    target.addEventListener('pointermove', e => this.move(e));
    target.addEventListener('pointerup', e => this.up(e));
    target.addEventListener('pointercancel', e => { if (this.cur && e.pointerId === this.cur.id) this.cancel(); });
  }

  down(e) {
    if (this.cur || !this.h.enabled()) return;
    const t = performance.now();
    this.cur = { id: e.pointerId, pts: [{ x: e.clientX, y: e.clientY, t }], t0: t, cam: this.h.cameraSnapshot(), camOn: false, lx: e.clientX, ly: e.clientY, holding: false };
    try { e.target.setPointerCapture?.(e.pointerId); } catch (_) { }
    this.cur.holdTimer = setTimeout(() => {
      const c = this.cur; if (!c) return;
      if (pathLen(c.pts) < TAP_PX) { c.holding = true; this.h.holdStart(); }
    }, HOLD_MS);
  }

  move(e) {
    const c = this.cur; if (!c || e.pointerId !== c.id) return;
    const t = performance.now();
    c.pts.push({ x: e.clientX, y: e.clientY, t });
    if (c.holding && pathLen(c.pts) > 34) { c.holding = false; this.h.holdEnd(-1); }   // 長押し中に大きく動かしたら取り消し
    // はじく操作とまちがえないよう、少し待ってからカメラを動かす。曲がって描いているときは文字を書いている → カメラは動かさない
    if (!c.glyphMode && turning(c.pts) > 1.0) { c.glyphMode = true; if (c.camOn) { this.h.cameraRestore(c.cam); } c.camOn = false; }
    if (!c.camOn && !c.glyphMode && t - c.t0 > CAM_DELAY) c.camOn = true;
    if (c.camOn && !c.holding) this.h.camera(e.clientX - c.lx, e.clientY - c.ly);
    if (c.camOn) { c.lx = e.clientX; c.ly = e.clientY; }
    this.trail.push({ x: e.clientX, y: e.clientY, t });
  }

  up(e) {
    const c = this.cur; if (!c || e.pointerId !== c.id) return;
    clearTimeout(c.holdTimer);
    this.cur = null;
    const t = performance.now(), dur = t - c.t0, pts = c.pts, L = pathLen(pts);
    const dx = pts[pts.length - 1].x - pts[0].x, dy = pts[pts.length - 1].y - pts[0].y, D = Math.hypot(dx, dy);
    if (c.holding) { this.h.holdEnd((dur - HOLD_MS) / 1000); return; }
    const glyph = recognize(pts);
    if (glyph && dur < 1600) { this.h.cameraRestore(c.cam); this.h.glyph(glyph); this.flash(glyph); return; }
    if (dur < TAP_MS && L < TAP_PX) { this.h.tap(); return; }
    if (dur < FLICK_MS && D > FLICK_PX) {
      this.h.cameraRestore(c.cam);
      if (dy < -Math.abs(dx) * 1.2) this.h.jump(); else this.h.flick(dx, dy);
    }
  }

  cancel() { clearTimeout(this.cur?.holdTimer); if (this.cur?.holding) this.h.holdEnd(-1); this.cur = null; }

  /** 描いた形が認められたとき、線をいっそう光らせる */
  flash(name) { this.glow = { name, t: performance.now() }; }

  /** 毎フレーム：光の線を描く */
  draw() {
    const g = this.g, now = performance.now();
    g.clearRect(0, 0, innerWidth, innerHeight);
    this.trail = this.trail.filter(p => now - p.t < 520);
    if (this.trail.length > 1) {
      g.lineCap = 'round'; g.lineJoin = 'round';
      const glow = this.glow && now - this.glow.t < 400;
      for (let i = 1; i < this.trail.length; i++) {
        const a = this.trail[i - 1], b = this.trail[i];
        if (b.t - a.t > 80) continue;
        const k = 1 - (now - b.t) / 520;
        g.strokeStyle = `rgba(255, ${glow ? 236 : 210}, ${glow ? 170 : 120}, ${k * (glow ? 1 : 0.8)})`;
        g.shadowColor = '#ffb640'; g.shadowBlur = glow ? 22 : 12;
        g.lineWidth = (glow ? 9 : 5) * k + 1;
        g.beginPath(); g.moveTo(a.x, a.y); g.lineTo(b.x, b.y); g.stroke();
      }
      g.shadowBlur = 0;
    }
  }
}

/** 線がどれだけ曲がったか（ラジアンの合計） */
function turning(p) {
  if (p.length < 5) return 0;
  const q = resample(p, 14);
  let sum = 0;
  for (let i = 2; i < q.length; i++) {
    const a = Math.atan2(q[i - 1].y - q[i - 2].y, q[i - 1].x - q[i - 2].x), b = Math.atan2(q[i].y - q[i - 1].y, q[i].x - q[i - 1].x);
    let d = b - a; d = Math.atan2(Math.sin(d), Math.cos(d)); sum += Math.abs(d);
  }
  return sum;
}

function pathLen(p) { let s = 0; for (let i = 1; i < p.length; i++) s += Math.hypot(p[i].x - p[i - 1].x, p[i].y - p[i - 1].y); return s; }

/** 等間隔に点を取り直す */
function resample(p, step = 12) {
  const out = [{ x: p[0].x, y: p[0].y }];
  let acc = 0;
  for (let i = 1; i < p.length; i++) {
    let a = { x: p[i - 1].x, y: p[i - 1].y }; const b = p[i];
    let d = Math.hypot(b.x - a.x, b.y - a.y);
    while (acc + d >= step) {
      const k = (step - acc) / d;
      a = { x: a.x + (b.x - a.x) * k, y: a.y + (b.y - a.y) * k };
      out.push(a); d = Math.hypot(b.x - a.x, b.y - a.y); acc = 0;
    }
    acc += d;
  }
  return out;
}

/** 形を読む：'circle'（円）／'zigzag'（ジグザグ）／null */
export function recognize(raw) {
  if (raw.length < 6 || pathLen(raw) < 130) return null;
  const p = resample(raw);
  if (p.length < 8) return null;
  const xs = p.map(q => q.x), ys = p.map(q => q.y);
  const w = Math.max(...xs) - Math.min(...xs), h = Math.max(...ys) - Math.min(...ys), size = Math.max(w, h);
  // 向きの変わり方を足し合わせる
  let turn = 0, sharp = 0;
  const ang = [];
  for (let i = 1; i < p.length; i++) ang.push(Math.atan2(p[i].y - p[i - 1].y, p[i].x - p[i - 1].x));
  for (let i = 1; i < ang.length; i++) {
    let d = ang[i] - ang[i - 1]; d = Math.atan2(Math.sin(d), Math.cos(d));
    turn += d;
  }
  // 円：同じ向きにほぼ一周以上まわり、幅と高さが近い
  const closed = Math.hypot(p[0].x - p[p.length - 1].x, p[0].y - p[p.length - 1].y) < size * 0.55;
  if (Math.abs(turn) > Math.PI * 1.55 && closed && Math.min(w, h) > size * 0.45) return 'circle';
  // ジグザグ：大きく折り返す角が2回以上
  let last = 0;
  for (let i = 2; i < ang.length; i += 1) {
    let d = ang[i] - ang[Math.max(0, i - 3)]; d = Math.abs(Math.atan2(Math.sin(d), Math.cos(d)));
    if (d > 1.9 && i - last > 3) { sharp++; last = i; }
  }
  if (sharp >= 2 && size > 90) return 'zigzag';
  return null;
}

// BGM と効果音。音源ファイルは使わず、Web Audio でその場で作曲・演奏する。
// エジプト風の音階（ヒジャーズ：レ・ミ♭・ファ#・ソ・ラ・シ♭・ド）で、ウード風の撥弦・ダルブッカ風の太鼓・ネイ風の笛。

const HIJAZ = [0, 1, 4, 5, 7, 8, 10]; // D を基準にした半音
const BASE_MIDI = 62; // D4

const midiToHz = m => 440 * Math.pow(2, (m - 69) / 12);
const scaleNote = (degree, octave = 0) => {
  const n = HIJAZ.length;
  const o = Math.floor(degree / n) + octave;
  const d = ((degree % n) + n) % n;
  return BASE_MIDI + HIJAZ[d] + 12 * o;
};

// 乱数（曲が毎回同じになるよう種つき）
function rng(seed) {
  let s = seed >>> 0;
  return () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; };
}

export class Audio {
  constructor() {
    this.ctx = null;
    this.current = null;
    this.muted = false;
    this.musicVolume = 0.55;
    this.sfxVolume = 0.8;
    this.pluckCache = new Map();
  }

  /** 最初のタッチで呼ぶ（ブラウザは操作なしに音を出せない） */
  unlock() {
    if (!this.ctx) {
      const AC = window.AudioContext || window.webkitAudioContext;
      this.ctx = new AC();
      this.master = this.ctx.createGain();
      this.master.gain.value = this.muted ? 0 : 1;
      this.master.connect(this.ctx.destination);
      this.musicBus = this.ctx.createGain();
      this.musicBus.gain.value = this.musicVolume;
      this.sfxBus = this.ctx.createGain();
      this.sfxBus.gain.value = this.sfxVolume;
      this.reverb = this.ctx.createConvolver();
      this.reverb.buffer = this.impulse(2.8, 2.5);
      const wet = this.ctx.createGain();
      wet.gain.value = 0.35;
      this.musicBus.connect(this.master);
      this.musicBus.connect(this.reverb);
      this.reverb.connect(wet).connect(this.master);
      this.sfxBus.connect(this.master);
      this.noiseBuf = this.noiseBuffer(1);
    }
    if (this.ctx.state === 'suspended') this.ctx.resume();
    if (this.pendingTheme) { const t = this.pendingTheme; this.pendingTheme = null; this.play(t); }
  }

  setMuted(m) {
    this.muted = m;
    if (this.master) this.master.gain.setTargetAtTime(m ? 0 : 1, this.ctx.currentTime, 0.05);
  }

  impulse(seconds, decay) {
    const rate = this.ctx.sampleRate, len = Math.floor(rate * seconds);
    const buf = this.ctx.createBuffer(2, len, rate);
    for (let c = 0; c < 2; c++) {
      const d = buf.getChannelData(c);
      for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, decay);
    }
    return buf;
  }

  noiseBuffer(seconds) {
    const len = Math.floor(this.ctx.sampleRate * seconds);
    const buf = this.ctx.createBuffer(1, len, this.ctx.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
    return buf;
  }

  // ---------- 楽器 ----------

  /** ウード風：カープラス・ストロング法で作った撥弦音（音ごとにキャッシュ） */
  pluckBuffer(midi, brightness = 0.5) {
    const key = `${midi}:${brightness}`;
    if (this.pluckCache.has(key)) return this.pluckCache.get(key);
    const rate = this.ctx.sampleRate, hz = midiToHz(midi);
    const len = Math.floor(rate * 1.6), period = Math.round(rate / hz);
    const buf = this.ctx.createBuffer(1, len, rate), d = buf.getChannelData(0);
    const ring = new Float32Array(period);
    for (let i = 0; i < period; i++) ring[i] = Math.random() * 2 - 1;
    let prev = 0;
    for (let i = 0; i < len; i++) {
      const j = i % period;
      const v = ring[j];
      // 平均化で高音が減衰する。brightness が大きいほど明るい
      const next = (v * (0.5 + brightness * 0.5) + prev * (0.5 - brightness * 0.5)) * 0.996;
      prev = v;
      ring[j] = next;
      d[i] = v * (i < 30 ? i / 30 : 1);
    }
    this.pluckCache.set(key, buf);
    return buf;
  }

  pluck(t, midi, vol = 0.35, dest = this.musicBus, brightness = 0.55) {
    const src = this.ctx.createBufferSource();
    src.buffer = this.pluckBuffer(midi, brightness);
    const g = this.ctx.createGain();
    g.gain.setValueAtTime(vol, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + 1.5);
    const lp = this.ctx.createBiquadFilter();
    lp.type = 'lowpass'; lp.frequency.value = 3200;
    src.connect(lp).connect(g).connect(dest);
    src.start(t); src.stop(t + 1.6);
  }

  /** ネイ風の笛：揺れ（ビブラート）と息の音 */
  flute(t, midi, dur, vol = 0.12) {
    const c = this.ctx, o = c.createOscillator(), g = c.createGain();
    o.type = 'sine'; o.frequency.value = midiToHz(midi);
    const vib = c.createOscillator(), vg = c.createGain();
    vib.frequency.value = 5.2; vg.gain.value = midiToHz(midi) * 0.012;
    vib.connect(vg).connect(o.frequency);
    // すこし下からしゃくり上げる
    o.frequency.setValueAtTime(midiToHz(midi) * 0.97, t);
    o.frequency.linearRampToValueAtTime(midiToHz(midi), t + 0.12);
    g.gain.setValueAtTime(0.0001, t);
    g.gain.linearRampToValueAtTime(vol, t + 0.15);
    g.gain.setValueAtTime(vol, t + dur * 0.7);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    const n = c.createBufferSource(); n.buffer = this.noiseBuf;
    const nf = c.createBiquadFilter(); nf.type = 'bandpass'; nf.frequency.value = midiToHz(midi) * 2; nf.Q.value = 2;
    const ng = c.createGain(); ng.gain.value = vol * 0.25;
    n.connect(nf).connect(ng).connect(g);
    o.connect(g).connect(this.musicBus);
    o.start(t); vib.start(t); n.start(t);
    o.stop(t + dur + 0.05); vib.stop(t + dur + 0.05); n.stop(t + dur + 0.05);
  }

  /** ダルブッカ風：dum（低い）・tek（高い）・ka（小さい） */
  drum(t, kind, vol = 0.5, dest = this.musicBus) {
    const c = this.ctx;
    if (kind === 'dum') {
      const o = c.createOscillator(), g = c.createGain();
      o.type = 'sine';
      o.frequency.setValueAtTime(120, t);
      o.frequency.exponentialRampToValueAtTime(55, t + 0.25);
      g.gain.setValueAtTime(vol, t);
      g.gain.exponentialRampToValueAtTime(0.001, t + 0.4);
      o.connect(g).connect(dest); o.start(t); o.stop(t + 0.45);
    } else {
      const n = c.createBufferSource(); n.buffer = this.noiseBuf;
      const f = c.createBiquadFilter(); f.type = 'bandpass';
      f.frequency.value = kind === 'tek' ? 3800 : 2600; f.Q.value = 1.2;
      const g = c.createGain();
      const v = kind === 'tek' ? vol * 0.55 : vol * 0.25;
      g.gain.setValueAtTime(v, t);
      g.gain.exponentialRampToValueAtTime(0.001, t + (kind === 'tek' ? 0.09 : 0.05));
      n.connect(f).connect(g).connect(dest);
      n.start(t, Math.random() * 0.5); n.stop(t + 0.12);
    }
  }

  /** 持続音（ドローン） */
  drone(t, midis, dur, vol = 0.05) {
    const c = this.ctx, g = c.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.linearRampToValueAtTime(vol, t + 1.5);
    g.gain.setValueAtTime(vol, t + dur - 1.5);
    g.gain.linearRampToValueAtTime(0.0001, t + dur);
    const lp = c.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 700;
    g.connect(lp).connect(this.musicBus);
    for (const m of midis) {
      for (const detune of [-6, 6]) {
        const o = c.createOscillator(); o.type = 'sawtooth';
        o.frequency.value = midiToHz(m); o.detune.value = detune;
        o.connect(g); o.start(t); o.stop(t + dur);
      }
    }
  }

  // ---------- 曲 ----------

  static THEMES = {
    town:   { bpm: 100, rhythm: 'maqsum', melody: 'oud', drone: [38, 45], seed: 7, density: 0.8 },
    desert: { bpm: 84,  rhythm: 'baladi', melody: 'flute', drone: [38, 45], seed: 21, density: 0.55 },
    tomb:   { bpm: 64,  rhythm: 'sparse', melody: 'flute', drone: [26, 33, 39], seed: 13, density: 0.35 },
    battle: { bpm: 138, rhythm: 'fast', melody: 'oud', drone: [38, 44], seed: 5, density: 1.0 },
  };

  static RHYTHMS = {
    // 16分音符 × 8 = 2拍。D=dum T=tek k=ka
    maqsum: 'D.T.kTk.D.T.kTk.',
    baladi: 'D.D.kTk.D.kTk.T.',
    sparse: 'D.......k...T...',
    fast:   'D.TkD.TkD.TkT.Tk',
  };

  play(name) {
    if (!this.ctx) { this.pendingTheme = name; return; }
    if (this.current === name) return;
    this.stopMusic();
    this.current = name;
    const theme = Audio.THEMES[name];
    if (!theme) return;
    const token = this.token = Symbol(name);
    const step = 60 / theme.bpm / 4; // 16分音符の長さ
    const rand = rng(theme.seed);
    const phrases = this.compose(theme, rand);
    let bar = 0;
    let next = this.ctx.currentTime + 0.1;
    const barLen = step * 16;
    this.drone(next, theme.drone, barLen * 8, name === 'tomb' ? 0.06 : 0.035);
    const schedule = () => {
      if (this.token !== token) return;
      while (next < this.ctx.currentTime + 1.5) {
        this.scheduleBar(next, step, theme, phrases[bar % phrases.length], bar);
        next += barLen;
        bar++;
        if (bar % 8 === 0) this.drone(next, theme.drone, barLen * 8, name === 'tomb' ? 0.06 : 0.035);
      }
      this.timer = setTimeout(schedule, 400);
    };
    schedule();
  }

  stopMusic() {
    this.token = null;
    this.current = null;
    clearTimeout(this.timer);
  }

  /** 8小節ぶんのメロディを作る（モチーフの繰り返しと変形） */
  compose(theme, rand) {
    const motif = [];
    let deg = 4 + Math.floor(rand() * 3);
    for (let i = 0; i < 16; i++) {
      if (rand() < theme.density * (i % 4 === 0 ? 1 : 0.55)) {
        deg += [-2, -1, -1, 1, 1, 2, 0][Math.floor(rand() * 7)];
        deg = Math.max(0, Math.min(11, deg));
        motif.push({ i, deg, len: 1 + Math.floor(rand() * 3) });
      }
    }
    const vary = (m, shift) => m.map(n => ({ ...n, deg: Math.max(0, Math.min(12, n.deg + shift)) }));
    const answer = motif.map(n => ({ ...n, deg: Math.max(0, n.deg - 1 - (n.i > 11 ? 2 : 0)) }));
    // 最後は主音（レ）で終わる
    const cadence = [...motif.filter(n => n.i < 12), { i: 12, deg: 0, len: 4 }];
    return [motif, answer, vary(motif, 2), cadence, motif, vary(answer, 1), vary(motif, -1), cadence];
  }

  scheduleBar(t, step, theme, phrase, bar) {
    const rhythm = Audio.RHYTHMS[theme.rhythm];
    for (let i = 0; i < 16; i++) {
      const ch = rhythm[i % rhythm.length];
      if (ch === 'D') this.drum(t + i * step, 'dum', 0.45);
      else if (ch === 'T') this.drum(t + i * step, 'tek', 0.4);
      else if (ch === 'k') this.drum(t + i * step, 'ka', 0.4);
    }
    // 曲の頭2小節は太鼓だけで入る
    if (bar < 2 && theme.melody === 'oud') return;
    for (const n of phrase) {
      const time = t + n.i * step;
      const midi = scaleNote(n.deg, theme.melody === 'flute' ? 0 : -1);
      if (theme.melody === 'oud') {
        this.pluck(time, midi, 0.3);
        // ウードらしいトレモロ（同じ音を細かく）
        if (n.len >= 3) this.pluck(time + step, midi, 0.16);
      } else {
        this.flute(time, midi + 12, n.len * step * 1.6, 0.1);
      }
    }
    // ベース
    if (bar % 2 === 0) this.pluck(t, scaleNote(0, -2), 0.3, this.musicBus, 0.3);
  }

  // ---------- 効果音 ----------

  sfx(name) {
    if (!this.ctx) return;
    const c = this.ctx, t = c.currentTime, out = this.sfxBus;
    const noise = (dur, type, freq, q, vol, sweepTo) => {
      const n = c.createBufferSource(); n.buffer = this.noiseBuf;
      const f = c.createBiquadFilter(); f.type = type; f.frequency.setValueAtTime(freq, t); f.Q.value = q;
      if (sweepTo) f.frequency.exponentialRampToValueAtTime(sweepTo, t + dur);
      const g = c.createGain(); g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.001, t + dur);
      n.connect(f).connect(g).connect(out); n.start(t, Math.random()); n.stop(t + dur + 0.02);
    };
    const tone = (freq, dur, type = 'sine', vol = 0.2, at = 0, to) => {
      const o = c.createOscillator(), g = c.createGain(); o.type = type;
      o.frequency.setValueAtTime(freq, t + at);
      if (to) o.frequency.exponentialRampToValueAtTime(to, t + at + dur);
      g.gain.setValueAtTime(0.0001, t + at); g.gain.linearRampToValueAtTime(vol, t + at + 0.01);
      g.gain.exponentialRampToValueAtTime(0.001, t + at + dur);
      o.connect(g).connect(out); o.start(t + at); o.stop(t + at + dur + 0.02);
    };
    switch (name) {
      case 'swing': noise(0.18, 'bandpass', 900, 1.5, 0.35, 3500); break;
      case 'hit': tone(160, 0.18, 'triangle', 0.5, 0, 60); noise(0.12, 'lowpass', 2500, 0.7, 0.4); break;
      case 'hurt': tone(220, 0.25, 'sawtooth', 0.18, 0, 110); noise(0.15, 'lowpass', 1200, 0.7, 0.3); break;
      case 'roll': noise(0.3, 'lowpass', 600, 0.7, 0.25, 200); break;
      case 'step': noise(0.06, 'lowpass', 500 + Math.random() * 300, 0.7, 0.08); break;
      case 'coin': tone(1320, 0.12, 'square', 0.06); tone(1760, 0.2, 'square', 0.06, 0.07); break;
      case 'talk': tone(660 + Math.random() * 120, 0.05, 'triangle', 0.05); break;
      case 'ui': tone(880, 0.06, 'triangle', 0.08); break;
      case 'clue': [0, 4, 7, 12].forEach((s, i) => this.pluck(t + i * 0.09, scaleNote(s, 0), 0.3, out, 0.7)); break;
      case 'pot': noise(0.5, 'bandpass', 400, 3, 0.4, 1600); break;
      case 'rare': [0, 2, 4, 7, 9, 12, 14].forEach((s, i) => this.pluck(t + i * 0.07, scaleNote(s, 1), 0.3, out, 0.8)); tone(1046, 1.2, 'sine', 0.08, 0.5); break;
      case 'death': tone(300, 0.6, 'sawtooth', 0.12, 0, 60); break;
    }
  }
}

export const audio = new Audio();

// 自動で歩かせてプレイ動画のコマを撮る: node tools/record.js <outdir> [fps] [w] [h]
// そのあと ffmpeg -framerate <fps> -i <outdir>/f%04d.jpg -c:v libx264 -pix_fmt yuv420p out.mp4
const { chromium } = require('playwright');
const fs = require('fs');
const [OUT, FPS = 20, W = 1280, H = 590] = process.argv.slice(2);
fs.rmSync(OUT, { recursive: true, force: true }); fs.mkdirSync(OUT, { recursive: true });

// 歩く道すじ（x, z）と、その区間の秒数
const PATH = [
  [[0, 70], [0, 30]], [[0, 30], [0, 2]], [[0, 2], [0, -24]], [[0, -24], [0, -36]], [[0, -36], [0, -58]], [[0, -58], [12, -60]],
];
const SECS = [4, 3, 3, 1.5, 3, 2];

(async () => {
  const b = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await b.newPage({ viewport: { width: +W, height: +H } });
  p.on('pageerror', e => console.log('ERR', e.message));
  await p.goto('http://localhost:8811/Game/index.html');
  await p.evaluate(() => localStorage.clear()); await p.reload();
  await p.waitForFunction(() => window.GAME_READY === true, null, { timeout: 180000 });
  await p.click('#startBtn'); await p.waitForTimeout(400);
  for (let i = 0; i < 8; i++) { await p.mouse.click(640, 520); await p.waitForTimeout(200); }
  await p.evaluate(async () => {
    const g = window.game; g.addItem('khopesh'); g.save.weapon = 'khopesh'; await g.equipVisual();
    await g.enterZone('necropolis', false, 'town');
    g.enemies.forEach(e => { e.def = { ...e.def, aggro: 0 }; });
    g.player.pos.set(0, 0, 70); g.player.face = Math.PI; g.camYaw = 0; g.camPitch = 0.22; g.camPos = null;
    // 歩きの入力を道すじから作る
    window.__walk = (tx, tz) => {
      const dx = tx - g.player.pos.x, dz = tz - g.player.pos.z, d = Math.hypot(dx, dz);
      if (d < 0.3) { g.input.x = 0; g.input.y = 0; return; }
      const want = Math.atan2(dx, dz);
      const rel = want - (g.camYaw + Math.PI);
      g.input.x = -Math.sin(rel) * 0.9; g.input.y = Math.cos(rel) * 0.9;
      g.lastDrag = -99;
    };
  });
  let n = 0;
  for (let s = 0; s < PATH.length; s++) {
    const [, to] = PATH[s];
    const frames = Math.round(SECS[s] * FPS);
    for (let f = 0; f < frames; f++) {
      await p.evaluate(([tx, tz, dt]) => { window.__walk(tx, tz); const g = window.game; g.tick(dt / 2, false); g.tick(dt / 2, true); }, [to[0], to[1], 1 / FPS]);
      await p.screenshot({ path: `${OUT}/f${String(n++).padStart(4, '0')}.jpg`, type: 'jpeg', quality: 85 });
    }
  }
  console.log('frames', n);
  await b.close();
})();

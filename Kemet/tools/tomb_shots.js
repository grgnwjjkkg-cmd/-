// 墓の中の見た目を撮影: node tools/tomb_shots.js <outdir>
const { chromium } = require('playwright');
const OUT = process.argv[2];
(async () => {
  const b = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await b.newPage({ viewport: { width: 1280, height: 590 } });
  p.on('pageerror', e => console.log('ERR', e.message));
  await p.goto('http://localhost:8811/Game/index.html');
  await p.evaluate(() => localStorage.clear()); await p.reload();
  await p.waitForFunction(() => window.GAME_READY === true, null, { timeout: 180000 });
  await p.click('#startBtn'); await p.waitForTimeout(400);
  for (let i = 0; i < 8; i++) { await p.mouse.click(640, 520); await p.waitForTimeout(200); }
  await p.evaluate(async () => { const g = window.game; g.addItem('khopesh'); g.save.weapon = 'khopesh'; await g.equipVisual(); await g.enterZone('necropolis', false, 'town'); });
  const views = [
    { x: 0, z: -44, face: Math.PI, yaw: 0.25, pitch: 0.28 },
    { x: 14, z: -56, face: Math.PI * 0.75, yaw: 0.35, pitch: 0.26 },
    { x: 25, z: -60, face: Math.PI, yaw: 0.0, pitch: 0.2 },
    { x: 25, z: -110, face: Math.PI, yaw: -0.3, pitch: 0.25 },
  ];
  for (const [i, v] of views.entries()) {
    await p.evaluate(v => { const g = window.game; g.player.pos.set(v.x, 0, v.z); g.player.face = v.face; g.camYaw = v.face + Math.PI + v.yaw; g.camPitch = v.pitch; g.camPos = null; g.inside = 1; g.enemies.forEach(e => { e.state = 'idle'; }); g.simulate(1.5); }, v);
    await p.waitForTimeout(4000);
    await p.screenshot({ path: `${OUT}/tomb_${i}.png` });
  }
  await b.close();
})();

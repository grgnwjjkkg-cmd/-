// 光を計算した墓地の見た目を撮影: node tools/level_shots.js <outdir> [w h]
const { chromium } = require('playwright');
const [OUT, W = 1280, H = 590] = process.argv.slice(2);
(async () => {
  const b = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await b.newPage({ viewport: { width: +W, height: +H } });
  p.on('pageerror', e => console.log('ERR', e.message));
  p.on('console', m => { if (/rror/.test(m.text())) console.log('console', m.text().slice(0, 200)); });
  await p.goto('http://localhost:8811/Game/index.html');
  await p.evaluate(() => localStorage.clear()); await p.reload();
  await p.waitForFunction(() => window.GAME_READY === true, null, { timeout: 180000 });
  await p.click('#startBtn'); await p.waitForTimeout(400);
  for (let i = 0; i < 8; i++) { await p.mouse.click(640, 520); await p.waitForTimeout(200); }
  await p.evaluate(async () => { const g = window.game; g.addItem('khopesh'); g.save.weapon = 'khopesh'; await g.equipVisual(); await g.enterZone('necropolis', false, 'town'); });
  const views = [
    ['desert', 0, 86, Math.PI, 0.0, 0.18], ['ruins', -12, 40, Math.PI * 1.2, 0.5, 0.2], ['gate', 0, 6, Math.PI, 0.0, 0.12],
    ['antechamber', 0, -16, Math.PI, 0.2, 0.2], ['hall', 0, -42, Math.PI, 0.15, 0.16], ['cave', 31, -70, Math.PI, -0.3, 0.2],
    ['lair', 56, -95, Math.PI / 2, 0.3, 0.2],
  ];
  for (const [n, x, z, face, yaw, pitch] of views) {
    await p.evaluate(v => { const [x, z, face, yaw, pitch] = v; const g = window.game; g.player.pos.set(x, 0, z); g.player.face = face; g.player.root.rotation.y = face; g.camYaw = face + Math.PI + yaw; g.camPitch = pitch; g.camPos = null; g.enemies.forEach(e => { e.state = 'idle'; e.def = { ...e.def, aggro: 0 }; }); for (let i = 0; i < 90; i++) g.tick(1 / 30, false); }, [x, z, face, yaw, pitch]);
    await p.waitForTimeout(3500);
    await p.screenshot({ path: `${OUT}/lv_${n}.png` }); console.log('shot', n);
  }
  await b.close();
})();

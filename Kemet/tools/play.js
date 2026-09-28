// 自動プレイで画面を撮る: node tools/play.js <outdir> [script]
const { chromium } = require('playwright');
const OUT = process.argv[2] || '/tmp/shots';
require('fs').mkdirSync(OUT, { recursive: true });
(async () => {
  const b = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--autoplay-policy=no-user-gesture-required'] });
  const p = await b.newPage({ viewport: { width: 932, height: 430 }, deviceScaleFactor: 1 });
  p.on('pageerror', e => console.log('ERR', e.message));
  p.on('console', m => { const t = m.text(); if (/rror|warn/i.test(t) && !/GPU stall|THREE\.WebGLRenderer/.test(t)) console.log('console:', t.slice(0, 300)); });
  await p.goto('http://localhost:8811/Game/index.html');
  await p.evaluate(() => localStorage.clear());
  await p.reload();
  await p.waitForFunction(() => window.GAME_READY === true, null, { timeout: 180000 });
  const shot = async n => { await p.waitForTimeout(300); await p.screenshot({ path: `${OUT}/${n}.png` }); console.log('shot', n); };
  await p.waitForTimeout(1500); await shot('01_title');
  await p.click('#startBtn');
  await p.waitForTimeout(800); await shot('02_intro');
  for (let i = 0; i < 6; i++) { await p.mouse.click(466, 380); await p.waitForTimeout(250); }
  await p.waitForTimeout(500); await shot('03_start');
  const hold = async (key, ms) => { await p.keyboard.down(key); await p.waitForTimeout(ms); await p.keyboard.up(key); };
  await hold('w', 3500); await shot('04_walk');
  const steps = process.argv[3] ? require(require('path').resolve(process.argv[3])) : null;
  if (steps) await steps(p, shot, hold);
  await b.close();
})();

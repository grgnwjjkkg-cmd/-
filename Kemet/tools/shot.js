// 使い方: node tools/shot.js <page> <out.png> [w] [h]
const { chromium } = require('playwright');
(async () => {
  const [page, out, w = 1200, h = 500] = process.argv.slice(2);
  const b = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await b.newPage({ viewport: { width: +w, height: +h } });
  p.on('pageerror', e => console.log('ERR', e.message)); p.on('console', m => { if (/error|Error/.test(m.text())) console.log('console:', m.text()); });
  await p.goto('http://localhost:8811/' + page);
  await p.waitForFunction(() => window.DONE === true, null, { timeout: 120000 });
  await p.screenshot({ path: out });
  await b.close();
})();

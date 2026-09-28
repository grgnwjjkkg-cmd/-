// 使い方（Kemet/ で）：
//   tools/fetch_assets.sh
//   npx http-server -p 8811 -s . &
//   NODE_PATH=$(npm root -g) node tools/build_assets.js [chars|anims|weapons]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const OUT = path.join(__dirname, '../Game/assets');
(async () => {
  const b = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await b.newPage();
  p.on('console', m => { if (!/THREE\.|404/.test(m.text())) console.log('page:', m.text()); });
  p.on('pageerror', e => console.log('ERR', e.message));
  await p.goto('http://localhost:8811/tools/build_assets.html');
  await p.waitForFunction(() => window.READY === true, null, { timeout: 60000 });
  const files = await p.evaluate(w => window.buildAll(w), process.argv[2] || null);
  for (const [name, b64] of Object.entries(files)) {
    const file = path.join(OUT, name);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    const buf = Buffer.from(b64, 'base64');
    fs.writeFileSync(file, buf);
    console.log(name, Math.round(buf.length / 1024), 'KB');
  }
  await b.close();
})();

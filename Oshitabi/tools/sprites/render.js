// 使い方: ./fetch_assets.sh を一度実行してから
//   npx http-server -p 8799 -s . &   （このフォルダで）
//   NODE_PATH=$(npm root -g) node render.js [id ...]
// → ../../Oshitabi/Resources/Sprites/<id>/ に webp を書き出す
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const OUT = path.join(__dirname, '../../Oshitabi/Resources/Sprites');
(async () => {
  const b = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const p = await b.newPage();
  p.on('pageerror', e => console.log('ERR', e.message));
  await p.goto('http://localhost:8799/render.html');
  await p.waitForFunction(() => window.READY === true, null, { timeout: 60000 });
  const ids = process.argv.slice(2).length ? process.argv.slice(2) : await p.evaluate(() => window.IDS);
  for (const id of ids) {
    const files = await p.evaluate(id => window.renderOne(id), id);
    const dir = path.join(OUT, id); fs.mkdirSync(dir, { recursive: true });
    let bytes = 0;
    for (const [name, url] of Object.entries(files)) {
      const buf = Buffer.from(url.split(',')[1], 'base64'); bytes += buf.length;
      fs.writeFileSync(path.join(dir, name), buf);
    }
    console.log(id, Object.keys(files).length, 'files', Math.round(bytes / 1024), 'KB');
  }
  await b.close();
})();

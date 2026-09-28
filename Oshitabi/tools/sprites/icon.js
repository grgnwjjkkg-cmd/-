const { chromium } = require('playwright'); const fs = require('fs'), path = require('path');
(async () => {
  const b = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const p = await b.newPage(); await p.goto('http://localhost:8799/render.html');
  await p.waitForFunction(() => window.READY === true);
  const url = await p.evaluate(() => window.renderIcon('mio'));
  fs.writeFileSync(path.join(__dirname, '../../Oshitabi/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png'), Buffer.from(url.split(',')[1], 'base64'));
  await b.close();
})();

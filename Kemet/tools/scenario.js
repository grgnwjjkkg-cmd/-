// 第1章をひととおり進めながら撮影する
module.exports = async (p, shot, hold) => {
  const tp = (x, z, face = 0) => p.evaluate(([x, z, f]) => { const g = window.game; g.player.pos.set(x, 0, z); g.player.face = f; g.camYaw = f + Math.PI; }, [x, z, face]);
  const talkAll = async (name, max = 14) => {
    await p.keyboard.press('e'); await p.waitForTimeout(700); await shot(name);
    for (let i = 0; i < max; i++) {
      const open = await p.evaluate(() => !document.getElementById('dialog').classList.contains('hidden'));
      if (!open) break;
      const choice = await p.$('#dlgChoices button');
      if (choice) await choice.click(); else await p.mouse.click(466, 400);
      await p.waitForTimeout(350);
    }
  };
  // 神官長
  await tp(0, -48, Math.PI); await p.waitForTimeout(600); await shot('05_temple'); await tp(0, -51.5, Math.PI);
  await talkAll('06_nefer');
  // 菓子→少年
  await tp(8.6, 5, Math.PI / 2); await talkAll('07_tawi');
  await tp(-5, 11.5, Math.PI); await talkAll('08_amen');
  // 漁師
  await tp(39, 1.5, Math.PI / 2); await p.waitForTimeout(500); await talkAll('09_seti');
  // ガチャ
  await p.evaluate(() => { window.game.save.ankh += 1000; window.game.refreshHUD(); });
  await tp(6, -24, Math.PI); await p.keyboard.press('e'); await p.waitForTimeout(600); await shot('10_gacha');
  await p.click('#g10'); await p.waitForTimeout(2600); await shot('11_gacha_result');
  await p.evaluate(() => window.game.closePanel());
  // 装備
  await p.evaluate(() => { const g = window.game; g.addItem('khopesh'); g.save.weapon = 'khopesh'; g.equipVisual(); });
  await p.evaluate(() => window.game.openMenu('equip')); await p.waitForTimeout(500); await shot('12_equip');
  await p.evaluate(() => window.game.closePanel());
  // 衛兵
  await tp(-42.5, 3.5, -Math.PI / 2); await talkAll('13_kash');
  await p.evaluate(() => window.game.enterZone('necropolis', false, 'town')); await p.waitForTimeout(2500); await shot('14_necropolis');
  // 盗賊と戦う
  await p.evaluate(() => { const g = window.game; g.player.pos.set(-2, 0, 17); g.player.face = Math.PI; g.camYaw = 0; });
  await p.waitForTimeout(1200); await shot('15_bandits');
  for (let i = 0; i < 8; i++) { await p.keyboard.press('j'); await p.waitForTimeout(700); }
  await shot('16_fight');
  // 墓の中
  await p.evaluate(() => { const g = window.game; g.player.pos.set(0, 0, -45); g.player.face = Math.PI; g.camYaw = 0; g.player.hp = 999; });
  await p.waitForTimeout(1800); await shot('17_tomb');
  await p.evaluate(() => { const g = window.game; g.player.pos.set(24, 0, -76); g.player.face = Math.PI; g.camYaw = 0; });
  await p.waitForTimeout(1500); await shot('18_hall');
  await p.evaluate(() => { const g = window.game; g.player.pos.set(25, 0, -106); g.player.face = Math.PI; g.camYaw = 0; });
  await p.waitForTimeout(1500); await shot('19_boss');
};

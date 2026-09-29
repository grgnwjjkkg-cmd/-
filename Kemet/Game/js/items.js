// 武器・お守り・ガチャ（神託の壺）

export const RARITY = {
  3: { label: '★3', color: '#8ec5ff' },
  4: { label: '★4', color: '#c78bff' },
  5: { label: '★5', color: '#ffcf4a' },
};

// model：assets/weapons/<model>.glb、tint：色（エジプトらしく青銅・金に）
export const WEAPONS = {
  bronze_dagger: { name: '青銅の短剣', rarity: 3, model: 'Dagger', tint: '#d9a066', atk: 9, speed: 1.35, reach: 1.6, desc: '軽くて速い。手数で押す' },
  travel_sword:  { name: '旅人の剣', rarity: 3, model: 'Sword', tint: '#e8e2d4', atk: 12, speed: 1.0, reach: 2.0, desc: '扱いやすい片手剣' },
  fisher_spear:  { name: '漁師の銛', rarity: 3, model: 'Spear', tint: '#d8c7a0', atk: 11, speed: 0.95, reach: 2.8, desc: 'リーチが長い' },
  hand_axe:      { name: '手斧', rarity: 3, model: 'Axe_Small', tint: '#e0d6c0', atk: 14, speed: 0.85, reach: 1.9, desc: '重い一撃' },
  khopesh:       { name: 'ケペシュ', rarity: 4, model: 'Sword_2', tint: '#e0a95a', atk: 17, speed: 1.1, reach: 2.1, crit: 0.1, desc: '古代エジプトの鎌形の剣。会心+10%' },
  war_axe:       { name: '戦斧', rarity: 4, model: 'Axe', tint: '#d0c4ae', atk: 22, speed: 0.75, reach: 2.2, desc: '振りは遅いが強烈' },
  mace:          { name: '大鎚', rarity: 4, model: 'Hammer_Small', tint: '#c9b7a0', atk: 21, speed: 0.8, reach: 2.0, stun: true, desc: '当てた敵をよろめかせる' },
  river_lance:   { name: 'ナイルの槍', rarity: 4, model: 'Spear', tint: '#6fc7d9', atk: 16, speed: 1.0, reach: 3.0, desc: '水の加護を受けた長槍' },
  ra_blade:      { name: '太陽剣ラー', rarity: 5, model: 'Sword_Golden', tint: '#ffd766', atk: 28, speed: 1.05, reach: 2.2, crit: 0.15, glow: '#ffb640', desc: '太陽の光を宿す黄金の剣' },
  seal_blade:    { name: '封印破りの剣', rarity: 4, model: 'Sword_Golden', tint: '#ffb08a', atk: 18, speed: 1.0, reach: 2.2, glow: '#ff5a2a', noGacha: true, desc: 'セトの封印を砕く、赤く光る剣' },
  anubis_scythe: { name: '冥府の大鎌', rarity: 5, model: 'Scythe', tint: '#9aa0c8', atk: 26, speed: 0.9, reach: 3.0, drain: 0.1, glow: '#8a7bff', desc: '与えたダメージの10%を回復' },
};

export const AMULETS = {
  scarab_charm: { name: 'スカラベのお守り', rarity: 3, hp: 15, desc: '最大HP+15' },
  lotus_charm:  { name: '蓮の花のお守り', rarity: 3, regen: 1, desc: '毎秒HPが1回復' },
  feather_charm:{ name: 'マアトの羽', rarity: 3, speed: 0.08, desc: '移動が8%速い' },
  eye_charm:    { name: 'ウアジェトの目', rarity: 4, crit: 0.12, desc: '会心率+12%' },
  ankh_charm:   { name: 'アンクの首飾り', rarity: 4, hp: 40, desc: '最大HP+40' },
  sun_disk:     { name: '太陽円盤', rarity: 5, atkMul: 0.18, desc: '攻撃力+18%' },
  horus_eye:    { name: 'ホルスの眼', rarity: 5, noGacha: true, hp: 30, crit: 0.1, desc: '大ピラミッドの秘宝。最大HP+30・会心率+10%' },
};

export function itemDef(id) {
  return WEAPONS[id] ? { kind: 'weapon', ...WEAPONS[id] } : AMULETS[id] ? { kind: 'amulet', ...AMULETS[id] } : null;
}

// ---------- ガチャ ----------

export const GACHA = {
  name: '神託の壺',
  cost1: 100,
  cost10: 900,
  rates: { 5: 0.03, 4: 0.17, 3: 0.8 },
  /** この回数引いて★5が出なければ、次は必ず★5（天井） */
  pity: 60,
};

const pool = rarity => [
  ...Object.keys(WEAPONS).filter(k => WEAPONS[k].rarity === rarity && !WEAPONS[k].noGacha),
  ...Object.keys(AMULETS).filter(k => AMULETS[k].rarity === rarity && !AMULETS[k].noGacha),
];

/** 1回引く。state.pityCount を更新する */
export function pull(state, random = Math.random, forceMin = 3) {
  state.pityCount = (state.pityCount || 0) + 1;
  let rarity;
  if (state.pityCount >= GACHA.pity) rarity = 5;
  else {
    const r = random();
    rarity = r < GACHA.rates[5] ? 5 : r < GACHA.rates[5] + GACHA.rates[4] ? 4 : 3;
  }
  rarity = Math.max(rarity, forceMin);
  if (rarity === 5) state.pityCount = 0;
  const list = pool(rarity);
  return list[Math.floor(random() * list.length)];
}

/** 10連：最後の1回は★4以上が確定 */
export function pull10(state, random = Math.random) {
  const out = [];
  for (let i = 0; i < 10; i++) out.push(pull(state, random, i === 9 && !out.some(id => itemDef(id).rarity >= 4) ? 4 : 3));
  return out;
}

/** 表示用の一覧（確率つき） */
export function gachaTable() {
  const rows = [];
  for (const rarity of [5, 4, 3]) {
    const list = pool(rarity);
    for (const id of list) rows.push({ id, rarity, rate: GACHA.rates[rarity] / list.length });
  }
  return rows;
}

// ---------- 強さの計算 ----------

/** 装備とレベルからプレイヤーの能力を出す。refine：同じものを重ねた強化段階 */
export function playerStats(save) {
  const lv = save.level;
  const s = { maxHP: 90 + lv * 10, atk: 0, speedMul: 1, crit: 0.05, regen: 0, drain: 0, reach: 1.2, attackSpeed: 1, stun: false, glow: null };
  const w = save.weapon && WEAPONS[save.weapon];
  const refine = id => Math.min(5, (save.inventory[id] || 1) - 1);
  if (w) {
    s.atk = Math.round(w.atk * (1 + 0.08 * refine(save.weapon)) + lv * 1.5);
    s.reach = w.reach; s.attackSpeed = w.speed; s.crit += w.crit || 0; s.drain = w.drain || 0; s.stun = !!w.stun; s.glow = w.glow || null;
  } else {
    s.atk = 4 + lv; // 素手
  }
  let atkMul = 1;
  for (const id of save.amulets) {
    const a = id && AMULETS[id];
    if (!a) continue;
    const k = 1 + 0.1 * refine(id);
    s.maxHP += Math.round((a.hp || 0) * k);
    s.regen += (a.regen || 0) * k;
    s.speedMul += (a.speed || 0) * k;
    s.crit += (a.crit || 0) * k;
    atkMul += (a.atkMul || 0) * k;
  }
  s.atk = Math.round(s.atk * atkMul);
  return s;
}

export const expToNext = lv => 40 + lv * 25;

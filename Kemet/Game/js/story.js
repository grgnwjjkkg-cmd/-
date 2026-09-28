// 第1章「盗まれた太陽のスカラベ」：登場人物・会話・目的
// 会話は「手順」の配列。{ who, text } … セリフ / { choice: [{ label, steps }] } … 選択肢 / { run: g => {} } … 処理

const say = (who, text) => ({ who, text });
const run = fn => ({ run: fn });

export const PEOPLE = {
  player: { name: 'あなた' },
  nefer: { name: 'ネフェル', title: '神官長' },
  amen:  { name: 'アメン', title: '市場の少年' },
  tawi:  { name: 'タウィ', title: '菓子売り' },
  hatra: { name: 'ハトラ', title: '武器商人' },
  seti:  { name: 'セティ', title: '漁師' },
  kash:  { name: 'カシュ', title: '西門の衛兵' },
  kem:   { name: 'ケム', title: '老学者' },
};

// 町にいる人（model は assets/chars/<model>.glb、anim は待機の動き）
export const TOWN_NPCS = [
  { id: 'nefer', model: 'nefer', pos: [0, -54], face: 0, anim: 'Idle_Talking_Loop' },
  { id: 'amen', model: 'amen', pos: [-5, 9], face: 2.5, anim: 'Idle_Loop', scale: 0.78 },
  { id: 'tawi', model: 'tawi', pos: [11, 5], face: -1.6, anim: 'Idle_Loop' },
  { id: 'hatra', model: 'hatra', pos: [-12, -7], face: 1.6, anim: 'Idle_Talking_Loop' },
  { id: 'seti', model: 'seti', pos: [41, 1], face: -1.4, anim: 'Sitting_Idle_Loop', sit: true },
  { id: 'kash', model: 'kash', pos: [-45, 3.5], face: 1.57, anim: 'Sword_Idle' },
  { id: 'kem', model: 'kem', pos: [-22, -22], face: 0.6, anim: 'Idle_Loop' },
];

/** 今やること（画面上部に出す） */
export function objective(s) {
  const f = s.flags;
  if (f.chapterClear) return '第1章クリア！ 町を自由に歩いてみよう';
  if (f.gotScarab) return 'スカラベを神殿のネフェルに届けよう';
  if (f.gateOpen) return '西岸の墓地の奥へ。盗賊団を追え';
  if (f.clueCloth) return s.weapon ? '西門の衛兵カシュに話そう' : '武器を手に入れて西門へ（ハトラの店・神託の壺）';
  if (f.clueDocks) return '船着き場の漁師セティに話を聞こう';
  if (f.metNefer) return f.hasCandy ? 'お菓子を市場の少年アメンに渡そう' : '市場で聞き込みをしよう';
  return '神殿の神官長ネフェルに会いに行こう（北）';
}

/** ヒント帳に書かれる手がかり */
export const CLUES = {
  redSand: { title: '赤い砂', text: '犯人は神殿に赤い砂を落としていった。赤い砂は西岸の砂漠にしかない。' },
  docks: { title: 'フードの男', text: '祭りの夜、フードをかぶった男が包みを抱えて船着き場へ走っていった。（アメン）' },
  cloth: { title: 'ジャッカルの布', text: 'フードの男は西岸へ渡った。落とした布には黒いジャッカルの紋章。盗賊団「黒ジャッカル」の印だ。（セティ）' },
  twoScarabs: { title: '対のスカラベ', text: '太陽のスカラベは、本来「月のスカラベ」と対になっていたという言い伝えがある。（ケム）' },
};

export function script(id, s) {
  const f = s.flags;
  switch (id) {
    case 'nefer':
      if (f.chapterClear) return [say('nefer', 'スカラベが戻り、祭りも再開できました。本当にありがとう。'), say('nefer', '……ただ、ケム先生が気になることを言っていましたね。')];
      if (f.gotScarab) return [
        say('nefer', 'それは……太陽のスカラベ！ 取り戻してくれたのですね！'),
        say('nefer', 'メンネフェルを代表してお礼を。これは神殿からの報酬です。'),
        run(g => { g.setFlag('chapterClear'); g.giveAnkh(1000); g.takeItem('scarab'); g.giveExp(200); }),
        say('nefer', '……でも、盗賊はなぜスカラベを「1つだけ」盗んだのでしょう。'),
        run(g => g.chapterClear()),
      ];
      if (f.metNefer) return [say('nefer', '手がかりは見つかりましたか？ 市場や船着き場の人たちなら、何か見ているかもしれません。')];
      return [
        say('nefer', 'あなたが噂の宝探し屋さんですね。来てくれて助かりました。'),
        say('nefer', '祭りの夜、この神殿から秘宝「太陽のスカラベ」が盗まれたのです。'),
        say('nefer', '犯人が残したのは、この赤い砂だけ。赤い砂は……ナイルの西岸にしかありません。'),
        { choice: [
          { label: '任せてください', steps: [say('player', '任せてください。必ず取り戻します。')] },
          { label: '報酬は？', steps: [say('player', '……報酬は出ますか？'), say('nefer', 'ふふ、もちろん。取り戻してくれたら神殿から十分なお礼を。')] },
        ] },
        say('nefer', 'これは調査のための費用です。町の人に話を聞いてみてください。'),
        run(g => { g.setFlag('metNefer'); g.addClue('redSand'); g.giveAnkh(300); }),
      ];

    case 'amen':
      if (f.clueDocks) return [say('amen', 'フードの男、船着き場のほうへ走っていったよ！ 漁師のセティおじさんなら何か知ってるかも。')];
      if (!f.metNefer) return [say('amen', 'お祭り、途中で終わっちゃったんだ。神殿で何かあったみたい。')];
      if (f.hasCandy) return [
        say('amen', 'わあ、デーツの蜜菓子！ くれるの？'),
        run(g => { g.takeItem('candy'); g.setFlag('hasCandy', false); }),
        say('amen', '……じゃあ教えてあげる。お祭りの夜、フードをかぶった男が包みを抱えて走っていったんだ。'),
        say('amen', '船着き場のほうだったよ。すっごく急いでた。'),
        run(g => { g.setFlag('clueDocks'); g.addClue('docks'); }),
      ];
      return [
        say('amen', 'お祭りの夜のこと？ ……知ってるけど、タダじゃ教えないよ。'),
        say('amen', 'タウィおばさんのデーツの蜜菓子、食べたいなあ。'),
      ];

    case 'tawi':
      return [
        say('tawi', 'いらっしゃい！ デーツの蜜菓子、1つ10アンクだよ。'),
        { choice: [
          { label: '1つ買う（10アンク）', steps: [run(g => g.buyCandy())] },
          { label: '武器はどこで？', steps: [say('tawi', '武器ならハトラの店だね。市場の西側さ。神殿の前の「神託の壺」で運試しする人も多いよ。')] },
          { label: 'やめておく', steps: [say('tawi', 'また来てね！')] },
        ] },
      ];

    case 'hatra':
      return [
        say('hatra', 'よう、宝探し屋。丸腰で西岸に行くつもりじゃないだろうな？'),
        { choice: [
          { label: '武器を見せて', steps: [run(g => g.openShop())] },
          { label: '神託の壺って？', steps: [
            say('hatra', '神殿の前の大きな壺さ。アンクを納めると、神々が武器やお守りを授けてくださる。'),
            say('hatra', '何が出るかは運次第。ただし、確率はちゃんと壺に刻まれてるぜ。'),
          ] },
          { label: 'またあとで', steps: [say('hatra', '死ぬなよ。')] },
        ] },
      ];

    case 'seti':
      if (f.clueCloth) return [say('seti', '黒ジャッカルの連中は西岸の墓地に巣くってる。西門から行けるが、気をつけな。')];
      if (!f.clueDocks) return [say('seti', '今日はナイルの機嫌がいい。魚もよく跳ねる。')];
      return [
        say('seti', 'フードの男？ ……ああ、祭りの夜に舟を出せと脅されたよ。'),
        say('seti', '西岸まで渡してやった。降りるとき、こいつを落としていった。'),
        say('seti', '黒いジャッカルの紋章……盗賊団「黒ジャッカル」の印だ。やつらは西岸の古い墓地をねぐらにしてる。'),
        say('seti', '墓地へは西門から陸路で行ける。衛兵のカシュに話してみな。'),
        run(g => { g.setFlag('clueCloth'); g.addClue('cloth'); }),
      ];

    case 'kash':
      if (f.gateOpen) return [say('kash', '門は開けてある。無事に帰ってこいよ。')];
      if (!f.clueCloth) return [say('kash', 'ここから先は死者の町だ。用のない者は通せない。')];
      if (!s.weapon) return [say('kash', '黒ジャッカルを追う？ 丸腰でか？ 武器を装備してから来い。'), say('kash', '武器ならハトラの店か、神殿前の神託の壺だ。')];
      return [
        say('kash', 'その武器……本気のようだな。いいだろう。'),
        say('kash', '墓地の奥にはミイラどもがうろついている。倒れそうになったら引き返せ。'),
        run(g => { g.setFlag('gateOpen'); g.openGate(); }),
      ];

    case 'kem':
      if (f.clueTwo) return [say('kem', '対のスカラベ……月のスカラベは、いまどこにあるのやら。')];
      return [
        say('kem', 'ふむ、太陽のスカラベが盗まれたそうじゃな。'),
        say('kem', '古い記録によれば、あれはもともと「月のスカラベ」と対になっておったらしい。'),
        say('kem', '2つがそろうとき、何かが開く……と書かれておるが、詳しいことは分からん。'),
        run(g => { g.setFlag('clueTwo'); g.addClue('twoScarabs'); }),
      ];
  }
  return [say(id, '……')];
}

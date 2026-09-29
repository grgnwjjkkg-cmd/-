// 第1章「盗まれた太陽のスカラベ」：登場人物・会話・目的
// 会話は「手順」の配列。{ who, text } … セリフ / { choice: [{ label, steps }] } … 選択肢 / { run: g => {} } … 処理

const say = (who, text) => ({ who, text });
const run = fn => ({ run: fn });

export const PEOPLE = {
  player: { name: 'あなた' },
  nefer: { name: 'メリト', title: '神官長' },
  amen:  { name: 'アメン', title: '市場の少年' },
  tawi:  { name: 'タウィ', title: '菓子売り' },
  hatra: { name: 'ハトラ', title: '武器商人' },
  seti:  { name: 'セティ', title: '漁師' },
  kash:  { name: 'カシュ', title: '西門の衛兵' },
  kem:   { name: 'ケム', title: '老学者' },
  // 東京（時の止まった夜の街で、なぜか動ける人たち。戦いには巻きこまれない）
  tk_prof: { name: '佐伯', title: '考古学者' },
  tk_reporter: { name: 'ミオ', title: '記者' },
  tk_tourist: { name: 'ルーカス', title: '旅行者' },
  tk_guard: { name: '大森', title: '駅の警備員' },
};

// 町にいる人（model は assets/chars/<model>.glb、anim は待機の動き）
export const TOWN_NPCS = [
  { id: 'nefer', model: 'human_nefer', pos: [0, -54], face: 0, anim: 'Idle_Talking_Loop' },
  { id: 'amen', model: 'human_amen', pos: [-5, 9], face: 2.5, anim: 'Idle_Loop' },
  { id: 'tawi', model: 'human_tawi', pos: [11, 5], face: -1.6, anim: 'Idle_Loop' },
  { id: 'hatra', model: 'human_hatra', pos: [-12, -7], face: 1.6, anim: 'Idle_Talking_Loop' },
  { id: 'seti', model: 'human_seti', pos: [41, 1], face: -1.4, anim: 'Sitting_Idle_Loop', sit: true },
  { id: 'kash', model: 'human_kash', pos: [-45, 3.5], face: 1.57, anim: 'Sword_Idle' },
  { id: 'kem', model: 'human_kem', pos: [-22, -22], face: 0.6, anim: 'Idle_Loop' },
];

// 東京にいる人（安全な場所：歩道の角や屋上）
export const TOKYO_NPCS = [
  { id: 'tk_prof', model: 'human_tk_prof', pos: [-6, 12.5], face: Math.PI, anim: 'Idle_Loop', safe: true },
  { id: 'tk_reporter', model: 'human_tk_reporter', pos: [22, 22], face: -2.4, anim: 'Idle_Talking_Loop', safe: true },
  { id: 'tk_tourist', model: 'human_tk_tourist', pos: [-22, 21], face: 2.4, anim: 'Idle_Loop', safe: true },
  { id: 'tk_guard', model: 'human_tk_guard', pos: [4, 64], face: Math.PI, anim: 'Idle_Loop', safe: true },
];

/** 場所ごとの人 */
export const ZONE_NPCS = { town: TOWN_NPCS, tokyo: TOKYO_NPCS };

/** 探索で見つかる物（場所ごと） */
export const FINDS = {
  necropolis: [
    { id: 'tablet1', x: -24, z: 47, title: '石板のかけら（1/3）', text: '「……太陽は東の神殿に、月は西の墓に眠る……」' },
    { id: 'tablet2', x: 3.2, z: -68, title: '石板のかけら（2/3）', text: '「……ふたつのスカラベを合わせし者に、冥府の門は開かれる……」' },
    { id: 'tablet3', x: 30.5, z: -89, title: '石板のかけら（3/3）', text: '「……黒き山犬の群れは、月を求めて西の果てへ……」' },
  ],
  pyramid: [
    { id: 'pyr1', x: -47, z: 12, title: '封印の石板（地下の間）', text: '「王の眠りを乱す者よ。地の底、光の届かぬ所に最初の言葉を置く」' },
    { id: 'pyr2', x: 38, z: -30, title: '封印の石板（女王の間）', text: '「女王の壁のくぼみの奥に、名を消された部屋がある」' },
    { id: 'pyr3', x: 0, z: -71, title: '封印の石板（大回廊）', text: '「三つの言葉がそろうとき、花こう岩の扉は地に沈む。眼を取れば山は崩れる。走れ」' },
  ],
};

/** 今やること（画面上部に出す） */
export function objective(s) {
  const f = s.flags;
  if (f.pyrEscaped) return '第2章クリア！ ギザの「太陽の門」が開いた。天空都市へ';
  if (f.chapterClear) return '第2章：ギザの大ピラミッドへ（墓地から西の道の先）。ケムに話を聞くのもよい';
  if (f.gotScarab) return 'スカラベを神殿のメリトに届けよう';
  if (f.gateOpen) return '西岸の墓地の奥へ。盗賊団を追え';
  if (f.clueCloth) return s.weapon ? '西門の衛兵カシュに話そう' : '武器を手に入れて西門へ（ハトラの店・神託の壺）';
  if (f.clueDocks) return '船着き場の漁師セティに話を聞こう';
  if (f.metNefer) return f.hasCandy ? 'お菓子を市場の少年アメンに渡そう' : '市場で聞き込みをしよう';
  return '神殿の神官長メリトに会いに行こう（北）';
}

/** ヒント帳に書かれる手がかり */
export const CLUES = {
  redSand: { title: '赤い砂', text: '犯人は神殿に赤い砂を落としていった。赤い砂は西岸の砂漠にしかない。' },
  docks: { title: 'フードの男', text: '祭りの夜、フードをかぶった男が包みを抱えて船着き場へ走っていった。（アメン）' },
  cloth: { title: 'ジャッカルの布', text: 'フードの男は西岸へ渡った。落とした布には黒いジャッカルの紋章。盗賊団「黒ジャッカル」の印だ。（セティ）' },
  tablet: { title: '石板の言葉', text: '「ふたつのスカラベを合わせし者に、冥府の門は開かれる」。黒ジャッカルは月のスカラベも狙っている？' },
  secrets: { title: '墓地の秘密', text: '柱の広間の鏡で日の光を北の壁の太陽円盤へ。町と墓地に黄金のスカラベが5つ。（ケム）' },
  sealOrder: { title: 'セトの封印', text: '「日が沈み、月が昇り、星がまたたくとき」――封印は ☀ → ☾ → ✦ の順に斬る。（盗賊団の間の碑文）' },
  twoScarabs: { title: '対のスカラベ', text: '太陽のスカラベは、本来「月のスカラベ」と対になっていたという言い伝えがある。（ケム）' },
};

export function script(id, s) {
  const f = s.flags;
  switch (id) {
    case 'tk_guard':
      if (f.tkGuard) return [say('tk_guard', '気をつけてな。影の化け物は、光る遺跡から出てくるみたいだ。')];
      return [
        say('tk_guard', 'おっと、君も動けるのか！ 夜中の0時ちょうどに、街じゅうの時間が止まってしまったんだ。'),
        say('tk_guard', '交差点の真ん中に、いきなりオベリスクが生えてきてね。そこから黒い影があふれてる。'),
        say('tk_guard', 'ここは駅の入口だから、影も近寄ってこない。困ったら戻っておいで。'),
        run(g => { g.setFlag('tkGuard'); g.giveAnkh(50); }),
      ];
    case 'tk_prof':
      if (f.tkProf) return [say('tk_prof', 'オベリスクの頂の金は「ベンベン石」をかたどったものだ。太陽が最初に降り立つ場所だよ。')];
      return [
        say('tk_prof', '……信じられん。これは本物だ。ヘリオポリスのオベリスクと同じ様式だよ。'),
        say('tk_prof', '君、エジプトから来たのかね？ その服……まるで壁画から抜け出してきたようだ。'),
        say('tk_prof', '碑文によると、「空の門」が開くたびに、ふたつの時代が重なるらしい。'),
        say('tk_prof', '北西のビルの屋上に、何か光る物が見えた。低い屋根から順に跳んでいけば届くはずだ。'),
        run(g => { g.setFlag('tkProf'); g.giveExp(40); }),
      ];
    case 'tk_reporter':
      if (f.tkReporter) return [say('tk_reporter', '写真はばっちり！ ……でも誰も信じてくれないだろうなあ。')];
      return [
        say('tk_reporter', 'スクープの予感！ ……って、あなたも止まってないの？'),
        say('tk_reporter', '取材メモ：影の化け物は、攻撃の直前に体がぼうっと光る。'),
        say('tk_reporter', 'そのしゅんかんに横へ飛べば、周りの時間がゆっくりになる……って、あなたなら分かるよね？'),
        run(g => { g.setFlag('tkReporter'); g.giveAnkh(80); }),
      ];
    case 'tk_tourist':
      if (f.tkTourist) return [say('tk_tourist', '南東の店の裏にも何かあったよ。ボクは怖くて近づけなかったけど。')];
      return [
        say('tk_tourist', 'やあ！ 東京観光に来たら、とんでもない夜になっちゃったよ。'),
        say('tk_tourist', '南東の角の店のあたりで、金色の箱を見たんだ。きっと宝箱だよね？'),
        say('tk_tourist', 'あと、帰り道は南の端の光る門だよ。ボクもあそこから来た……気がする。'),
        run(g => { g.setFlag('tkTourist'); }),
      ];

    case 'nefer':
      if (f.chapterClear) return [say('nefer', 'スカラベが戻り、祭りも再開できました。本当にありがとう。'), say('nefer', '……ただ、ケム先生が気になることを言っていましたね。')];
      if (f.gotScarab) return [
        say('nefer', 'それは……太陽のスカラベ！ 取り戻してくれたのですね！'),
        say('nefer', 'メンメリトを代表してお礼を。これは神殿からの報酬です。'),
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
      if (f.chapterClear) return [
        say('seti', 'ところで……この船着き場の先、河口の海の底に、昔の神殿の町が沈んでるって話を知ってるか？'),
        say('seti', '潜った仲間が、倒れた巨像を見たそうだ。船着き場の先から行ける。息が続くならな。'),
      ];
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
      if (f.pyrEscaped) return [say('kem', 'ホルスの眼を持ち帰ったとな！ ……ギザの「太陽の門」が光っておった。天へ通じる門だという言い伝えじゃ。')];
      if (f.chapterClear) return [
        say('kem', '月のスカラベの手がかりじゃが……ギザの大ピラミッドの奥に、封印された王の間があるという。'),
        say('kem', '墓地から西へ続く道の先がギザじゃ。中の石板を3つ集めれば、封印が解けるそうじゃ。'),
      ];
      if (f.clueTwo && !f.kemSecrets) return [
        say('kem', 'そうそう、墓地にはまだ秘密があるぞ。'),
        say('kem', '柱の広間には、天井の穴から差す日の光を運ぶ「鏡」が残っておる。光を北の壁の太陽円盤へ届ければ……さて、何が起こるかの。'),
        say('kem', 'それから、町と墓地には「黄金のスカラベ」が5つ隠されておるそうじゃ。全部集めた者には幸運が訪れるとか。'),
        run(g => { g.setFlag('kemSecrets'); g.addClue('secrets'); }),
      ];
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

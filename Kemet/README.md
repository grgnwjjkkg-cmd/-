# ケメトの秘宝（仮）

古代エジプトの町を3Dで歩き回り、盗まれた秘宝の手がかりを集める探索アクションRPG。設計は `DESIGN.md`。

## Mac で動かす
```
cd ~/kemet
open Kemet.xcodeproj
```
Xcode で Team を選んで ▶。iPhone は横向きで遊びます。

## パソコンのブラウザで試す
```
cd ~/kemet
npx http-server -p 8811 -s .
```
ブラウザで http://localhost:8811/Game/index.html を開く。W/A/S/D で移動、J で攻撃、K で回避、E で話す。

## フォルダ
- `Game/` … ゲーム本体（three.js）。`js/story.js` が会話と物語、`js/items.js` が武器・お守り・ガチャ
- `App/` … iPhone アプリ（WebView でゲームを動かすだけ）
- `tools/` … 無料素材をゲーム用に変換するスクリプトと、自動プレイのテスト

## 場所（地図）
| 名前 | 台本 | 中身 |
|---|---|---|
| 町 | `tools/bake/town.py` | 市場・神殿・船着き場（船着き場の先から海中遺跡へ） |
| 西岸の墓地 | `tools/bake/necropolis.py` | 巨像が守る岩の墓、水没した柱の広間、洞窟、盗賊団の間（西の道はギザへ） |
| ギザの台地 | `tools/bake/giza.py` | 段々に積まれた大ピラミッド、石の墓の通り、太陽の門 |
| 大ピラミッドの中 | `tools/bake/pyramid.py` | 石板3つ → 封印の扉が開く → 秘宝 → 崩れる前に脱出 |
| 海中遺跡 | `tools/bake/sunken.py` | 倒れた巨像と柱の海の底（光のゆらぎ・泡） |
| 天空都市 | `tools/bake/sky.py` | 雲の上に浮かぶ島々と太陽神殿 |

## 光のベイク（リアルな見た目）
Blender で光の跳ね返りを計算して、画像（ライトマップ）に焼き付けています（POOLS と同じ考え方）。
```
tools/fetch_libs.sh                                # three.js
python3 tools/fetch_polyhaven.py textures hdris    # 実写の石・砂・空（Poly Haven, CC0）
python3 tools/shrink_tex.py                        # アプリ用に画像を縮める
blender -b --python tools/bake/make_colossus.py    # 入口の巨像の形（MakeHuman が必要）
BLENDER=blender tools/bake/bake_all.sh 160         # 全部の場所の光を計算（1か所 20〜60分）
```
途中で止まったら `BAKE_RESUME=1` をつけると、終わった部分は計算し直しません。
出入口の位置だけ変えたときは `python3 tools/bake/patch_meta.py <場所>`（計算し直さなくてよい）。

## キャラ（MakeHuman で作るリアルな人）
```
blender -b --python tools/chars/make_human.py -- hero     # hero / nefer / kash / mummy ... は台本の CHARS
```
Blender に MPFB2（MakeHuman の拡張, CC0）と makehuman_system_assets を入れておく。
体つき・肌・髪・服（腰布・長い服・首飾り・腕輪・はちまき など）は `tools/chars/make_human.py` の `CHARS` に書く。
動きはゲームの共通アニメをそのまま使う（読み込むときに骨の向きを自動で合わせる）。
`Game/char_view.html?c=human_hero&a=Walk_Loop` で見た目と動きを確認できる。

## 差し替えるとき
- キャラ・武器：`Game/assets/chars/*.glb`・`Game/assets/weapons/*.glb` を入れ替える
- BGM：`js/audio.js`（今はコードで演奏。音楽ファイルに差し替え可能）

## 素材
3Dモデル・アニメーション：[Quaternius](https://quaternius.com)（CC0 1.0）
人の体：[MakeHuman / MPFB2](http://www.makehumancommunity.org)（CC0 1.0）
実写テクスチャ・空の写真：[Poly Haven](https://polyhaven.com)（CC0 1.0）

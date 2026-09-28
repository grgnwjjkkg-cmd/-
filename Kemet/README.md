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

## 差し替えるとき
- キャラ・武器：`Game/assets/chars/*.glb`・`Game/assets/weapons/*.glb` を入れ替える
- BGM：`js/audio.js`（今はコードで演奏。音楽ファイルに差し替え可能）

## 素材
3Dモデル・アニメーション：[Quaternius](https://quaternius.com)（CC0 1.0）

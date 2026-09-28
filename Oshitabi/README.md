# オシタビ（仮）

推しを1人決めると、アプリを閉じていても育つ。仲間のカードで戦うローグライク。

## 遊び方
- **推し**タブ：推しを眺める・タップで話しかける・放置でたまった経験値を受け取る（最大8時間ぶん）
- **冒険**タブ：3人のパーティで全8階の「影の回廊」へ。違うキャラのカードを続けて使うと**連携**でダメージが上がる
- **仲間**タブ：集めたキャラの一覧。強敵や影の王を倒すと新しい仲間が加わる

## Mac でのテスト
```
cd ~/oshitabi/Oshitabi
DEVICE=$(xcrun simctl list devices available | grep -m1 -o 'iPhone [^(]*' | sed 's/ *$//'); xcodebuild test -project Oshitabi.xcodeproj -scheme Oshitabi -destination "platform=iOS Simulator,name=$DEVICE" 2>&1 | grep -E "\.swift:[0-9]+: error|TEST SUCCEEDED|TEST FAILED|BUILD FAILED|Test Case .* failed" | head -30
```

## キャラ画像
`Oshitabi/Resources/Sprites/` の画像は、無料の3D素材を `tools/sprites/` のスクリプトで画像に変換したもの。
キャラを差し替えるときは `render.html` の `DEFS` を変えて、もう一度書き出す。

## 素材
- 3Dモデル・アニメーション：[Quaternius](https://quaternius.com)（Universal Base Characters / Modular Character Outfits - Fantasy / Universal Animation Library、CC0 1.0）

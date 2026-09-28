# 論文フィード（papers.json）の形式

アプリの「論文」タブは、論文要約サイトが配信する JSON を読み込んで表示します。
サイト側でこの形式の JSON を公開し、そのURLをアプリの「設定 → 論文データ」に入れると、
アプリを更新しなくても記事の追加がアプリに反映されます。

URLが未設定のあいだは、アプリに同梱したサンプル（`EviTrain/EviTrain/Resources/papers_sample.json`）が表示されます。

## 形式

```json
{
  "version": 1,
  "updatedAt": "2026-09-28",
  "papers": [
    {
      "id": "seitz-2014-strength-sprint",
      "title": "下半身の筋力アップは、足の速さの向上につながる",
      "originalTitle": "Increases in Lower-Body Strength Transfer Positively to Sprint Performance: ...",
      "authors": "Seitz LB, et al.",
      "journal": "Sports Medicine",
      "year": 2014,
      "doi": "10.1007/s40279-014-0227-1",
      "url": "https://（要約サイト）/papers/seitz-2014",
      "category": "スピード",
      "tags": ["スプリント", "筋力", "脚"],
      "studyType": "メタ分析",
      "summary": "要約本文",
      "keyPoints": ["ポイント1", "ポイント2"],
      "practical": "トレーニングへの活かし方"
    }
  ]
}
```

| 項目 | 必須 | 説明 |
|---|---|---|
| `id` | ✅ | 記事ごとに一意の文字列。ブックマークの保存に使うので、あとから変えない |
| `title` | ✅ | 日本語の見出し |
| `category` | ✅ | 論文タブの絞り込みに使う大分類（例: 筋肥大 / 筋力 / スピード / 栄養） |
| `tags` | ✅ | 種目とのひも付けに使う（空配列でも可） |
| `summary` | ✅ | 要約 |
| `keyPoints` | ✅ | 箇条書きのポイント（空配列でも可） |
| `originalTitle` `authors` `journal` `year` `doi` `url` `studyType` `practical` | − | あれば表示される |

## 種目とのひも付け（このアプリの特徴）

各種目にはタグが付いています（例: スクワット = 筋力・筋肥大・スプリント・パワー）。
論文の `tags` と `category`、種目のタグと部位名が一致するほど「関連が強い」とみなし、
種目の記録画面や履歴グラフの下に「この種目に関係する研究」として表示します。

アプリ側で使っているタグ:
`筋力` `筋肥大` `スプリント` `パワー` `加速` `最大速度` `ケガ予防` `体幹` `持久力`
および部位名 `胸` `背中` `脚` `肩` `腕` `体幹` `スプリント` `ジャンプ` `有酸素`

## 要約サイト（Next.js）で配信する例

`app/papers.json/route.ts` を作ると `https://（サイト）/papers.json` で配信できます。

```ts
import { getAllPapers } from "@/lib/papers"; // サイト側の記事取得処理に置き換える

export const revalidate = 3600; // 1時間ごとに再生成

export async function GET() {
  const papers = await getAllPapers();
  return Response.json({
    version: 1,
    updatedAt: new Date().toISOString().slice(0, 10),
    papers,
  });
}
```

## 注意

- サンプルの8本は実在する論文（DOIをCrossrefで確認済み）ですが、要約文は公開前に原著を読んで確認してください。
- 要約は「研究の紹介」であり、医学的な助言ではない旨をサイトとアプリの両方に表示しています。

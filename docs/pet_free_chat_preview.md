# ペット自由会話（preview）

## 構成

- `POST /v1/analyze`: Llama 4 Scoutを1回呼び、ペット有無・種類・姿勢・表情・推定気分をまとめて返す。既存フィールドは維持する。
- `POST /v1/chat`: Llama 3.1 8B fastで `greet`（話しかけ）、`reply`（返事）、`monologue`（独り言）を1〜2文で返す。
- 初回判定後は35〜55秒のランダム間隔で、長辺336pxのPNGを1枚だけ再解析する。端末内の動き検出時も前回観察から30秒未満なら実行しない。
- 姿勢キー・気分キーが変わらない場合、会話モデルは呼ばず何も表示しない。
- 会話履歴は最大20件（10往復相当）。人格設定は端末のSharedPreferencesへ保存する。
- WebはWeb Speech APIとspeechSynthesisを使用し、非対応時またはマイク長押しで文字入力へ切り替える。iOS/Androidは既存のMethodChannel音声認識を使う。

## API例

`POST /v1/chat`

```json
{
  "clientId": "匿名UUID",
  "kind": "reply",
  "message": "今日は何して遊ぶ？",
  "persona": {
    "petName": "こむぎ",
    "species": "犬",
    "preset": "甘えん坊",
    "firstPerson": "ぼく",
    "ending": "",
    "ownerCall": "ママ",
    "dialect": "標準語"
  },
  "state": {
    "pose": "横になっている",
    "mood": "眠いのかも",
    "expression": "目を細めている",
    "previousPose": "",
    "previousMood": ""
  },
  "history": []
}
```

```json
{"kind":"reply","utterance":"もう少しごろんとしたら、起きて遊ぶよ。"}
```

## 無料枠の概算

想定は1日あたり10分×3回。観察間隔の平均45秒として、定期観察は約13回/セッション（39回/日）になる。

| 処理 | 保守的な単価 | 1日の回数 | 概算 |
| --- | ---: | ---: | ---: |
| 初回Scout判定（最大3枚） | 21.2 neurons/枚 | 9枚 | 191 neurons |
| 定期Scout観察 | 21.2 neurons/回 | 39回 | 827 neurons |
| 8B会話（挨拶・返事・独り言） | 6 neurons/回 | 42回 | 252 neurons |
| 合計 |  |  | **約1,270 neurons/日** |

画像縮小前の実測値を定期観察にも当てた保守的な計算で、10,000 neurons/日の約13%。通信再試行や長い会話履歴を考慮して2倍の安全率を置いても約2,540 neurons/日。運用時はWorkers AIダッシュボードの実測を確認する。

## テスト

- Worker: `cd worker/pet-vision-api && npm test` で `/v1/chat` の検証（greet / reply / monologue のリクエスト検証、プロンプト内容、独り言の呼びかけ除去、健康断定の差し替えなど）を追加。
- Flutter: `flutter test` で `PetTalkAiService.chat()` の greet/monologue 送信、履歴トリム、不正エンドポイント時の null 返却を追加。

## previewデプロイ

本番へ反映せず、次だけを使用する。

```sh
cd worker/pet-vision-api
npx wrangler deploy --env preview

flutter build web --release \
  --dart-define=PET_TALK_AI_ENDPOINT=https://pet-talk-vision-api-preview.aqu-azure001.workers.dev/v1/analyze \
  --dart-define=PET_TALK_TEST_ADS=true

npx wrangler pages deploy build/web \
  --project-name pettalk-web \
  --branch pet-free-chat-preview
```

現在のpreview URL:

- Worker: `https://pet-talk-vision-api-preview.aqu-azure001.workers.dev`
- Pages: `https://pet-free-chat-preview.pettalk-web.pages.dev`

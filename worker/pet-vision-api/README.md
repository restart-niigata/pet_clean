# ぺっとーく画像判定API

Cloudflare Workers AIの画像理解モデルを使い、カメラ画像に実在する動物が
映っている場合だけ短い日本語コメントを返します。画像は保存しません。

## 開発

```bash
npm install
npm run cf-typegen
npm test
npm run typecheck
npm run dev
```

`POST /v1/analyze` にJPEGのBase64、選択した種類・性格・方言、端末ごとの
UUIDを送信します。公開APIのAI利用を抑えるため、UUID単位でレート制限します。

## デプロイ

```bash
npx wrangler login
npm run deploy
```

デプロイ後のURLをFlutterビルド時に指定します。

```bash
flutter run --release \
  --dart-define=PET_TALK_AI_ENDPOINT=https://<worker>.workers.dev/v1/analyze
```

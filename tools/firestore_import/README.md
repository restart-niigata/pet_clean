# Firestore コメント投入

`assets/comments.json` を、Firestore の `comment_groups` コレクションへ
「種類 × 性格」単位で投入します。通常実行は検証だけで、書き込みません。

```powershell
cd tools/firestore_import
npm install
npm run check
```

実際に書き込む前に、対象Firebaseプロジェクトを確認し、Application Default
Credentials または `GOOGLE_APPLICATION_CREDENTIALS` を設定します。

```powershell
$env:FIREBASE_PROJECT_ID = 'your-project-id'
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\secure\service-account.json'
npm run import
```

サービスアカウントJSONは機密情報なので、リポジトリへ追加しないでください。
アプリはオフラインでも利用できるよう、引き続き同じコメントをアセットにも保持します。

# ぺっとーく (pet_clean)

カメラに映したペットが、性格や方言に合わせてひとこと話すFlutterアプリです。

## Windows / Mac 共通の開発環境

Flutter `3.35.6` を基準にしています。FVMを使う場合は、リポジトリ直下の
`.fvmrc` から同じバージョンを導入できます。

```powershell
fvm install
fvm flutter pub get
fvm flutter run
```

FVMを使わない場合は、Flutter stableを用意して `flutter pub get`、
`flutter run` の順に実行します。`.gitattributes` でソースの改行コードを
LFに統一しているため、WindowsとMacを行き来しても不要な全行差分が出ません。
APIキー、Firebaseサービスアカウント、署名鍵はGitHubへ追加しないでください。

## AIコメント連携

AIコメントは、生成AIへ直接接続せず、自前のバックエンドを経由します。APIキーを
アプリに埋め込まないための構成です。バックエンドが未設定、または通信できない
場合は、従来の `assets/comments.json` に自動でフォールバックします。

起動時にバックエンドURLを指定します。

```powershell
flutter run --dart-define=PET_TALK_AI_ENDPOINT=https://example.com/api/pet-comment
```

アプリは次のJSONを `POST` します。飼い主名とペット名は送信しません。

```json
{
  "species": "犬",
  "personality": "元気",
  "dialect": "関西弁"
}
```

バックエンドは次の形式で、120文字以内の短いコメントを返してください。
`{owner}` と `{pet}` はレスポンス受信後、端末内で実際の名前に置換されます。

```json
{
  "comment": "{owner}、{pet}と今日も遊ぼな！"
}
```

本番環境ではHTTPSが必須です。ローカル開発時のみ `localhost` と `127.0.0.1`
へのHTTP接続を許可しています。失敗時は5分間AIへの再接続を止め、通信待ちが
繰り返されないようにしています。また、AIリクエストは最大でも1分に1回とし、
その間はローカルコメントを使います。

## 広告と同意

- 独自の利用規約への同意後に、Google UMP の同意状態を更新します。
- UMP が広告リクエストを許可した場合だけ Mobile Ads SDK を初期化します。
- バナーは画面幅に合うアンカー型アダプティブサイズを使用します。
- 全画面広告は起動時には表示せず、共有成功3回ごと、かつ前回表示から
  5分以上経過した自然な区切りでのみ表示します。
- デバッグビルドは Google のテスト広告ID、本番ビルドは本番広告IDを使います。
- UMP が求める地域では、メニューに「広告プライバシー設定」が表示されます。

## 公開前に必要な設定

次の値はプロジェクト所有者の情報が必要なため、公開前に確定してください。

1. Android の `applicationId`（現在は `com.example.pet_clean`）
2. iOS の `PRODUCT_BUNDLE_IDENTIFIER`（現在は `com.example.petClean`）
3. Android リリース用キーストアと署名設定（現在はデバッグ署名）
4. iOS の Apple Developer Team と配布署名
5. AdMob 管理画面での UMP メッセージ公開と、アプリID・広告ユニットの照合
6. 本番AIバックエンドURLと `PET_TALK_AI_ENDPOINT` のビルド時指定
7. Android/iOS実機で、同意・カメラ・共有・広告・通信失敗時フォールバックを確認

## Firestoreへのコメント投入

コメントはオフライン利用のため `assets/comments.json` に同梱しています。
Firestoreへ同じデータを管理用に投入する場合は、
`tools/firestore_import` のドライラン付きインポーターを使用します。
FirebaseプロジェクトIDと認証情報がない状態では、外部への書き込みは行いません。

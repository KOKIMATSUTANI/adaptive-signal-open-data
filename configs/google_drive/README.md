# Google Drive連携設定

## セットアップ手順

### 1. Google Cloud Consoleでプロジェクトを作成
1. [Google Cloud Console](https://console.cloud.google.com/)にアクセス
2. 新しいプロジェクトを作成
3. Google Drive APIを有効化

### 2. 認証情報を作成
1. 「認証情報」→「認証情報を作成」→「OAuth クライアント ID」
2. アプリケーションの種類: 「デスクトップアプリケーション」
3. 認証情報をダウンロードして`credentials.json`として保存

### 3. ファイル配置
```
configs/google_drive/
├── credentials.json  # Google Cloud Consoleからダウンロード
├── token.json        # 自動生成（初回認証後）
└── README.md         # このファイル
```

### 4. 初回認証
Dockerコンテナを実行すると、初回認証時にブラウザが開きます：
1. Googleアカウントでログイン
2. アプリケーションのアクセス許可
3. `token.json`が自動生成される

## 注意事項
- `credentials.json`は機密情報のため、Gitにコミットしないでください
- `token.json`も自動生成されるため、Gitにコミットしないでください
- 認証情報は定期的に更新が必要です

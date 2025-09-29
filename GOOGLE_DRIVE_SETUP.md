# Google Drive連携セットアップガイド

## 概要
Docker内の操作だけでGTFSデータをGoogle Driveに自動アップロードする機能を提供します。

## セットアップ手順

### 1. Google Cloud Console設定

#### プロジェクト作成
1. [Google Cloud Console](https://console.cloud.google.com/)にアクセス
2. 新しいプロジェクトを作成（例：`tram-gtfs-data`）
3. プロジェクトを選択

#### Google Drive API有効化
1. 「APIとサービス」→「ライブラリ」
2. 「Google Drive API」を検索
3. 「有効にする」をクリック

#### 認証情報作成
1. 「APIとサービス」→「認証情報」
2. 「認証情報を作成」→「OAuth クライアント ID」
3. アプリケーションの種類：「デスクトップアプリケーション」
4. 名前：`GTFS Data Uploader`
5. 「作成」をクリック
6. JSONファイルをダウンロード

### 2. 認証情報ファイル配置

```bash
# ダウンロードしたJSONファイルを配置
cp ~/Downloads/credentials.json configs/google_drive/
```

### 3. Docker実行

#### 初回認証
```bash
# 初回実行（認証が必要）
docker-compose up gtfs-ingest
```

初回実行時：
1. ブラウザが自動で開く
2. Googleアカウントでログイン
3. アプリケーションのアクセス許可
4. `token.json`が自動生成される

#### 通常実行
```bash
# 連続実行（20秒間隔でデータ取得→Google Driveアップロード）
docker-compose up gtfs-ingest

# または一回だけ実行
docker run --rm \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/configs/google_drive:/app/configs/google_drive \
  -e GOOGLE_DRIVE_ENABLED=true \
  tram-ingest:latest --feed-type all --once
```

## データ構造

### Google Drive上のフォルダ構造
```
Google Drive/
└── 2024-01-15/                    # 日付フォルダ
    └── GTFS_Data/                 # GTFSデータフォルダ
        ├── bronze/                # 生データ
        │   ├── gtfs_rt_trip_updates_20240115_143022.json
        │   └── gtfs_rt_vehicle_positions_20240115_143022.json
        ├── silver/                # 処理済みデータ
        └── raw/                   # 元データ
```

### アップロードされるファイル
- **GTFS-RTデータ**: JSON形式でタイムスタンプ付き
- **GTFS Staticデータ**: ZIP形式のまま
- **ログファイル**: 処理状況のログ

## トラブルシューティング

### 認証エラー
```bash
# 認証情報をリセット
rm configs/google_drive/token.json
docker-compose up gtfs-ingest
```

### 権限エラー
1. Google Cloud ConsoleでOAuth同意画面を設定
2. テストユーザーに自分のアカウントを追加

### アップロード失敗
```bash
# ログを確認
docker-compose logs gtfs-ingest

# 手動でアップロードテスト
docker run --rm \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/configs/google_drive:/app/configs/google_drive \
  tram-ingest:latest python -c "
from src.gtfs_pipeline.google_drive import GoogleDriveManager
from src.gtfs_pipeline.config import GTFSConfig
config = GTFSConfig()
manager = GoogleDriveManager(config)
manager.authenticate()
"
```

## セキュリティ注意事項

- `credentials.json`と`token.json`は機密情報
- Gitにコミットしない（`.gitignore`で除外済み）
- 定期的に認証情報を更新
- 必要最小限の権限のみ付与

## 自動化

### Cron設定例
```bash
# 毎時データ取得→Google Driveアップロード
0 * * * * cd /path/to/project && docker-compose up gtfs-ingest
```

### システムサービス化
```bash
# systemdサービスファイル作成
sudo nano /etc/systemd/system/gtfs-ingest.service
```

これで、Docker内の操作だけでGTFSデータをGoogle Driveに自動アップロードできます！

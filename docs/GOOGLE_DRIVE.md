# Google Drive連携

## 概要

GTFSデータをGoogle Driveに自動バックアップする機能です。rcloneまたはGoogle Drive APIを使用できます。

## 認証方法の選択

| 方法 | メリット | 用途 | 設定難易度 |
|------|----------|------|------------|
| **rclone** | 高機能、安定性、大量データ転送 | 本格運用 | ⭐⭐ |
| **Google Drive API** | 細かい制御、カスタム機能 | 開発・テスト | ⭐⭐⭐ |

## セットアップ

### 方法1: rclone（推奨）

#### 1. インストール
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install rclone

# macOS
brew install rclone

# Windows
# https://rclone.org/downloads/ からダウンロード
```

#### 2. 認証設定
```bash
rclone config
# n) New remote
# name> gdrive
# Storage> drive
# (その他はデフォルトでEnter)
# Use auto config?> Y
```

#### 3. 設定ファイル配置
```bash
cp ~/.config/rclone/rclone.conf ./configs/rclone/
```

#### 4. 動作確認
```bash
rclone lsd gdrive:
```

### 方法2: Google Drive API

#### 1. Google Cloud Console設定
1. [Google Cloud Console](https://console.cloud.google.com/)でプロジェクト作成
2. Google Drive API有効化
3. 認証情報作成（OAuth 2.0）
4. 認証情報をダウンロード

#### 2. 設定ファイル配置
```bash
# ダウンロードした認証情報を配置
cp ~/Downloads/credentials.json ./configs/google_drive/
```

#### 3. 初回認証
```bash
# 認証トークンを生成
python -c "
from src.gtfs_pipeline.google_drive import GoogleDriveManager
manager = GoogleDriveManager('./configs/google_drive')
"
```

## 使用方法

### rclone使用
```bash
# 自動バックアップ付きで実行
make run-ingest-rclone

# または直接Docker
docker run --rm \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/logs:/app/logs \
  -v $(pwd)/configs/rclone:/root/.config/rclone \
  -e RCLONE_ENABLED=true \
  tram-ingest:latest
```

### Google Drive API使用
```bash
# 自動バックアップ付きで実行
make run-ingest

# または直接Docker
docker run --rm \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/logs:/app/logs \
  -v $(pwd)/configs/google_drive:/app/configs/google_drive \
  -e GOOGLE_DRIVE_ENABLED=true \
  tram-ingest:latest
```

### バックアップなし
```bash
# バックアップ機能を無効化
make run-ingest-no-backup
```

## 設定

### 環境変数

| 変数名 | デフォルト値 | 説明 |
|--------|-------------|------|
| `RCLONE_ENABLED` | `false` | rclone自動バックアップの有効/無効 |
| `GOOGLE_DRIVE_ENABLED` | `false` | Google Drive API自動バックアップの有効/無効 |
| `BACKUP_INTERVAL` | `300` | バックアップ間隔（秒） |

### バックアップされるファイル

- **データファイル**: `*.json`, `*.zip`, `*.parquet`
- **ログファイル**: `*.log`
- **ファイル名**: `{timestamp}_{original_filename}`

## トラブルシューティング

### 認証エラー
```
ERROR: failed to get drive: oauth2: cannot fetch token
```
**解決方法**: 設定ファイルが正しく配置されているか確認

### 権限エラー
```
ERROR: permission denied
```
**解決方法**: Google Drive APIの権限設定を確認

### ネットワークエラー
```
ERROR: connection timeout
```
**解決方法**: ネットワーク接続を確認

## ログ

バックアップ処理のログは `logs/backup.log` に出力されます。

## セキュリティ

- 認証ファイルは適切に管理してください
- 必要最小限の権限のみを設定してください
- 設定ファイルのバックアップを取ってください

# rclone設定ディレクトリ

このディレクトリには、rcloneの設定ファイルを配置します。

## 設定ファイル

```
configs/rclone/
├── rclone.conf    # rclone設定ファイル（手動で配置）
└── README.md      # このファイル
```

## セットアップ手順

### 1. rcloneのインストール
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install rclone

# macOS
brew install rclone

# Windows
# https://rclone.org/downloads/ からダウンロード
```

### 2. Google Drive認証設定
```bash
# rclone設定開始
rclone config

# 新しいリモートを作成
n) New remote
name> gdrive
Storage> drive
client_id> (空白でEnter - デフォルトを使用)
client_secret> (空白でEnter - デフォルトを使用)
scope> drive
root_folder_id> (空白でEnter)
service_account_file> (空白でEnter)
Use auto config?> Y
```

### 3. 設定ファイルの配置
```bash
# 設定ファイルをこのディレクトリにコピー
cp ~/.config/rclone/rclone.conf ./configs/rclone/
```

### 4. 設定確認
```bash
# 設定確認
rclone listremotes

# Google Drive接続テスト
rclone lsd gdrive:
```

## Dockerでの使用

### 基本的な使用方法
```bash
# rclone設定をマウントして実行
docker run --rm \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/logs:/app/logs \
  -v $(pwd)/configs/rclone:/root/.config/rclone \
  -e RCLONE_ENABLED=true \
  tram-ingest:latest
```

### Makefileを使用
```bash
# rclone自動バックアップ付きで実行
make run-ingest-rclone
```

## トラブルシューティング

### 1. 認証エラー
```
ERROR: failed to get drive: failed to get drive: oauth2: cannot fetch token
```

**解決方法**: 設定ファイルが正しく配置されているか確認してください。

### 2. 権限エラー
```
ERROR: failed to get drive: failed to get drive: permission denied
```

**解決方法**: Google Drive APIの権限設定を確認してください。

### 3. ネットワークエラー
```
ERROR: failed to get drive: failed to get drive: connection timeout
```

**解決方法**: ネットワーク接続を確認してください。

## セキュリティ

- **設定ファイル**: 認証情報が含まれているため、適切に管理してください
- **権限**: 必要最小限の権限のみを設定してください
- **バックアップ**: 設定ファイルのバックアップを取ってください

## 参考資料

- [rclone公式ドキュメント](https://rclone.org/)
- [Google Drive設定ガイド](https://rclone.org/drive/)
- [認証設定](https://rclone.org/docs/#authentication)

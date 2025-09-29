# Docker Configuration

このディレクトリには、Tram Delay Reduction ManagementシステムのDocker設定ファイルが含まれています。

## ファイル構成

```
docker/
├── docker-compose.yml    # 全サービスのオーケストレーション
├── Dockerfile.base       # ベースイメージ（共通依存関係）
├── Dockerfile.ingest     # GTFSデータ取得用イメージ
├── Dockerfile.sim        # シミュレーション用イメージ
├── Dockerfile.train      # 学習用イメージ
└── README.md            # このファイル
```

## 使用方法

### 1. 全サービス起動
```bash
# プロジェクトルートから実行
make compose-up

# または直接docker-composeコマンド
docker-compose -f docker/docker-compose.yml up --build
```

### 2. 個別サービス起動
```bash
# GTFSデータ取得のみ
make compose-ingest

# シミュレーションのみ
make compose-sim

# 学習のみ
make compose-train
```

### 3. 個別イメージビルド
```bash
# ベースイメージ
make build-base

# GTFSデータ取得イメージ
make build-ingest

# シミュレーションイメージ
make build-sim

# 学習イメージ
make build-train
```

## サービス詳細

### gtfs-ingest
- **目的**: GTFSデータの取得・保存
- **実行間隔**: 20秒
- **バックアップ**: Google Drive自動バックアップ（5分間隔）
- **再起動**: 自動再起動（unless-stopped）

### simulation
- **目的**: SUMO/Flowシミュレーション実行
- **実行**: 手動実行
- **再起動**: なし

### training
- **目的**: 強化学習・最適化実行
- **実行**: 手動実行
- **再起動**: なし

## ボリュームマウント

### データディレクトリ
- `../data` → `/app/data` - GTFSデータ保存
- `../logs` → `/app/logs` - ログファイル
- `../results` → `/app/results` - 実行結果
- `../models` → `/app/models` - 学習済みモデル

### 設定ディレクトリ
- `../configs/google_drive` → `/app/configs/google_drive` - Google Drive認証

## 環境変数

### 共通
- `PYTHONPATH=/app/src` - Pythonパス設定

### gtfs-ingest
- `GOOGLE_DRIVE_ENABLED=true` - Google Drive自動バックアップ有効
- `BACKUP_INTERVAL=300` - バックアップ間隔（秒）

### simulation
- `SUMO_HOME=/opt/sumo` - SUMOインストールパス

## トラブルシューティング

### 1. ビルドエラー
```bash
# キャッシュをクリアして再ビルド
make clean
make build-all
```

### 2. ボリュームマウントエラー
```bash
# ディレクトリの存在確認
ls -la ../data ../logs ../results ../models
```

### 3. 権限エラー
```bash
# ディレクトリの権限確認
ls -la ../data ../logs
```

## 開発時の注意点

1. **Dockerfileの変更**: イメージ再ビルドが必要
2. **docker-compose.ymlの変更**: サービス再起動が必要
3. **ボリュームマウント**: 相対パス（`../`）を使用
4. **環境変数**: 各サービスに適切な値を設定

## パフォーマンス最適化

### マルチステージビルド
- ベースイメージで重い依存関係を一度だけインストール
- 派生イメージで軽量な依存関係のみ追加

### レイヤーキャッシュ
- 変更頻度の低いレイヤーを先に配置
- 依存関係のインストールを分離

### イメージサイズ最適化
- 不要なファイルの削除
- マルチステージビルドの活用

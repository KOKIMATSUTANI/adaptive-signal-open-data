# Tram Delay Reduction Management

路面電車の遅延削減を目的とした、GTFSデータ収集・分析・最適化システムです。

## 概要

- **GTFSデータ収集**: 20秒間隔でのリアルタイムデータ取得
- **自動バックアップ**: Google Driveへの自動アップロード
- **シミュレーション**: SUMO/Flowを使用した交通シミュレーション
- **最適化**: 強化学習・数理最適化による遅延削減

## クイックスタート

### 1. 依存関係のインストール
```bash
# Docker & Docker Compose
sudo apt update
sudo apt install docker.io docker-compose

# rclone（Google Drive連携用）
sudo apt install rclone
```

### 2. Google Drive設定（オプション）
```bash
# rclone設定
rclone config
cp ~/.config/rclone/rclone.conf ./configs/rclone/
```

### 3. 実行
```bash
# GTFSデータ収集開始
make run-ingest-rclone

# または全サービス起動
make compose-up
```

## ディレクトリ構成

```
tram-delay-reduction-management/
├── docs/                    # ドキュメント
│   └── GOOGLE_DRIVE.md     # Google Drive連携
├── docker/                  # Docker設定
│   ├── docker-compose.yml  # サービス定義
│   ├── Dockerfile.base     # ベースイメージ
│   ├── Dockerfile.ingest   # データ収集
│   ├── Dockerfile.sim      # シミュレーション
│   └── Dockerfile.train    # 学習
├── requirements/            # Python依存関係
│   ├── base.txt            # 共通依存
│   ├── ingest.txt          # データ収集
│   ├── sim.txt             # シミュレーション
│   └── train.txt           # 学習
├── src/                    # ソースコード
│   ├── gtfs_pipeline/      # GTFSデータ処理
│   ├── simulation/         # シミュレーション
│   └── training/           # 学習
├── configs/                # 設定ファイル
│   ├── rclone/             # rclone設定
│   └── google_drive/       # Google Drive API設定
├── scripts/                # スクリプト
│   └── backup_to_google_drive.sh
├── data/                   # データ保存
├── logs/                   # ログファイル
└── Makefile               # ビルド・実行コマンド
```

## 主要機能

### GTFSデータ収集
- **間隔**: 20秒
- **データ**: GTFS Static, Trip Updates, Vehicle Positions
- **保存**: ローカル + Google Drive自動バックアップ

### シミュレーション
- **エンジン**: SUMO/Flow
- **用途**: 交通流シミュレーション
- **出力**: 遅延分析結果

### 最適化
- **手法**: 強化学習（Q-DDQN）、数理最適化
- **目的**: 遅延削減
- **出力**: 最適化された運行計画

## 使用方法

### データ収集
```bash
# rclone使用（推奨）
make run-ingest-rclone

# Google Drive API使用
make run-ingest

# バックアップなし
make run-ingest-no-backup
```

### シミュレーション
```bash
make run-sim
```

### 学習
```bash
make run-train
```

### 全サービス
```bash
make compose-up
```

## 設定

### 環境変数
- `RCLONE_ENABLED`: rclone自動バックアップ
- `GOOGLE_DRIVE_ENABLED`: Google Drive API自動バックアップ
- `BACKUP_INTERVAL`: バックアップ間隔（秒）

### 設定ファイル
- `configs/rclone/rclone.conf`: rclone設定
- `configs/google_drive/`: Google Drive API設定

## トラブルシューティング

### ビルドエラー
```bash
make clean
make build-all
```

### 認証エラー
- rclone設定を確認: `rclone lsd gdrive:`
- Google Drive API設定を確認: `docs/GOOGLE_DRIVE.md`

### ログ確認
```bash
# アプリケーションログ
tail -f logs/ingest.log

# バックアップログ
tail -f logs/backup.log
```

## 開発

### 依存関係追加
```bash
# 全ジョブ共通
echo "package>=1.0.0" >> requirements/base.txt

# 特定ジョブ専用
echo "package>=1.0.0" >> requirements/ingest.txt
```

### ビルド
```bash
# 個別ビルド
make build-ingest
make build-sim
make build-train

# 全ビルド
make build-all
```

## ライセンス

MIT License

## 貢献

プルリクエストやイシューの報告を歓迎します。

## 参考資料

- [GTFS仕様](https://developers.google.com/transit/gtfs)
- [SUMO公式ドキュメント](https://sumo.dlr.de/docs/)
- [rclone公式ドキュメント](https://rclone.org/)
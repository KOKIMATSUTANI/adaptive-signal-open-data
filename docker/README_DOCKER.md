# Docker構成 - 路面電車遅延削減管理システム

## アーキテクチャ概要

このプロジェクトは、**分離されたDockerイメージ**を使用して、各ジョブの依存関係を最適化し、ビルド時間を短縮します。

| ファイル                  | 役割（何のための箱？）                                           | ねらい / この分離で得られるもの                                                                  |
| --------------------- | ----------------------------------------------------- | ---------------------------------------------------------------------------------- |
| **Dockerfile.base**   | 共通の土台（Python, pip/poetry, pandas/pyarrow など全ジョブ共通の依存） | **一度だけ**重い依存を入れてキャッシュ化 → 以降の派生イメージが**爆速ビルド**。環境を**一元化**して再現性UP。                    |
| **Dockerfile.ingest** | GTFS/GTFS-RT 取得 + Parquet化専用                          | 実行権限・依存を**最小限**に（セキュア&軽量）。ジョブは短命・定期実行しやすい。データ用の**ボリューム**を前提に設計。                    |
| **Dockerfile.sim**    | SUMO / Flow のシミュレーション専用                               | SIM系の追加依存（SUMO, Flow, OSパッケージ）を**隔離**。重い/特殊な依存を他ジョブに波及させない。                        |
| **Dockerfile.train**  | RL / MIP 学習専用                                         | 将来の **GPU化（CUDAベースに差し替え）** をこの層だけで完結。学習用ライブラリ（torch など）を他から**分離**してサイズ・セキュリティを最適化。 |

## クイックスタート

### 1. 全イメージをビルド
```bash
make build-all
```

### 2. データ取得を実行
```bash
make run-ingest
```

### 3. シミュレーションを実行
```bash
make run-sim
```

### 4. 学習を実行
```bash
make run-train
```

## 詳細な使用方法

### ベースイメージのビルド（初回のみ）
```bash
# 重い依存関係を一度だけインストール
make build-base
```

### 個別イメージのビルド
```bash
# GTFSデータ取得用
make build-ingest

# シミュレーション用
make build-sim

# 学習用
make build-train
```

### Docker Compose使用
```bash
# 全サービスを一度に実行
make compose-up

# または直接
docker-compose up --build
```

## 実行例

### データ取得（短命ジョブ）
```bash
# 全データを取得
docker run --rm -v $(pwd)/data:/app/data tram-ingest:latest

# GTFS Staticのみ
docker run --rm -v $(pwd)/data:/app/data tram-ingest:latest --feed-type gtfs_static --once

# 特定のフィードのみ
docker run --rm -v $(pwd)/data:/app/data tram-ingest:latest --feed-type trip_updates --once
```

### シミュレーション実行
```bash
# デフォルト設定で実行
docker run --rm -v $(pwd)/results:/app/results tram-sim:latest

# 特定のシナリオで実行
docker run --rm -v $(pwd)/results:/app/results tram-sim:latest --scenario toyama_tram
```

### 学習実行
```bash
# デフォルト設定で学習
docker run --rm -v $(pwd)/models:/app/models -v $(pwd)/results:/app/results tram-train:latest

# 特定のアルゴリズムで学習
docker run --rm -v $(pwd)/models:/app/models tram-train:latest --algorithm qddqn --episodes 1000
```

## 定期実行（Cron設定例）

### データ取得を20秒間隔で実行
```bash
# crontab -e で以下を追加
*/20 * * * * cd /path/to/project && make run-ingest
```

### シミュレーションを毎時実行
```bash
# crontab -e で以下を追加
0 * * * * cd /path/to/project && make run-sim
```

## ボリューム構成

```
./data/          # GTFSデータ保存先
./models/        # 学習済みモデル保存先
./results/       # シミュレーション・学習結果保存先
./logs/          # ログファイル保存先
```

## GPU対応（将来の拡張）

学習用イメージをGPU対応にする場合：

```bash
# GPU対応版のビルド
docker build -f docker/Dockerfile.train.gpu -t tram-train:gpu .

# GPU使用で実行
docker run --rm --gpus all -v $(pwd)/models:/app/models tram-train:gpu
```

## トラブルシューティング

### イメージのクリーンアップ
```bash
make clean
```

### ログの確認
```bash
# コンテナ内のログを確認
docker logs <container_id>

# ホストのログファイルを確認
tail -f logs/gtfs_ingest.log
```

### ボリュームの確認
```bash
# マウントされたボリュームの内容を確認
ls -la data/
ls -la models/
ls -la results/
```

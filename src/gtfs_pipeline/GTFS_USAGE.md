# 富山地方鉄道 GTFS データ取得ガイド

このプロジェクトは、富山地方鉄道のGTFSデータ（静的データとリアルタイムデータ）を取得・処理するためのPythonパイプラインです。

## データソース

- **GTFS Static (JP)**: https://api.gtfs-data.jp/v2/organizations/chitetsu/feeds/chitetsushinaidensha/files/feed.zip?rid=current
- **Trip Updates**: https://gtfs-rt-files.buscatch.jp/toyama/chitetsu_tram/TripUpdates.pb
- **Vehicle Positions**: https://gtfs-rt-files.buscatch.jp/toyama/chitetsu_tram/VehiclePositions.pb

## 使用方法

### 1. 依存関係のインストール

```bash
pip install -r requirements.txt
```

### 2. 設定されたフィードの確認

```bash
python -m src.gtfs_pipeline.cli list-feeds
```

### 3. データの取得

#### 一回だけ実行（推奨）
```bash
python -m src.gtfs_pipeline.cli ingest --feed-type all --once
```

#### 連続実行（20秒間隔）
```bash
python -m src.gtfs_pipeline.cli ingest --feed-type all --interval 20
```

#### 連続実行（60秒間隔、デフォルト）
```bash
python -m src.gtfs_pipeline.cli ingest --feed-type all
```

#### 特定のデータタイプのみ取得
```bash
# GTFS Staticデータのみ
python -m src.gtfs_pipeline.cli ingest --feed-type gtfs_static --once

# Trip Updatesのみ
python -m src.gtfs_pipeline.cli ingest --feed-type trip_updates --once

# Vehicle Positionsのみ
python -m src.gtfs_pipeline.cli ingest --feed-type vehicle_positions --once
```

## 設定

### リクエスト間隔
- 現在の設定: **20秒間隔**でリクエストを送信
- 連続実行時の間隔: `--interval`オプションで指定可能（デフォルト60秒）

### タイムアウト設定
- リクエストタイムアウト: 30秒
- 最大リトライ回数: 3回
- リトライ間隔: 5秒

## データ構造

### GTFS Static データ
- `agency.txt`: 事業者情報
- `stops.txt`: 停留所情報
- `routes.txt`: 路線情報
- `trips.txt`: 運行情報
- `stop_times.txt`: 停留所通過時刻
- `calendar.txt`: 運行カレンダー
- `calendar_dates.txt`: 運行日例外

### GTFS-RT データ
- **Trip Updates**: 運行遅延・変更情報
- **Vehicle Positions**: 車両位置情報

## ログ

処理状況は詳細なログとして出力されます。データの取得状況、解析結果、エラー情報などが記録されます。

## 注意事項

- 現在の実装では、データはログに出力されるのみで、データベースへの永続化は実装されていません
- 実際のデータベース保存機能を実装する場合は、`database.py`の`store_gtfs_rt_data`と`store_gtfs_static_data`メソッドを実装してください
- リクエスト間隔は20秒に設定されており、サーバーに負荷をかけないよう配慮されています
- 連続実行時は`Ctrl+C`で停止できます

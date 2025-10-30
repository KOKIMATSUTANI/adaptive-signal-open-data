# 1. 背景と目的
- GTFS×SUMO×Flow×RLで公共交通最適化に挑戦
![研究全体イメージ](../assets/slide-1-overview.jpg "研究全体の概要を示す図を挿入")

---

# 2. 原理
- クラウド×自動化スクリプト×コンテナで再現性を確保
![技術構成の概観](../assets/slide-2-architecture.png "技術構成を示す図を挿入")

---

# 2-1. クラウドコンピューティングの役割
- GCP でローカル停止時も処理と保存が継続
![GCP 操作画面](../assets/slide-2-1-gcp.jpg "GCP の操作画面を挿入")

---

# 2-2. Shellscript の役割
- 20 秒周期の取得監視とジョブ起動を自動化
```pseudo
scheduler-realtime.sh
  set -euo pipefail
  interval_seconds = ${RT_INTERVAL:-20}
  log() -> append timestamped entries to logs/scheduler-realtime.log

  function run_rt_ingest() {
    cd PROJECT_DIR
    docker compose run --rm gtfs-ingest-realtime
  }

  while true {
    if current_hour < 5 -> skip cycle
    run_rt_ingest() or log retry
    sleep interval_seconds
  }
```

---

# 2-3. Docker / Compose の役割
- 依存関係込みの環境を `docker compose` で再現
```pseudo
docker-compose.yml
  services:
    gtfs-ingest-static:
      build: docker/Dockerfile.ingest
      volumes: [../data, ../logs, ../configs]
      command: --feed-type gtfs_static --once
    gtfs-ingest-realtime:
      build: docker/Dockerfile.ingest-realtime
      volumes: [../data, ../logs, ../configs]
      command: --feed-type all --once
    simulation:
      build: docker/Dockerfile.sim
      command: --config configs/sim/toyama_tram.yaml
    training:
      build: docker/Dockerfile.train
      command: --config configs/train/qddqn.yaml \
               --episodes 1000
```

---

# 2-4. SUMO シミュレーション例
- 交通流を SUMO で再現し評価指標を取得
![SUMO の画面](../assets/slide-2-4-sumo.jpg "SUMO のシミュレーション画面を挿入")
*出典: [SUMO - DLR](https://www.dlr.de/en/ts/research-transfer/research-services/sumo)*


---

# 3-1. GCP での取得運用
- GTFS 取得を VM 常駐化しローカル PC 依存を排除
![VM の設定画面](../assets/slide-3-1-vm.jpg "GCP VM の設定画面を挿入")

---

# 3-2. 20 秒間隔の取得スクリプト
- `fetch_gtfs.sh` が `sleep 20` で高頻度ポーリング
```pseudo
scripts/scheduler-realtime.sh
  RT_INTERVAL = ${RT_INTERVAL:-20}
  log(msg) -> append to logs/scheduler-realtime.log with timestamp

  function run_rt_ingest() {
    docker compose run --rm gtfs-ingest-realtime
  }

  loop in background {
    if current_hour < 5:
      sleep RT_INTERVAL; continue
    run_rt_ingest(); sleep RT_INTERVAL
  }
```

---

# 3-3. Docker 化の意図
- Dockerfile と Compose で誰でも同じ手順を実行可能に
![Docker 実行画面](../assets/slide-3-3-docker-run.jpg "Docker 実行画面を挿入")

---

# 4. 結果
- 現状は GTFS 取得パイプラインの構築まで完了
![取得ログまたは成果画面](../assets/slide-4-result.jpg "取得結果のスクリーンショットを挿入")

---

# 5. 今後
- 前処理・SUMO/Flow 環境構築・評価指標整備を順次進める
![ロードマップ図](../assets/slide-5-roadmap.png "ロードマップを示す図を挿入")

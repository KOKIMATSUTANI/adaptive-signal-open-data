# 目次
1. 背景と目的
2. GTFS取得に関する原理と方法
3. GTFSデータ取得の現状
4. 今後の課題


---
# 目次
1. <span style="color:#1d4ed8">背景と目的（研究の全体の流れ）</span>
2. GTFS取得に関する原理と方法
3. GTFSデータ取得の現状
4. 今後の課題


---
# 1. 背景と目的
- GTFS×SUMO×FLOW×DRLで交通信号通最適化に挑戦
<div class = "mermaid"> 
flowchart LR
    A[GTFS data] --> B[Data preprocessing]
    B --> C[SUMO simulation]
    C --> D[RL agent training]
    D --> E[Evaluation]
    E --> F[Results]
</div>

---
# 目次
1. 背景と目的
2. <span style="color:#1d4ed8">GTFS取得に関する原理と方法</span>
3. GTFSデータ取得の現状
4. 今後の課題


---

# 2. GTFS取得に関する原理と方法
<!-- （クラウドコンピューティング/Shellscript/Docker/SUMO） -->
- クラウド×自動化スクリプト×コンテナで再現性を確保

![技術構成の概観](../assets/overview.png "GTFSログのスクリーンショット")

---

## 2-1. クラウドコンピューティングの役割
- GCP でローカル停止時も処理と保存が継続
![GCP 操作画面](../assets/slide-2-1-gcp.jpg "GCP の操作画面を挿入")

---

## 2-2. Shellscript の役割
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

## 2-3. Docker / Docker Compose の役割
- 依存関係込みの環境をDockerで構築
-  `docker compose` で管理
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

## 2-4. SUMO シミュレーション例
- 交通流を SUMO で再現し評価指標を取得
![SUMO の画面](../assets/slide-2-4-sumo.jpg "SUMO のシミュレーション画面を挿入")
*出典: [SUMO - DLR](https://www.dlr.de/en/ts/research-transfer/research-services/sumo)*


---
# 目次
1. 背景と目的
2. GTFS取得に関する原理と方法
3. <span style="color:#1d4ed8">3. GTFSデータ取得の現状（9/28-10/9の進捗）</span>
4. 今後の課題


---
# 3. GTFSデータ取得の現状

- 現状は GTFS 取得パイプラインの構築まで完了
![取得ログまたは成果画面](../assets/slide-4-result.jpg "取得結果のスクリーンショットを挿入")

---

# 目次
1. 背景と目的
2. GTFS取得に関する原理と方法
3. GTFSデータ取得の現状
4. <span style="color:#1d4ed8">4. 今後の課題</span>


---
# 今後の課題
- .json -> .zip, .pbファイルでの取得方法の変更
- SSH接続の設定
- SUMOシミュレーション環境（一交差点）の構築
- FLOWコーディング
- 上記についての先行研究再調査（卒論で引用できるような形式で整理する）

# Makefile for Tram Delay Reduction Management

# イメージ名
BASE_IMAGE = tram-base:latest
INGEST_IMAGE = tram-ingest:latest
SIM_IMAGE = tram-sim:latest
TRAIN_IMAGE = tram-train:latest

# ビルドターゲット
.PHONY: build-base build-ingest build-sim build-train build-all
.PHONY: run-ingest run-sim run-train
.PHONY: clean help

# ベースイメージをビルド（重い依存を一度だけ）
build-base:
	docker build -f docker/Dockerfile.base -t $(BASE_IMAGE) .

# 各ジョブ用イメージをビルド（軽量・高速）
build-ingest: build-base
	docker build -f docker/Dockerfile.ingest -t $(INGEST_IMAGE) .

build-sim: build-base
	docker build -f docker/Dockerfile.sim -t $(SIM_IMAGE) .

build-train: build-base
	docker build -f docker/Dockerfile.train -t $(TRAIN_IMAGE) .

# 全イメージをビルド
build-all: build-ingest build-sim build-train

# データ取得実行
run-ingest: build-ingest
	docker run --rm -v $(PWD)/data:/app/data -v $(PWD)/logs:/app/logs $(INGEST_IMAGE)

# シミュレーション実行
run-sim: build-sim
	docker run --rm -v $(PWD)/data:/app/data -v $(PWD)/results:/app/results $(SIM_IMAGE)

# 学習実行
run-train: build-train
	docker run --rm -v $(PWD)/data:/app/data -v $(PWD)/models:/app/models -v $(PWD)/results:/app/results $(TRAIN_IMAGE)

# Docker Compose実行
compose-up:
	docker-compose up --build

# クリーンアップ
clean:
	docker rmi $(BASE_IMAGE) $(INGEST_IMAGE) $(SIM_IMAGE) $(TRAIN_IMAGE) 2>/dev/null || true
	docker system prune -f

# ヘルプ
help:
	@echo "Available targets:"
	@echo "  build-base   - Build base image (heavy dependencies)"
	@echo "  build-ingest - Build GTFS ingestion image"
	@echo "  build-sim    - Build simulation image"
	@echo "  build-train  - Build training image"
	@echo "  build-all    - Build all images"
	@echo "  run-ingest   - Run GTFS data ingestion"
	@echo "  run-sim      - Run simulation"
	@echo "  run-train    - Run training"
	@echo "  compose-up   - Run with docker-compose"
	@echo "  clean        - Clean up images"
	@echo "  help         - Show this help"

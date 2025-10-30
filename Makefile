# Makefile for Tram Delay Reduction Management
# NOTE: Do not use chmod 777 or 666.
# Use proper ownership (chown) and safe permissions instead (chmod 755).

# Image names
BASE_IMAGE = tram-base:latest
INGEST_IMAGE = tram-ingest:latest
INGEST_REALTIME_IMAGE = tram-ingest-realtime:latest
SIM_IMAGE = tram-sim:latest
TRAIN_IMAGE = tram-train:latest
REALTIME_INTERVAL ?= 20

# Docker Compose configuration
COMPOSE_FILE = docker/docker-compose.yml

# Build targets
.PHONY: build-base build-ingest build-ingest-realtime build-sim build-train build-all
.PHONY: run-ingest-static run-ingest-realtime run-ingest-realtime-loop run-sim run-train
.PHONY: compose-ingest-realtime compose-ingest-realtime-loop compose-ingest-realtime-raw compose-sim compose-train
.PHONY: clean help

# Build base image (heavy dependencies once)
build-base:
	docker build --build-arg APP_UID=1000 --build-arg APP_GID=1000 -f docker/Dockerfile.base -t $(BASE_IMAGE) .

# Build job-specific images (lightweight & fast)
build-ingest: build-base
	docker build --build-arg APP_UID=1000 --build-arg APP_GID=1000 -f docker/Dockerfile.ingest -t $(INGEST_IMAGE) .

build-ingest-realtime: build-base
	docker build --build-arg APP_UID=1000 --build-arg APP_GID=1000 -f docker/Dockerfile.ingest-realtime -t $(INGEST_REALTIME_IMAGE) .

build-sim: build-base
	docker build -f docker/Dockerfile.sim -t $(SIM_IMAGE) .

build-train: build-base
	docker build -f docker/Dockerfile.train -t $(TRAIN_IMAGE) .

# Build all images
build-all: build-ingest build-ingest-realtime build-sim build-train

# Run GTFS static data ingestion once (cleans previous snapshots)
run-ingest-static:
	./scripts/ingest_static_once.sh

# Run GTFS-RT real-time data ingestion (short-lived task)
run-ingest-realtime: build-ingest-realtime
	docker run --rm -v $(PWD)/data:/app/data -v $(PWD)/logs:/app/logs -v $(PWD)/configs:/app/configs $(INGEST_REALTIME_IMAGE) --feed-type realtime --once

run-ingest-realtime-loop:
	./scripts/scheduler-realtime.sh

run-ingest-realtime-raw: build-ingest-realtime
	docker run --rm \
		-e GTFS_RT_SAVE_PROTO=1 \
		-e GTFS_STATIC_SAVE_ZIP=1 \
		-v $(PWD)/data:/app/data \
		-v $(PWD)/logs:/app/logs \
		-v $(PWD)/configs:/app/configs \
		$(INGEST_REALTIME_IMAGE) --feed-type realtime --once

# Run simulation
run-sim: build-sim
	docker run --rm -v $(PWD)/data:/app/data -v $(PWD)/results:/app/results $(SIM_IMAGE)

# Run training
run-train: build-train
	docker run --rm -v $(PWD)/data:/app/data -v $(PWD)/models:/app/models -v $(PWD)/results:/app/results $(TRAIN_IMAGE)

# Run with Docker Compose (short-lived tasks)
compose-ingest-realtime:
	docker compose -f $(COMPOSE_FILE) run --rm gtfs-ingest-realtime

compose-ingest-realtime-loop:
	docker compose -f $(COMPOSE_FILE) run --rm gtfs-ingest-realtime --feed-type realtime --interval $(REALTIME_INTERVAL)

compose-ingest-realtime-raw:
	GTFS_RT_SAVE_PROTO=1 GTFS_STATIC_SAVE_ZIP=1 docker compose -f $(COMPOSE_FILE) run --rm gtfs-ingest-realtime

compose-sim:
	docker compose -f $(COMPOSE_FILE) run --rm simulation

compose-train:
	docker compose -f $(COMPOSE_FILE) run --rm training

# Real-time scheduler (short-lived tasks)
scheduler-realtime:
	./scripts/scheduler-realtime.sh

scheduler-realtime-once:
	./scripts/scheduler-realtime.sh --once

# Cron-based real-time data collection
cron-setup:
	./scripts/setup-cron.sh setup

cron-remove:
	./scripts/setup-cron.sh remove

cron-show:
	./scripts/setup-cron.sh show

# Cleanup
clean:
	docker rmi $(BASE_IMAGE) $(INGEST_IMAGE) $(INGEST_REALTIME_IMAGE) $(SIM_IMAGE) $(TRAIN_IMAGE) 2>/dev/null || true
	docker system prune -f

# Help
help:
	@echo "Available targets:"
	@echo "  build-base   - Build base image (heavy dependencies)"
	@echo "  build-ingest - Build GTFS Static ingestion image (short-lived task)"
	@echo "  build-ingest-realtime - Build GTFS-RT real-time ingestion image (continuous)"
	@echo "  build-sim    - Build simulation image"
	@echo "  build-train  - Build training image"
	@echo "  build-all    - Build all images"
	@echo "  run-ingest-static - Run GTFS static ingestion once (ensures a single snapshot)"
	@echo "  run-ingest-realtime - Run GTFS-RT real-time data ingestion (single execution)"
	@echo "  run-ingest-realtime-loop - Run continuous GTFS-RT ingestion (interval=$(REALTIME_INTERVAL)s)"
	@echo "  run-ingest-realtime-raw - Run GTFS-RT ingestion saving raw protobuf/ZIP artifacts"
	@echo "  run-sim      - Run simulation"
	@echo "  run-train    - Run training"
	@echo "  compose-ingest-realtime - Run GTFS-RT real-time ingestion with docker compose (single execution)"
	@echo "  compose-ingest-realtime-loop - Run continuous GTFS-RT ingestion with docker compose"
	@echo "  compose-ingest-realtime-raw - Same as above with raw protobuf/ZIP archiving enabled"
	@echo "  compose-sim  - Run simulation with docker compose"
	@echo "  compose-train - Run training with docker compose"
	@echo "  scheduler-realtime - Run real-time scheduler (RT data every 20s)"
	@echo "  scheduler-realtime-once - Run real-time scheduler once"
	@echo "  cron-setup   - Setup system cron for real-time data collection"
	@echo "  cron-remove  - Remove system cron jobs"
	@echo "  cron-show    - Show current cron jobs"
	@echo "  clean        - Clean up images"
	@echo "  help         - Show this help"

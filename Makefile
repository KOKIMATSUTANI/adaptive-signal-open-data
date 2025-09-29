# Makefile for Tram Delay Reduction Management
# NOTE: Do not use chmod 777 or 666.
# Use proper ownership (chown) and safe permissions instead (chmod 755).

# Image names
BASE_IMAGE = tram-base:latest
INGEST_IMAGE = tram-ingest:latest
INGEST_REALTIME_IMAGE = tram-ingest-realtime:latest
BACKUP_IMAGE = tram-backup:latest
SIM_IMAGE = tram-sim:latest
TRAIN_IMAGE = tram-train:latest

# Docker Compose configuration
COMPOSE_FILE = docker/docker-compose.yml

# Build targets
.PHONY: build-base build-ingest build-ingest-realtime build-backup build-sim build-train build-all
.PHONY: run-ingest run-ingest-realtime run-backup run-sim run-train
.PHONY: compose-ingest compose-ingest-realtime compose-backup compose-sim compose-train
.PHONY: scheduler scheduler-once clean help

# Build base image (heavy dependencies once)
build-base:
	docker build --build-arg APP_UID=1000 --build-arg APP_GID=1000 -f docker/Dockerfile.base -t $(BASE_IMAGE) .

# Build job-specific images (lightweight & fast)
build-ingest: build-base
	docker build --build-arg APP_UID=1000 --build-arg APP_GID=1000 -f docker/Dockerfile.ingest -t $(INGEST_IMAGE) .

build-ingest-realtime: build-base
	docker build --build-arg APP_UID=1000 --build-arg APP_GID=1000 -f docker/Dockerfile.ingest-realtime -t $(INGEST_REALTIME_IMAGE) .

build-backup: build-base
	docker build --build-arg APP_UID=1000 --build-arg APP_GID=1000 -f docker/Dockerfile.backup -t $(BACKUP_IMAGE) .

build-sim: build-base
	docker build -f docker/Dockerfile.sim -t $(SIM_IMAGE) .

build-train: build-base
	docker build -f docker/Dockerfile.train -t $(TRAIN_IMAGE) .

# Build all images
build-all: build-ingest build-ingest-realtime build-backup build-sim build-train

# Run GTFS Static data ingestion (short-lived task)
run-ingest: build-ingest
	docker run --rm -v $(PWD)/data:/app/data -v $(PWD)/logs:/app/logs -v $(PWD)/configs:/app/configs $(INGEST_IMAGE) --feed-type gtfs_static --once

# Run GTFS-RT real-time data ingestion (short-lived task)
run-ingest-realtime: build-ingest-realtime
	docker run --rm -v $(PWD)/data:/app/data -v $(PWD)/logs:/app/logs -v $(PWD)/configs:/app/configs $(INGEST_REALTIME_IMAGE) --feed-type all --once

# Run backup (short-lived task)
run-backup: build-backup
	docker run --rm -v $(PWD)/data:/app/data -v $(PWD)/logs:/app/logs -v $(PWD)/configs:/app/configs -v $(HOME)/.config/rclone:/root/.config/rclone:ro -v $(HOME)/.config/rclone:/home/appuser/.config/rclone:ro $(BACKUP_IMAGE) --once

# Run simulation
run-sim: build-sim
	docker run --rm -v $(PWD)/data:/app/data -v $(PWD)/results:/app/results $(SIM_IMAGE)

# Run training
run-train: build-train
	docker run --rm -v $(PWD)/data:/app/data -v $(PWD)/models:/app/models -v $(PWD)/results:/app/results $(TRAIN_IMAGE)

# Run with Docker Compose (short-lived tasks)
compose-ingest:
	docker-compose -f $(COMPOSE_FILE) run --rm gtfs-ingest-static

compose-ingest-realtime:
	docker-compose -f $(COMPOSE_FILE) run --rm gtfs-ingest-realtime

compose-backup:
	docker-compose -f $(COMPOSE_FILE) run --rm backup

compose-sim:
	docker-compose -f $(COMPOSE_FILE) run --rm simulation

compose-train:
	docker-compose -f $(COMPOSE_FILE) run --rm training

# Scheduler for automated execution
scheduler:
	./scripts/scheduler.sh

scheduler-once:
	./scripts/scheduler.sh --once

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
	docker rmi $(BASE_IMAGE) $(INGEST_IMAGE) $(INGEST_REALTIME_IMAGE) $(BACKUP_IMAGE) $(SIM_IMAGE) $(TRAIN_IMAGE) 2>/dev/null || true
	docker system prune -f

# Help
help:
	@echo "Available targets:"
	@echo "  build-base   - Build base image (heavy dependencies)"
	@echo "  build-ingest - Build GTFS Static ingestion image (short-lived task)"
	@echo "  build-ingest-realtime - Build GTFS-RT real-time ingestion image (continuous)"
	@echo "  build-backup - Build backup image (short-lived task)"
	@echo "  build-sim    - Build simulation image"
	@echo "  build-train  - Build training image"
	@echo "  build-all    - Build all images"
	@echo "  run-ingest   - Run GTFS Static data ingestion (single execution)"
	@echo "  run-ingest-realtime - Run GTFS-RT real-time data ingestion (single execution)"
	@echo "  run-backup   - Run backup (single execution)"
	@echo "  run-sim      - Run simulation"
	@echo "  run-train    - Run training"
	@echo "  compose-ingest - Run GTFS Static ingestion with docker-compose"
	@echo "  compose-ingest-realtime - Run GTFS-RT real-time ingestion with docker-compose (single execution)"
	@echo "  compose-backup - Run backup with docker-compose"
	@echo "  compose-sim  - Run simulation with docker-compose"
	@echo "  compose-train - Run training with docker-compose"
	@echo "  scheduler    - Run automated scheduler (static ingest + backup)"
	@echo "  scheduler-once - Run scheduler once (single execution)"
	@echo "  scheduler-realtime - Run real-time scheduler (RT data every 20s + backup)"
	@echo "  scheduler-realtime-once - Run real-time scheduler once"
	@echo "  cron-setup   - Setup system cron for real-time data collection"
	@echo "  cron-remove  - Remove system cron jobs"
	@echo "  cron-show    - Show current cron jobs"
	@echo "  clean        - Clean up images"
	@echo "  help         - Show this help"

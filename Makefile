# Makefile for Tram Delay Reduction Management
# NOTE: Do not use chmod 777 or 666.
# Use proper ownership (chown) and safe permissions instead (chmod 755).

# Image names
BASE_IMAGE = tram-base:latest
INGEST_IMAGE = tram-ingest:latest
INGEST_REALTIME_IMAGE = tram-ingest-realtime:latest
SIM_IMAGE = tram-sim:latest
TRAIN_IMAGE = tram-train:latest
RUN_DATE := $(shell date +%Y%m%d)
INGEST_RT_CONTAINER_NAME := gtfs-ingest-realtime_$(RUN_DATE)
REALTIME_INTERVAL ?= 20

# Container runtime configuration (override with CONTAINER_RUNTIME=podman etc.)
CONTAINER_RUNTIME ?= docker
COMPOSE_CMD ?= $(CONTAINER_RUNTIME) compose

# Docker Compose configuration
COMPOSE_FILE = docker/docker-compose.yml

# Build targets
.PHONY: build-base build-ingest build-ingest-realtime build-sim build-train build-all
.PHONY: run-ingest-static
.PHONY: compose-ingest-realtime compose-ingest-realtime-loop compose-ingest-realtime-raw stop-realtime-loop
.PHONY: compose-sim compose-train
.PHONY: clean help


# Build base image (heavy dependencies once)
build-base:
	$(CONTAINER_RUNTIME) build --build-arg APP_UID=1000 --build-arg APP_GID=1000 -f docker/Dockerfile.base -t $(BASE_IMAGE) .

# Build job-specific images (lightweight & fast)
build-ingest: build-base
	$(CONTAINER_RUNTIME) build --build-arg APP_UID=1000 --build-arg APP_GID=1000 -f docker/Dockerfile.ingest -t $(INGEST_IMAGE) .

build-ingest-realtime: build-base
	$(CONTAINER_RUNTIME) build --build-arg APP_UID=1000 --build-arg APP_GID=1000 -f docker/Dockerfile.ingest-realtime -t $(INGEST_REALTIME_IMAGE) .

build-sim: build-base
	$(CONTAINER_RUNTIME) build -f docker/Dockerfile.sim -t $(SIM_IMAGE) .

build-train: build-base
	$(CONTAINER_RUNTIME) build -f docker/Dockerfile.train -t $(TRAIN_IMAGE) .

# Build all images
build-all: build-ingest build-ingest-realtime build-sim build-train

# Run GTFS static data ingestion once (cleans previous snapshots)
run-ingest-static:
	CONTAINER_RUNTIME=$(CONTAINER_RUNTIME) COMPOSE_CMD="$(COMPOSE_CMD)" ./scripts/ingest_static_once.sh

# Run with Docker Compose (short-lived tasks)
compose-ingest-realtime:
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) run -e RUN_DATE=$(RUN_DATE) --rm gtfs-ingest-realtime

compose-ingest-realtime-loop:
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) up -d gtfs-ingest-realtime 


stop-realtime-loop:
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) rm -fs gtfs-ingest-realtime

compose-ingest-realtime-raw:
	GTFS_RT_SAVE_PROTO=1 GTFS_STATIC_SAVE_ZIP=1 $(COMPOSE_CMD) -f $(COMPOSE_FILE) run --rm gtfs-ingest-realtime

compose-sim:
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) run --rm simulation

compose-train:
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) run --rm training

# Real-time scheduler (short-lived tasks)
scheduler-realtime:
	CONTAINER_RUNTIME=$(CONTAINER_RUNTIME) COMPOSE_CMD="$(COMPOSE_CMD)" ./scripts/scheduler-realtime.sh

scheduler-realtime-once:
	CONTAINER_RUNTIME=$(CONTAINER_RUNTIME) COMPOSE_CMD="$(COMPOSE_CMD)" ./scripts/scheduler-realtime.sh --once

# Cron-based real-time data collection
cron-setup:
	CONTAINER_RUNTIME=$(CONTAINER_RUNTIME) COMPOSE_CMD="$(COMPOSE_CMD)" ./scripts/setup-cron.sh setup

cron-remove:
	CONTAINER_RUNTIME=$(CONTAINER_RUNTIME) COMPOSE_CMD="$(COMPOSE_CMD)" ./scripts/setup-cron.sh remove

cron-show:
	./scripts/setup-cron.sh show

# Cleanup
clean:
	$(CONTAINER_RUNTIME) rmi $(BASE_IMAGE) $(INGEST_IMAGE) $(INGEST_REALTIME_IMAGE) $(SIM_IMAGE) $(TRAIN_IMAGE) 2>/dev/null || true
	$(CONTAINER_RUNTIME) system prune -f

# Help
help:
	@echo "Available targets:"
	@echo "  build-base   - Build base image (heavy dependencies)"
	@echo "  build-ingest - Build GTFS Static ingestion image (short-lived task)"
	@echo "  build-base   - Build base image (heavy dependencies)"
	@echo "  build-ingest - Build GTFS Static ingestion image (short-lived task)"
	@echo "  build-ingest-realtime - Build GTFS-RT real-time ingestion image (continuous)"
	@echo "  build-sim    - Build simulation image"
	@echo "  build-train  - Build training image"
	@echo "  build-all    - Build all images"
	@echo "  run-ingest-static - Run GTFS static ingestion once (ensures a single snapshot)"
	@echo "  compose-ingest-realtime - Run GTFS-RT real-time ingestion with compose (single execution)"
	@echo "  compose-ingest-realtime-loop - Run continuous GTFS-RT ingestion with compose"
	@echo "  stop-realtime-loop - for cron configuration"
	@echo "  compose-ingest-realtime-raw - Same as above with raw protobuf/ZIP archiving enabled"
	@echo "  compose-sim  - Run simulation with compose"
	@echo "  compose-train - Run training with compose"
	@echo "  scheduler-realtime - Run real-time scheduler (RT data every 20s)"
	@echo "  scheduler-realtime-once - Run real-time scheduler once"
	@echo "  cron-setup   - Setup system cron for real-time data collection"
	@echo "  cron-remove  - Remove system cron jobs"
	@echo "  cron-show    - Show current cron jobs"

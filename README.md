# 🚋 Tram Delay Reduction via GTFS × SUMO × Flow × RL

## Overview
This repository explores **adaptive traffic signal priority** for trams using a combination of:  
- **GTFS / GTFS-RT**: Real-world transit schedule and real-time delay data  
- **SUMO**: Microscopic traffic simulation engine  
- **Flow**: Reinforcement learning framework wrapping SUMO (Gym API)  
- **Deep RL**: Algorithms such as DQN/DDQN to optimize signal control  

The workflow follows a **data science pipeline**:  
1. **Data ingestion** (GTFS, GTFS-RT)  
2. **Preprocessing & normalization** (Parquet, append-only, statistics)  
3. **Simulation setup** (SUMO networks, Flow environments)  
4. **Model training** (baselines vs RL agents)  
5. **Evaluation & visualization** (delay, queue length, reward curves)  

Future extensions include multi-junction networks, advanced RL, and MLOps/Cloud readiness.

---

## Repository Structure
```plantext
├── src/
│   ├── gtfs_pipeline/     # Ingestion & preprocessing
│   ├── sim_bridge/        # GTFS → SUMO network conversion
│   ├── training/          # RL agents and baselines
│   └── evaluation/        # Metrics and visualization
├── configs/               # YAML configs for feeds, scenarios
├── data/                  # GTFS raw & warehouse (Parquet)
├── results/               # Figures, logs, trained models
├── Dockerfile             # Reproducible environment
├── docker-compose.yaml    # Optional local orchestration
└── README.md

```


---
## Quickstart
```bash
# Clone repo
git clone https://github.com/yourname/tram-delay-reduction.git
cd tram-delay-reduction

# Build Docker image
docker build -t tram-delay-reduction .

# Run GTFS ingestion (example config)
docker run -v ./data:/app/data tram-delay-reduction \
  python -m src.gtfs_pipeline.poll_realtime --config configs/feed.yaml --minutes 60

```


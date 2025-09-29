# Toyama Chitetsu GTFS Data Collection Guide

This project is a Python pipeline for collecting and processing GTFS data (static and real-time data) from Toyama Chitetsu.

## Data Sources

- **GTFS Static (JP)**: https://api.gtfs-data.jp/v2/organizations/chitetsu/feeds/chitetsushinaidensha/files/feed.zip?rid=current
- **Trip Updates**: https://gtfs-rt-files.buscatch.jp/toyama/chitetsu_tram/TripUpdates.pb
- **Vehicle Positions**: https://gtfs-rt-files.buscatch.jp/toyama/chitetsu_tram/VehiclePositions.pb

## Usage

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Check Configured Feeds

```bash
python -m src.gtfs_pipeline.cli list-feeds
```

### 3. Data Collection

#### Run Once (Recommended)
```bash
python -m src.gtfs_pipeline.cli ingest --feed-type all --once
```

#### Continuous Execution (20-second intervals)
```bash
python -m src.gtfs_pipeline.cli ingest --feed-type all --interval 20
```

#### Continuous Execution (60-second intervals, default)
```bash
python -m src.gtfs_pipeline.cli ingest --feed-type all
```

#### Collect Specific Data Types Only
```bash
# GTFS Static data only
python -m src.gtfs_pipeline.cli ingest --feed-type gtfs_static --once

# Trip Updates only
python -m src.gtfs_pipeline.cli ingest --feed-type trip_updates --once

# Vehicle Positions only
python -m src.gtfs_pipeline.cli ingest --feed-type vehicle_positions --once
```

## Configuration

### Request Interval
- Current setting: Send requests at **20-second intervals**
- Continuous execution interval: Can be specified with `--interval` option (default 60 seconds)

### Timeout Settings
- Request timeout: 30 seconds
- Maximum retry count: 3 times
- Retry interval: 5 seconds

## Data Structure

### GTFS Static Data
- `agency.txt`: Agency information
- `stops.txt`: Stop information
- `routes.txt`: Route information
- `trips.txt`: Trip information
- `stop_times.txt`: Stop time information
- `calendar.txt`: Service calendar
- `calendar_dates.txt`: Service date exceptions

### GTFS-RT Data
- **Trip Updates**: Trip delay and change information
- **Vehicle Positions**: Vehicle position information

## Logging

Processing status is output as detailed logs. Data collection status, analysis results, error information, etc. are recorded.

## Important Notes

- Current implementation only outputs data to logs, database persistence is not implemented
- To implement actual database storage functionality, implement the `store_gtfs_rt_data` and `store_gtfs_static_data` methods in `database.py`
- Request interval is set to 20 seconds to avoid putting load on the server
- Continuous execution can be stopped with `Ctrl+C`
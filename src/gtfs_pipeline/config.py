"""
Configuration module for GTFS-RT pipeline.
"""

import json
import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional


@dataclass
class DatabaseConfig:
    """Database configuration settings."""
    host: str = "localhost"
    port: int = 5432
    database: str = "gtfs_rt"
    username: str = "postgres"
    password: str = ""
    pool_size: int = 10
    max_overflow: int = 20


@dataclass
class GTFSConfig:
    """Main configuration class for GTFS-RT pipeline."""
    
    # Feed URLs for different transit agencies
    feeds: Dict[str, List[str]] = field(default_factory=lambda: {
        "trip_updates": [
            "https://gtfs-rt-files.buscatch.jp/toyama/chitetsu_tram/TripUpdates.pb",
        ],
        "vehicle_positions": [
            "https://gtfs-rt-files.buscatch.jp/toyama/chitetsu_tram/VehiclePositions.pb",
        ]
    })
    
    # GTFS Static data URL
    gtfs_static_url: str = "https://api.gtfs-data.jp/v2/organizations/chitetsu/feeds/chitetsushinaidensha/files/feed.zip?rid=current"
    
    # Request settings
    request_delay: float = 20.0  # seconds between requests
    timeout: int = 30  # seconds
    max_retries: int = 3
    retry_delay: float = 5.0  # seconds
    
    # Data storage settings
    data_directory: str = "/app/data"
    raw_data_retention_days: int = 7
    processed_data_retention_days: int = 30
    
    # Database configuration
    database: DatabaseConfig = field(default_factory=DatabaseConfig)
    
    # Logging settings
    log_level: str = "INFO"
    log_file: str = "/app/logs/gtfs_ingest.log"
    log_rotation: str = "daily"
    log_retention_days: int = 30
    
    # Processing settings
    batch_size: int = 1000
    max_concurrent_requests: int = 5
    enable_compression: bool = True


# Default configuration instance
DEFAULT_CONFIG = GTFSConfig()

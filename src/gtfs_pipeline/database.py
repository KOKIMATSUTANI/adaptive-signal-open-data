"""
Database management module for GTFS-RT pipeline.
"""

import asyncio
import json
import logging
import os
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Any, Dict, List, Optional, Union

import pandas as pd

from .config import DatabaseConfig, GTFSConfig
from .google_drive import GoogleDriveManager


class DatabaseManager:
    """
    Database manager for GTFS-RT data storage and retrieval.
    """
    
    def __init__(self, config: DatabaseConfig, gtfs_config: Optional[GTFSConfig] = None):
        """
        Initialize database manager.
        
        Args:
            config: Database configuration
            gtfs_config: GTFS configuration (for Google Drive integration)
        """
        # Feature flags let us deploy raw artifact persistence safely.
        self.save_raw_proto = os.getenv("GTFS_RT_SAVE_PROTO", "0") == "1"
        self.save_raw_static_zip = os.getenv("GTFS_STATIC_SAVE_ZIP", "0") == "1"
        self.config = config
        self.gtfs_config = gtfs_config
        self.logger = logging.getLogger(__name__)
        self.google_drive_manager = None
        
        # Initialize Google Drive integration
        if gtfs_config:
            self.google_drive_manager = GoogleDriveManager(gtfs_config)
    
    async def initialize(self):
        """Initialize database connection and create tables if needed."""
        self.logger.info("Database manager initialized (placeholder)")
    
    def store_gtfs_rt_raw(self, raw_bytes: bytes, feed_type: str, timestamp: str) -> None:
        raw_dir = Path("/app/data/raw")
        raw_dir.mkdir(parents=True, exist_ok=True)
        filename = f"gtfs_rt_{feed_type}_{timestamp}.pb"
        target = raw_dir / filename
        with open(target, "wb") as fh:
            fh.write(raw_bytes)
        self.logger.info("GTFS-RT protobuf saved: %s", target)


    def store_gtfs_static_raw(self, raw_bytes: bytes, timestamp: str) -> None:
        raw_dir = Path("/app/data/raw")
        raw_dir.mkdir(parents=True, exist_ok=True)
        filename = f"gtfs_static_{timestamp}.zip"
        target = raw_dir / filename
        with open(target, "wb") as fh:
            fh.write(raw_bytes)
        self.logger.info("GTFS Static ZIP saved: %s", target)


    async def store_gtfs_rt_data(
        self,
        data: Dict,
        feed_url: str,
        raw_bytes: Optional[bytes] = None,
        timestamp: Optional[str] = None,
    ) -> bool:
        """
        Store GTFS-RT data in the database.
        
        Args:
            data: Parsed GTFS-RT data
            feed_url: URL of the feed
            
        Returns:
            True if successful, False otherwise
        """
        self.logger.info(f"Storing GTFS-RT data from {feed_url}")
        
        feed_type = data.get('feed_type', 'unknown')
        if self.save_raw_proto and raw_bytes and timestamp:
            # Persist raw protobuf so we can reprocess or audit original payloads later.
            self.store_gtfs_rt_raw(raw_bytes, feed_type, timestamp)

        # Log the data structure for debugging
        if 'trip_updates' in data:
            self.logger.info(f"Trip updates: {len(data['trip_updates'])} records")
        elif 'vehicle_positions' in data:
            self.logger.info(f"Vehicle positions: {len(data['vehicle_positions'])} records")

        # Save to raw data directory
        try:
            import json
            from pathlib import Path
            
            # Create raw data directory if it doesn't exist
            raw_dir = Path("/app/data/raw")
            raw_dir.mkdir(parents=True, exist_ok=True)
            
            # Generate filename with timestamp (JST - container timezone is set to Asia/Tokyo)
            timestamp = timestamp or datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f"gtfs_rt_{feed_type}_{timestamp}.json"
            filepath = raw_dir / filename
            
            # Save data to file
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, default=str, ensure_ascii=False)
            
            self.logger.info(f"GTFS-RT data saved to: {filepath}")
            
        except Exception as e:
            self.logger.error(f"Error saving GTFS-RT data to file: {e}")
            return False
        
        # Upload to Google Drive
        if self.google_drive_manager:
            try:
                # Save data to temporary file
                import tempfile
                
                with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
                    json.dump(data, f, indent=2, default=str)
                    temp_file = f.name
                
                # Upload to Google Drive
                success = self.google_drive_manager.upload_file(
                    temp_file, 
                    file_name=f"gtfs_rt_{data.get('feed_type', 'unknown')}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
                )
                
                # Remove temporary file
                os.unlink(temp_file)
                
                if success:
                    self.logger.info("GTFS-RT data uploaded to Google Drive")
                else:
                    self.logger.warning("Failed to upload GTFS-RT data to Google Drive")
                    
            except Exception as e:
                self.logger.error(f"Error uploading to Google Drive: {e}")
        
        return True

    async def store_gtfs_static_data(
        self,
        data: Dict[str, pd.DataFrame],
        feed_url: str,
        raw_bytes: Optional[bytes] = None,
        timestamp: Optional[str] = None,
    ) -> bool:
        """
        Store GTFS Static data in the database.
        
        Args:
            data: Dictionary of DataFrames with GTFS Static data
            feed_url: URL of the feed
            raw_bytes: Optional raw ZIP payload
            timestamp: Fetch timestamp used for artifact filenames
        
        Returns:
            True if successful, False otherwise
        """
        self.logger.info(f"Storing GTFS Static data from {feed_url}")

        if self.save_raw_static_zip and raw_bytes and timestamp:
            # Persist raw ZIP so we can rehydrate or audit GTFS static inputs.
            self.store_gtfs_static_raw(raw_bytes, timestamp)

        # Log the data structure for debugging
        for table_name, df in data.items():
            self.logger.info(f"GTFS Static table '{table_name}': {len(df)} records")
            if len(df) > 0:
                self.logger.info(f"  Columns: {list(df.columns)}")
                # Log first few rows for debugging
                self.logger.debug(f"  Sample data:\n{df.head()}")
        
        # Save to raw data directory
        try:
            import json
            from pathlib import Path

            # Create raw data directory if it doesn't exist
            raw_dir = Path("/app/data/raw")
            raw_dir.mkdir(parents=True, exist_ok=True)
            
            # Generate filename with timestamp (JST - container timezone is set to Asia/Tokyo)
            timestamp = timestamp or datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f"gtfs_static_{timestamp}.json"
            filepath = raw_dir / filename
            
            # Convert DataFrames to dictionaries for JSON serialization
            json_data = {
                'feed_url': feed_url,
                'timestamp': timestamp,
                'tables': {}
            }
            
            for table_name, df in data.items():
                json_data['tables'][table_name] = df.to_dict('records')
            
            # Save data to file
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(json_data, f, indent=2, default=str, ensure_ascii=False)
            
            self.logger.info(f"GTFS Static data saved to: {filepath}")
            
        except Exception as e:
            self.logger.error(f"Error saving GTFS Static data to file: {e}")
            return False
        
        return True
    
    async def close(self):
        """Close database connections."""
        self.logger.info("Database connections closed (placeholder)")

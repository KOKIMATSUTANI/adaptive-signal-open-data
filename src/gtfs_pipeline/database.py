"""
Database management module for GTFS-RT pipeline.
"""

import asyncio
import json
import logging
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
    
    async def store_gtfs_rt_data(self, data: Dict, feed_url: str) -> bool:
        """
        Store GTFS-RT data in the database.
        
        Args:
            data: Parsed GTFS-RT data
            feed_url: URL of the feed
            
        Returns:
            True if successful, False otherwise
        """
        self.logger.info(f"Storing GTFS-RT data from {feed_url}")
        
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
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            feed_type = data.get('feed_type', 'unknown')
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
    
    async def store_gtfs_static_data(self, data: Dict[str, pd.DataFrame], feed_url: str) -> bool:
        """
        Store GTFS Static data in the database.
        
        Args:
            data: Dictionary of DataFrames with GTFS Static data
            feed_url: URL of the feed
            
        Returns:
            True if successful, False otherwise
        """
        self.logger.info(f"Storing GTFS Static data from {feed_url}")
        
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
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
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

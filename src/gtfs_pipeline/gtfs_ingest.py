"""
GTFS-RT Data Ingestion Module

This module handles the ingestion of GTFS-RT data from various transit agencies,
processing the protobuf data, and storing it in a structured format for analysis.
"""

import asyncio
import logging
import time
import zipfile
import io
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Union
from urllib.parse import urlparse

import aiohttp
import pandas as pd
from google.transit import gtfs_realtime_pb2

from .config import GTFSConfig
from .database import DatabaseManager
from .utils import setup_logging


class GTFSIngest:
    """
    GTFS-RT data ingestion class for collecting real-time transit data.
    """
    
    # Bootstrap ingestion state with configuration, logging and DB access.
    def __init__(self, config: GTFSConfig, db_manager: DatabaseManager):
        """
        Initialize the GTFS-RT ingestion system.
        
        Args:
            config: Configuration object containing feed URLs and settings
            db_manager: Database manager for storing ingested data
        """
        self.config = config
        self.db_manager = db_manager
        self.logger = setup_logging(__name__)
        self.session: Optional[aiohttp.ClientSession] = None
        
    # Open the shared HTTP session when the async context starts.
    async def __aenter__(self):
        """Async context manager entry."""
        self.session = aiohttp.ClientSession(
            timeout=aiohttp.ClientTimeout(total=30),
            headers={'User-Agent': 'GTFS-RT-Ingest/1.0'}
        )
        return self
        
    # Ensure the HTTP session gets closed on context teardown.
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit."""
        if self.session:
            await self.session.close()
    
    # Pull GTFS-RT protobuf payload from the upstream endpoint.
    async def fetch_gtfs_rt_data(self, feed_url: str) -> Optional[bytes]:
        """
        Fetch GTFS-RT data from a given URL.
        
        Args:
            feed_url: URL of the GTFS-RT feed
            
        Returns:
            Raw protobuf data or None if fetch failed
        """
        try:
            self.logger.info(f"Fetching GTFS-RT data from: {feed_url}")
            
            async with self.session.get(feed_url) as response:
                if response.status == 200:
                    data = await response.read()
                    self.logger.info(f"Successfully fetched {len(data)} bytes")
                    return data
                else:
                    self.logger.error(f"HTTP {response.status} error fetching {feed_url}")
                    return None
                    
        except asyncio.TimeoutError:
            self.logger.error(f"Timeout fetching {feed_url}")
            return None
        except Exception as e:
            self.logger.error(f"Error fetching {feed_url}: {e}")
            return None
    
    # Download the GTFS static bundle and unfold the core tables.
    async def fetch_gtfs_static_data(self, feed_url: str) -> Optional[Tuple[Dict[str, pd.DataFrame], bytes]]:
        """
        Fetch and parse GTFS Static data from a given URL.
        
        Args:
            feed_url: URL of the GTFS Static feed (ZIP file)
            
        Returns:
            Tuple of (parsed tables, raw ZIP bytes) or None if fetch failed
        """
        try:
            self.logger.info(f"Fetching GTFS Static data from: {feed_url}")
            
            async with self.session.get(feed_url) as response:
                if response.status == 200:
                    zip_data = await response.read()
                    self.logger.info(f"Successfully fetched {len(zip_data)} bytes of GTFS Static data")
                    
                    # Parse ZIP file
                    gtfs_data = {}
                    with zipfile.ZipFile(io.BytesIO(zip_data)) as zip_file:
                        # Read common GTFS files
                        gtfs_files = [
                            'agency.txt', 'stops.txt', 'routes.txt', 'trips.txt', 
                            'stop_times.txt', 'calendar.txt', 'calendar_dates.txt'
                        ]
                        
                        for file_name in gtfs_files:
                            if file_name in zip_file.namelist():
                                try:
                                    with zip_file.open(file_name) as file:
                                        df = pd.read_csv(file)
                                        gtfs_data[file_name.replace('.txt', '')] = df
                                        self.logger.info(f"Loaded {file_name}: {len(df)} records")
                                except Exception as e:
                                    self.logger.warning(f"Error reading {file_name}: {e}")
                    
                    return gtfs_data, zip_data
                else:
                    self.logger.error(f"HTTP {response.status} error fetching {feed_url}")
                    return None
                    
        except asyncio.TimeoutError:
            self.logger.error(f"Timeout fetching {feed_url}")
            return None
        except Exception as e:
            self.logger.error(f"Error fetching GTFS Static data from {feed_url}: {e}")
            return None
    
    # Route raw GTFS-RT bytes to the correct parser for the feed type.
    def parse_gtfs_rt_data(self, data: bytes, feed_type: str) -> Dict:
        """
        Parse GTFS-RT protobuf data into structured format.
        
        Args:
            data: Raw protobuf data
            feed_type: Type of feed (trip_updates, vehicle_positions)
            
        Returns:
            Parsed data dictionary
        """
        try:
            if feed_type == "trip_updates":
                feed = gtfs_realtime_pb2.FeedMessage()
                feed.ParseFromString(data)
                return self._parse_trip_updates(feed)
            elif feed_type == "vehicle_positions":
                feed = gtfs_realtime_pb2.FeedMessage()
                feed.ParseFromString(data)
                return self._parse_vehicle_positions(feed)
            else:
                self.logger.error(f"Unknown feed type: {feed_type}")
                return {}
                
        except Exception as e:
            self.logger.error(f"Error parsing GTFS-RT data: {e}")
            return {}
    
    # Normalise trip update entities into dictionaries ready for persistence.
    def _parse_trip_updates(self, feed: gtfs_realtime_pb2.FeedMessage) -> Dict:
        """Parse trip updates from GTFS-RT feed."""
        trip_updates = []
        
        for entity in feed.entity:
            if entity.HasField('trip_update'):
                trip_update = entity.trip_update
                update_data = {
                    'trip_id': trip_update.trip.trip_id,
                    'route_id': trip_update.trip.route_id,
                    'direction_id': trip_update.trip.direction_id,
                    'start_time': trip_update.trip.start_time,
                    'start_date': trip_update.trip.start_date,
                    'vehicle_id': trip_update.vehicle.id if trip_update.HasField('vehicle') else None,
                    'timestamp': trip_update.timestamp,
                    'delay': trip_update.delay if trip_update.HasField('delay') else None,
                }
                trip_updates.append(update_data)
        
        return {
            'feed_type': 'trip_updates',
            'timestamp': feed.header.timestamp,
            'gtfs_realtime_version': feed.header.gtfs_realtime_version,
            'trip_updates': trip_updates
        }
    
    # Normalise vehicle position entities into downstream-friendly records.
    def _parse_vehicle_positions(self, feed: gtfs_realtime_pb2.FeedMessage) -> Dict:
        """Parse vehicle positions from GTFS-RT feed."""
        vehicle_positions = []
        
        for entity in feed.entity:
            if entity.HasField('vehicle'):
                vehicle = entity.vehicle
                position_data = {
                    'vehicle_id': vehicle.vehicle.id,
                    'trip_id': vehicle.trip.trip_id,
                    'route_id': vehicle.trip.route_id,
                    'direction_id': vehicle.trip.direction_id,
                    'start_time': vehicle.trip.start_time,
                    'start_date': vehicle.trip.start_date,
                    'current_stop_sequence': vehicle.current_stop_sequence,
                    'current_status': vehicle.current_status,
                    'timestamp': vehicle.timestamp,
                    'position': {
                        'latitude': vehicle.position.latitude,
                        'longitude': vehicle.position.longitude,
                        'bearing': vehicle.position.bearing,
                        'speed': vehicle.position.speed
                    } if vehicle.HasField('position') else None
                }
                vehicle_positions.append(position_data)
        
        return {
            'feed_type': 'vehicle_positions',
            'timestamp': feed.header.timestamp,
            'gtfs_realtime_version': feed.header.gtfs_realtime_version,
            'vehicle_positions': vehicle_positions
        }

    # Execute fetch, parse, and persistence workflow for a real-time feed.
    async def ingest_feed(self, feed_url: str, feed_type: str) -> bool:
        """
        Ingest a single GTFS-RT feed.
        
        Args:
            feed_url: URL of the GTFS-RT feed
            feed_type: Type of feed (trip_updates, vehicle_positions)
            
        Returns:
            True if ingestion was successful, False otherwise
        """
        try:
            # Fetch data
            raw_data = await self.fetch_gtfs_rt_data(feed_url)
            if not raw_data:
                return False
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            
            # Parse protobuf data
            parsed_data = self.parse_gtfs_rt_data(raw_data, feed_type)
            if not parsed_data:
                return False
            
            # Store in database
            success = await self.db_manager.store_gtfs_rt_data(
                parsed_data,
                feed_url,
                raw_bytes=raw_data,
                timestamp=timestamp,
            )
            
            if success:
                self.logger.info(f"Successfully ingested {feed_type} from {feed_url}")
            else:
                self.logger.error(f"Failed to store {feed_type} data from {feed_url}")
            
            return success
            
        except Exception as e:
            self.logger.error(f"Error ingesting {feed_type} from {feed_url}: {e}")
            return False
    
    # Handle the static GTFS bundle ingestion once per run.
    async def ingest_gtfs_static(self) -> bool:
        """
        Ingest GTFS Static data.
        
        Returns:
            True if ingestion was successful, False otherwise
        """
        try:
            # Fetch GTFS Static data
            fetch_result = await self.fetch_gtfs_static_data(self.config.gtfs_static_url)
            if not fetch_result:
                return False
            gtfs_data, raw_zip = fetch_result
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            
            # Store in database
            success = await self.db_manager.store_gtfs_static_data(
                gtfs_data,
                self.config.gtfs_static_url,
                raw_bytes=raw_zip,
                timestamp=timestamp,
            )
            
            if success:
                self.logger.info(f"Successfully ingested GTFS Static data from {self.config.gtfs_static_url}")
            else:
                self.logger.error(f"Failed to store GTFS Static data from {self.config.gtfs_static_url}")
            
            return success
            
        except Exception as e:
            self.logger.error(f"Error ingesting GTFS Static data: {e}")
            return False

    # Run one combined ingestion pass over static and RT feeds.
    async def ingest_all_feeds(self) -> Dict[str, bool]:
        """
        Ingest all configured GTFS-RT feeds and GTFS Static data.
        
        Returns:
            Dictionary mapping feed URLs to success status
        """
        results = {}
        
        # Ingest GTFS Static data first
        static_success = await self.ingest_gtfs_static()
        results[self.config.gtfs_static_url] = static_success
        
        # Ingest GTFS-RT feeds
        for feed_type, feed_urls in self.config.feeds.items():
            for feed_url in feed_urls:
                success = await self.ingest_feed(feed_url, feed_type)
                results[feed_url] = success
                
                # Add delay between requests to be respectful
                await asyncio.sleep(self.config.request_delay)
        
        return results
    
    # Keep ingesting on a schedule until cancelled.
    async def continuous_ingestion(self, interval: int = 60) -> None:
        """
        Run continuous ingestion at specified intervals.
        
        Args:
            interval: Interval in seconds between ingestion cycles
        """
        self.logger.info(f"Starting continuous ingestion with {interval}s intervals")
        
        while True:
            try:
                self.logger.info("Starting ingestion cycle")
                results = await self.ingest_all_feeds()
                successful = sum(1 for success in results.values() if success)
                total = len(results)
                self.logger.info(f"Ingestion cycle completed: {successful}/{total} feeds successful")
                
                # Wait for next cycle
                self.logger.info(f"Waiting {interval} seconds until next cycle...")
                await asyncio.sleep(interval)
                
            except KeyboardInterrupt:
                self.logger.info("Continuous ingestion stopped by user")
                break
            except Exception as e:
                self.logger.error(f"Error in continuous ingestion cycle: {e}")
                self.logger.info(f"Waiting {interval} seconds before retry...")
                await asyncio.sleep(interval)

# Provide a CLI-style entry point when the module is executed directly.
async def main():
    """Main function for running GTFS-RT ingestion."""
    config = GTFSConfig()
    db_manager = DatabaseManager(config.database)
    
    async with GTFSIngest(config, db_manager) as ingest:
        results = await ingest.ingest_all_feeds()
        print(f"Ingestion completed: {sum(results.values())}/{len(results)} feeds successful")


if __name__ == "__main__":
    asyncio.run(main())

"""
Command Line Interface for GTFS-RT pipeline.
"""

import asyncio
import sys
from pathlib import Path
from typing import Optional

import click

from .config import GTFSConfig
from .database import DatabaseManager
from .gtfs_ingest import GTFSIngest
from .utils import setup_logging


@click.group()
@click.option('--config', '-c', type=click.Path(exists=True), help='Configuration file path')
@click.option('--log-level', type=click.Choice(['DEBUG', 'INFO', 'WARNING', 'ERROR']), 
              default='INFO', help='Logging level')
@click.pass_context
def cli(ctx, config: Optional[str], log_level: str):
    """GTFS-RT Data Ingestion Pipeline CLI."""
    ctx.ensure_object(dict)
    
    # Load configuration
    ctx.obj['config'] = GTFSConfig()
    
    # Setup logging
    setup_logging(level=log_level)


@cli.command()
@click.option('--feed-type', type=click.Choice(['trip_updates', 'vehicle_positions', 'realtime', 'gtfs_static', 'all']),
              default='all', help='Type of feed to ingest')
@click.option('--once', is_flag=True, help='Run ingestion once instead of continuously')
@click.option('--interval', type=int, default=60, help='Interval in seconds for continuous ingestion')
@click.pass_context
def ingest(ctx, feed_type: str, once: bool, interval: int):
    """Ingest GTFS-RT data from configured feeds."""
    config = ctx.obj['config']
    
    async def run_ingestion():
        db_manager = DatabaseManager(config.database)
        try:
            await db_manager.initialize()
            
            # Create ingestion instance
            async with GTFSIngest(config, db_manager) as ingest_instance:
                if once:
                    # Run once
                    if feed_type == 'gtfs_static':
                        success = await ingest_instance.ingest_gtfs_static()
                        click.echo(f"GTFS Static ingestion: {'Success' if success else 'Failed'}")
                    elif feed_type in ['trip_updates', 'vehicle_positions']:
                        results = await ingest_instance.ingest_realtime_feeds(feed_types=[feed_type])
                        successful = sum(1 for success in results.values() if success)
                        total = len(results)
                        click.echo(f"{feed_type} ingestion completed: {successful}/{total} feeds successful")
                    elif feed_type == 'realtime':
                        results = await ingest_instance.ingest_realtime_feeds()
                        successful = sum(1 for success in results.values() if success)
                        total = len(results)
                        click.echo(f"Real-time ingestion completed: {successful}/{total} feeds successful")
                    else:  # 'all'
                        results = await ingest_instance.ingest_all_feeds()
                        successful = sum(1 for success in results.values() if success)
                        total = len(results)
                        click.echo(f"Ingestion completed: {successful}/{total} feeds successful")
                else:
                    if feed_type == 'gtfs_static':
                        click.echo(
                            "Continuous ingestion for GTFS Static is not supported. "
                            "Use --once for static downloads.",
                            err=True,
                        )
                        return
                    elif feed_type in ['trip_updates', 'vehicle_positions']:
                        click.echo(
                            f"Starting continuous real-time ingestion for {feed_type} "
                            f"with {interval}s intervals..."
                        )
                        await ingest_instance.continuous_realtime_ingestion(
                            interval=interval,
                            feed_types=[feed_type],
                        )
                    elif feed_type == 'realtime':
                        click.echo(
                            f"Starting continuous real-time ingestion for all feeds "
                            f"with {interval}s intervals..."
                        )
                        await ingest_instance.continuous_realtime_ingestion(interval=interval)
                    else:  # 'all'
                        click.echo(f"Starting continuous ingestion with {interval}s intervals...")
                        await ingest_instance.continuous_ingestion(interval=interval)
            
        except KeyboardInterrupt:
            click.echo("\nIngestion stopped by user")
        except Exception as e:
            click.echo(f"Error during ingestion: {e}", err=True)
            sys.exit(1)
        finally:
            await db_manager.close()
    
    asyncio.run(run_ingestion())


@cli.command()
@click.pass_context
def list_feeds(ctx):
    """List all configured feed URLs."""
    config = ctx.obj['config']
    
    click.echo("Configured GTFS Feeds:")
    click.echo("=" * 30)
    
    # GTFS Static
    click.echo(f"\nGTFS STATIC:")
    click.echo(f"  - {config.gtfs_static_url}")
    
    # GTFS-RT Feeds
    for feed_type, urls in config.feeds.items():
        click.echo(f"\n{feed_type.upper()}:")
        for url in urls:
            click.echo(f"  - {url}")
        
        if not urls:
            click.echo("  (no feeds configured)")


if __name__ == '__main__':
    cli()

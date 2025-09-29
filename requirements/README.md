# Requirements Management

This directory contains Python dependency files for the Tram Delay Reduction Management system.

## File Structure

- `base.txt` - Common dependencies for all jobs
- `ingest.txt` - GTFS data collection dependencies
- `sim.txt` - Simulation dependencies
- `train.txt` - Training dependencies

## Detailed Documentation

See [docs/REQUIREMENTS.md](../docs/REQUIREMENTS.md) for complete dependency management guide.

## Quick Usage

```bash
# Add common dependency
echo "package>=1.0.0" >> requirements/base.txt

# Add job-specific dependency
echo "package>=1.0.0" >> requirements/ingest.txt
```

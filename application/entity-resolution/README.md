# Entity Resolution with Splink

This project implements entity resolution (record linkage/deduplication) using the [Splink](https://github.com/moj-analytical-services/splink) library. It demonstrates both local (DuckDB) and database (PostgreSQL) backends for processing entity matching at scale.

## Overview

Entity resolution is the process of identifying records that refer to the same real-world entity across different data sources or within a single dataset. This implementation uses probabilistic record linkage based on the Fellegi-Sunter model.

## Features

- **Multiple Backends**: Support for DuckDB (local) and PostgreSQL (distributed)
- **Demo Data**: Includes synthetic person records for testing
- **Configurable Matching**: Fuzzy matching on names, dates, emails, and locations
- **Visual Reports**: HTML reports showing match weights and clustering results
- **Makefile Commands**: Convenient commands for all operations

## Installation

```bash
# Install dependencies using uv
make install

# Or manually
uv venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
uv pip install -e .
```

## Quick Start

```bash
# Run the complete demo pipeline
make demo

# This will:
# 1. Load demo data (1000 synthetic person records)
# 2. Train the Splink model
# 3. Generate pairwise predictions
# 4. Create entity clusters
# 5. Generate visualization reports
```

## Data

The project uses two demo datasets from Splink:

1. **fake_1000**: 1,000 synthetic person records with intentional duplicates
   - Columns: unique_id, first_name, surname, dob, city, email, cluster
   
2. **historical_50k**: 50,000 historical person records from Wikidata
   - Columns: unique_id, full_name, first_name, surname, dob, birth_place, postcode_fake, occupation

## Pipeline Components

### 1. Data Exploration
```bash
make explore
```
Downloads and saves demo datasets locally in Parquet format.

### 2. Model Training
```bash
make train
```
Trains the Splink model using expectation-maximization on blocking rules.

### 3. Prediction Generation
```bash
make predict
```
Generates pairwise match probabilities between records.

### 4. Clustering
```bash
make cluster
```
Groups matched records into entities at different probability thresholds (0.95, 0.90, 0.80).

### 5. Report Generation
```bash
make report
```
Creates HTML visualizations showing:
- Match weight distributions
- Waterfall charts for individual comparisons
- Model parameters

## PostgreSQL Backend

For production workloads, use PostgreSQL:

```bash
# Start PostgreSQL (using docker-compose)
cd /workspaces/mono-repo/infrastructure/docker
docker-compose -f postgres-compose.yml up -d

# Run entity resolution with PostgreSQL
cd /workspaces/mono-repo/application/entity-resolution
make postgres-demo
```

## Configuration

The matching configuration in `src/entity_resolution_demo.py` includes:

- **Name Matching**: Jaro-Winkler similarity with thresholds [0.9, 0.8]
- **Date Matching**: Exact match and fuzzy matching within 1 month/year
- **Location Matching**: Exact match with term frequency adjustments
- **Email Matching**: Exact and fuzzy username matching

### Blocking Rules

To improve performance, comparisons are limited to record pairs that match on:
- Same first name AND surname
- Same surname AND date of birth
- Same email address
- Same first name AND city

## Project Structure

```
entity-resolution/
├── src/
│   ├── explore_demo_data.py      # Dataset exploration
│   ├── entity_resolution_demo.py  # Main pipeline (DuckDB)
│   └── entity_resolution_postgres.py # PostgreSQL backend
├── data/                          # Generated data files
│   ├── fake_1000.parquet
│   └── clusters_threshold_*.csv
├── reports/                       # HTML visualization reports
│   ├── match_weights.html
│   └── waterfall_chart.html
├── entity_resolution/             # Package directory
│   └── __init__.py
├── pyproject.toml                 # Project dependencies
├── Makefile                       # Convenience commands
└── README.md                      # This file
```

## Makefile Commands

| Command | Description |
|---------|-------------|
| `make help` | Show all available commands |
| `make install` | Install project dependencies |
| `make demo` | Run full demo pipeline |
| `make explore` | Download and explore datasets |
| `make train` | Train the Splink model |
| `make predict` | Generate match predictions |
| `make cluster` | Create entity clusters |
| `make report` | Generate HTML reports |
| `make postgres-demo` | Run with PostgreSQL backend |
| `make clean` | Remove generated files |
| `make cluster-stats` | View clustering statistics |
| `make shell` | Open Python shell with imports |

## Results

After running the demo, you'll find:

- **Clusters**: Records grouped by entity in `data/clusters_threshold_*.csv`
- **Reports**: Interactive HTML visualizations in `reports/`
- **Statistics**: ~190-195 clusters containing multiple records from 1000 total records

## Advanced Usage

### Custom Data

To use your own data:

1. Prepare a DataFrame with a `unique_id` column
2. Modify the comparisons in `create_splink_settings()`
3. Update blocking rules for your use case
4. Run the pipeline

### Performance Tuning

- Adjust blocking rules to balance recall vs. computation
- Modify probability thresholds for clustering
- Use PostgreSQL for datasets > 1M records
- Enable parallel processing with Spark backend

## Dependencies

- **splink**: Core entity resolution library
- **duckdb**: Local SQL engine
- **pandas**: Data manipulation
- **psycopg2-binary**: PostgreSQL adapter
- **pyarrow**: Parquet file support
- **sqlglot**: SQL parsing for Splink

## References

- [Splink Documentation](https://moj-analytical-services.github.io/splink/)
- [Fellegi-Sunter Model](https://en.wikipedia.org/wiki/Record_linkage#Fellegi-Sunter_model)
- [Entity Resolution Guide](https://github.com/moj-analytical-services/splink/tree/master/docs)

## License

This project uses the open-source Splink library developed by the UK Ministry of Justice.
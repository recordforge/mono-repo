.PHONY: help install clean demo explore train predict cluster report test all postgres-demo

# Default target
help:
	@echo "Entity Resolution Makefile Commands:"
	@echo ""
	@echo "Setup & Installation:"
	@echo "  make install         - Install project dependencies using uv"
	@echo "  make clean           - Remove generated data, reports, and cache files"
	@echo ""
	@echo "Data Operations:"
	@echo "  make explore         - Explore and save demo datasets"
	@echo "  make demo            - Run full entity resolution demo pipeline"
	@echo ""
	@echo "Individual Pipeline Steps:"
	@echo "  make train           - Train the Splink model on demo data"
	@echo "  make predict         - Generate pairwise predictions"
	@echo "  make cluster         - Create entity clusters from predictions"
	@echo "  make report          - Generate visualization reports"
	@echo ""
	@echo "Database Operations:"
	@echo "  make postgres-demo   - Run entity resolution with PostgreSQL backend"
	@echo "  make postgres-load   - Load data into PostgreSQL"
	@echo ""
	@echo "Testing & Quality:"
	@echo "  make test            - Run unit tests"
	@echo "  make lint            - Run code linting"
	@echo "  make format          - Format code with black"
	@echo ""
	@echo "Utility:"
	@echo "  make shell           - Open Python shell with project imports"
	@echo "  make jupyter         - Start Jupyter notebook server"

# Install dependencies
install:
	@echo "Installing dependencies with uv..."
	uv venv .venv
	uv pip install -e .

# Install dev dependencies
install-dev:
	@echo "Installing dev dependencies..."
	uv pip install -e ".[dev]"

# Clean generated files
clean:
	@echo "Cleaning generated files..."
	rm -rf data/*.csv data/*.parquet
	rm -rf reports/*.html
	rm -rf __pycache__ src/__pycache__ entity_resolution/__pycache__
	rm -rf .pytest_cache
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete

# Explore demo datasets
explore:
	@echo "Exploring demo datasets..."
	.venv/bin/python src/explore_demo_data.py

# Run full demo pipeline
demo:
	@echo "Running entity resolution demo pipeline..."
	.venv/bin/python src/entity_resolution_demo.py

# Train model only
train:
	@echo "Training Splink model..."
	.venv/bin/python -c "from src.entity_resolution_demo import *; df = load_demo_data(); settings = create_splink_settings(); linker = Linker(df, settings, DuckDBAPI()); train_model(linker); print('Model trained successfully!')"

# Generate predictions only
predict:
	@echo "Generating predictions..."
	.venv/bin/python -c "from src.entity_resolution_demo import *; df = load_demo_data(); settings = create_splink_settings(); linker = Linker(df, settings, DuckDBAPI()); train_model(linker); predictions = run_predictions(linker); print('Predictions generated!')"

# Create clusters only
cluster:
	@echo "Creating entity clusters..."
	.venv/bin/python -c "from src.entity_resolution_demo import *; df = load_demo_data(); settings = create_splink_settings(); linker = Linker(df, settings, DuckDBAPI()); train_model(linker); predictions = run_predictions(linker); create_clusters(linker, predictions)"

# Generate reports only
report:
	@echo "Generating visualization reports..."
	.venv/bin/python -c "from src.entity_resolution_demo import *; df = load_demo_data(); settings = create_splink_settings(); linker = Linker(df, settings, DuckDBAPI()); train_model(linker); generate_reports(linker)"

# Run with PostgreSQL backend (requires postgres to be running)
postgres-demo:
	@echo "Running entity resolution with PostgreSQL backend..."
	@echo "Note: This requires PostgreSQL to be running and configured"
	.venv/bin/python src/entity_resolution_postgres.py

# Load data into PostgreSQL
postgres-load:
	@echo "Loading data into PostgreSQL..."
	.venv/bin/python -c "import pandas as pd; import psycopg2; from sqlalchemy import create_engine; df = pd.read_parquet('data/fake_1000.parquet'); engine = create_engine('postgresql://postgres:postgres@localhost:5432/entity_resolution'); df.to_sql('fake_persons', engine, if_exists='replace', index=False); print('Data loaded to PostgreSQL!')"

# Run tests
test:
	@echo "Running tests..."
	.venv/bin/pytest tests/ -v

# Lint code
lint:
	@echo "Running linting..."
	.venv/bin/ruff check src/ entity_resolution/

# Format code
format:
	@echo "Formatting code with black..."
	.venv/bin/black src/ entity_resolution/

# Open Python shell with imports
shell:
	@echo "Opening Python shell with project imports..."
	.venv/bin/python -i -c "from src.entity_resolution_demo import *; from splink import *; import pandas as pd; print('Imports loaded: entity_resolution_demo, splink, pandas')"

# Start Jupyter notebook
jupyter:
	@echo "Starting Jupyter notebook..."
	.venv/bin/pip install jupyter
	.venv/bin/jupyter notebook

# Run all steps in sequence
all: clean install explore demo report
	@echo "Full pipeline completed!"

# Check data quality
check-data:
	@echo "Checking data quality..."
	@if [ -f data/fake_1000.parquet ]; then \
		.venv/bin/python -c "import pandas as pd; df = pd.read_parquet('data/fake_1000.parquet'); print(f'Records: {len(df)}'); print(f'Columns: {df.columns.tolist()}'); print(f'Nulls:\\n{df.isnull().sum()}')"; \
	else \
		echo "No data file found. Run 'make explore' first."; \
	fi

# View cluster statistics
cluster-stats:
	@echo "Cluster statistics:"
	@for threshold in 0.95 0.90 0.80; do \
		if [ -f "data/clusters_threshold_$$threshold.csv" ]; then \
			echo "\nThreshold $$threshold:"; \
			.venv/bin/python -c "import pandas as pd; df = pd.read_csv('data/clusters_threshold_$$threshold.csv'); clusters = df.groupby('cluster_id').size(); print(f'  Total clusters: {len(clusters)}'); print(f'  Clusters with >1 record: {(clusters > 1).sum()}'); print(f'  Max cluster size: {clusters.max()}')"; \
		fi \
	done

# Watch for file changes and re-run demo
watch:
	@echo "Watching for changes..."
	@while true; do \
		make demo; \
		echo "Waiting for changes... (Ctrl+C to stop)"; \
		sleep 5; \
	done
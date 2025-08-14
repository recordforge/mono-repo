# Data Platform Monorepo - Global Commands

.PHONY: help setup-all test-all lint-all format-all clean-all clickhouse-local clickhouse-init

PROJECTS = application/orchestration application/data-connectors/ingress application/data-connectors/egress application/transformation application/entity-resolution application/reporting application/research application/shared-lib

help:
	@echo "Available commands:"
	@echo "  make setup-all      - Setup all project environments"
	@echo "  make test-all       - Run tests for all projects"
	@echo "  make lint-all       - Lint all projects"
	@echo "  make format-all     - Format all projects"
	@echo "  make clean-all      - Clean all virtual environments"
	@echo "  make clickhouse-local - Start local ClickHouse"
	@echo "  make clickhouse-init  - Initialize ClickHouse schema"

setup-all:
	@echo "Setting up all projects..."
	@for project in $(PROJECTS); do \
		echo "========================================"; \
		echo "Setting up $$project..."; \
		echo "========================================"; \
		(cd $$project && uv sync) || exit 1; \
	done
	@echo "All projects setup complete!"

test-all:
	@echo "Testing all projects..."
	@for project in $(PROJECTS); do \
		echo "========================================"; \
		echo "Testing $$project..."; \
		echo "========================================"; \
		if [ -d "$$project/tests" ]; then \
			(cd $$project && uv run pytest tests/ -v) || exit 1; \
		else \
			echo "No tests directory found, skipping..."; \
		fi; \
	done
	@echo "All tests complete!"

lint-all:
	@echo "Linting all projects..."
	@for project in $(PROJECTS); do \
		echo "========================================"; \
		echo "Linting $$project..."; \
		echo "========================================"; \
		(cd $$project && uv run black . --check && uv run ruff check .) || exit 1; \
	done
	@echo "All linting complete!"

format-all:
	@echo "Formatting all projects..."
	@for project in $(PROJECTS); do \
		echo "========================================"; \
		echo "Formatting $$project..."; \
		echo "========================================"; \
		(cd $$project && uv run black . && uv run ruff check . --fix) || exit 1; \
	done
	@echo "All formatting complete!"

clean-all:
	@echo "Cleaning all projects..."
	@for project in $(PROJECTS); do \
		echo "Cleaning $$project..."; \
		(cd $$project && rm -rf .venv uv.lock __pycache__ .pytest_cache .ruff_cache); \
	done
	@echo "All projects cleaned!"

# ClickHouse specific commands
clickhouse-local:
	@echo "Starting local ClickHouse..."
	@if [ ! -f infrastructure/docker/clickhouse-compose.yml ]; then \
		echo "Creating ClickHouse Docker Compose file..."; \
		mkdir -p infrastructure/docker; \
		echo "version: '3.8'\n\nservices:\n  clickhouse:\n    image: clickhouse/clickhouse-server:latest\n    container_name: clickhouse-local\n    ports:\n      - '8123:8123'\n      - '9000:9000'\n    volumes:\n      - clickhouse-data:/var/lib/clickhouse\n    environment:\n      CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT: 1\n      CLICKHOUSE_USER: default\n      CLICKHOUSE_PASSWORD: ''\n\nvolumes:\n  clickhouse-data:" > infrastructure/docker/clickhouse-compose.yml; \
	fi
	sudo docker compose -f infrastructure/docker/clickhouse-compose.yml up -d

clickhouse-stop:
	@echo "Stopping local ClickHouse..."
	sudo docker compose -f infrastructure/docker/clickhouse-compose.yml down

clickhouse-init:
	@echo "Initializing ClickHouse schema..."
	@if [ ! -f scripts/clickhouse-init.sql ]; then \
		echo "ClickHouse init script not found. Creating default..."; \
		$(MAKE) create-clickhouse-init; \
	fi
	sudo docker exec -i clickhouse-local clickhouse-client < scripts/clickhouse-init.sql

create-clickhouse-init:
	@echo "Creating ClickHouse initialization script..."
	@mkdir -p scripts
	@printf '%s\n' \
		'-- ClickHouse Schema Initialization' \
		'-- Databases for different layers' \
		'' \
		'-- Raw layer: Direct ingestion from sources' \
		'CREATE DATABASE IF NOT EXISTS raw;' \
		'' \
		'-- Staging layer: Initial transformations' \
		'CREATE DATABASE IF NOT EXISTS staging;' \
		'' \
		'-- Analytics layer: Core business logic' \
		'CREATE DATABASE IF NOT EXISTS analytics;' \
		'' \
		'-- Master data: Entity resolution results' \
		'CREATE DATABASE IF NOT EXISTS master_data;' \
		'' \
		'-- Egress layer: Prepared for export' \
		'CREATE DATABASE IF NOT EXISTS egress;' \
		'' \
		'-- Example table with ClickHouse best practices' \
		'CREATE TABLE IF NOT EXISTS raw.events (' \
		'    event_id UUID DEFAULT generateUUIDv4(),' \
		'    event_time DateTime64(3),' \
		'    user_id UInt64,' \
		'    event_type LowCardinality(String),' \
		'    properties String  -- JSON' \
		') ENGINE = MergeTree()' \
		'ORDER BY (event_time, user_id)' \
		'PARTITION BY toYYYYMM(event_time)' \
		'SETTINGS index_granularity = 8192;' \
		'' \
		"SELECT 'ClickHouse schema initialized successfully!' as status;" \
		> scripts/clickhouse-init.sql
	@echo "ClickHouse init script created at scripts/clickhouse-init.sql"

# Quick start commands
quick-start:
	@echo "Quick start setup..."
	$(MAKE) setup-all
	$(MAKE) clickhouse-local
	@sleep 5  # Wait for ClickHouse to start
	$(MAKE) clickhouse-init
	@echo "========================================" 
	@echo "Quick start complete!"
	@echo "ClickHouse is running on http://localhost:8123"
	@echo "To start working on a project:"
	@echo "  cd <project-name>"
	@echo "  uv run <command>"
	@echo "========================================"
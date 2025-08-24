# Data Platform Monorepo - Global Commands

.PHONY: help setup-all test-all lint-all format-all clean-all postgres-local postgres-init postgres-seed

PROJECTS = application/orchestration application/data-connectors/ingress application/data-connectors/egress application/transformation application/entity-resolution application/reporting application/research application/shared-lib

help:
	@echo "Available commands:"
	@echo "  make setup-all        - Setup all project environments"
	@echo "  make test-all         - Run tests for all projects"
	@echo "  make lint-all         - Lint all projects"
	@echo "  make format-all       - Format all projects"
	@echo "  make clean-all        - Clean all virtual environments"
	@echo "  make postgres-local   - Start local PostgreSQL"
	@echo "  make postgres-stop    - Stop local PostgreSQL"
	@echo "  make postgres-init    - Initialize PostgreSQL schema"
	@echo "  make postgres-seed    - Seed PostgreSQL with test data"
	@echo "  make quick-start      - Quick setup (setup-all + PostgreSQL + test data)"

setup-all:
	@echo "Setting up all projects..."
	@for project in $(PROJECTS); do \
		echo "========================================"; \
		echo "Setting up $$project..."; \
		echo "========================================"; \
		if [ -f "$$project/pyproject.toml" ]; then \
			(cd $$project && uv sync --all-extras) || exit 1; \
		else \
			echo "No pyproject.toml found, skipping..."; \
		fi; \
	done
	@echo "All projects setup complete!"

test-all:
	@echo "Testing all projects..."
	@for project in $(PROJECTS); do \
		echo "========================================"; \
		echo "Testing $$project..."; \
		echo "========================================"; \
		if [ -f "$$project/pyproject.toml" ]; then \
			if [ -d "$$project/tests" ]; then \
				(cd $$project && uv run pytest tests/ -v --tb=short) || true; \
			else \
				echo "No tests directory found, skipping..."; \
			fi; \
		else \
			echo "No pyproject.toml found, skipping..."; \
		fi; \
	done
	@echo "All tests complete!"

lint-all:
	@echo "Linting all projects..."
	@for project in $(PROJECTS); do \
		echo "========================================"; \
		echo "Linting $$project..."; \
		echo "========================================"; \
		if [ -f "$$project/pyproject.toml" ]; then \
			if command -v $$project/.venv/bin/black >/dev/null 2>&1; then \
				(cd $$project && uv run black . --check) || exit 1; \
			fi; \
			if command -v $$project/.venv/bin/ruff >/dev/null 2>&1; then \
				(cd $$project && uv run ruff check .) || exit 1; \
			fi; \
		else \
			echo "No pyproject.toml found, skipping..."; \
		fi; \
	done
	@echo "All linting complete!"

format-all:
	@echo "Formatting all projects..."
	@for project in $(PROJECTS); do \
		echo "========================================"; \
		echo "Formatting $$project..."; \
		echo "========================================"; \
		if [ -f "$$project/pyproject.toml" ]; then \
			if command -v $$project/.venv/bin/black >/dev/null 2>&1; then \
				(cd $$project && uv run black .) || exit 1; \
			fi; \
			if command -v $$project/.venv/bin/ruff >/dev/null 2>&1; then \
				(cd $$project && uv run ruff check . --fix) || exit 1; \
			fi; \
		else \
			echo "No pyproject.toml found, skipping..."; \
		fi; \
	done
	@echo "All formatting complete!"

clean-all:
	@echo "Cleaning all projects..."
	@for project in $(PROJECTS); do \
		echo "Cleaning $$project..."; \
		(cd $$project && rm -rf .venv uv.lock __pycache__ .pytest_cache .ruff_cache); \
	done
	@echo "All projects cleaned!"

# PostgreSQL specific commands
postgres-local:
	@echo "Starting local PostgreSQL..."
	sudo docker compose -f infrastructure/docker/postgres-compose.yml up -d
	@echo "Waiting for PostgreSQL to be ready..."
	@sleep 5
	@sudo docker exec postgres-local pg_isready -U dataplatform || (echo "PostgreSQL not ready, waiting..." && sleep 5)
	@echo "PostgreSQL is running on localhost:5432"

postgres-stop:
	@echo "Stopping local PostgreSQL..."
	sudo docker compose -f infrastructure/docker/postgres-compose.yml down

postgres-init:
	@echo "Initializing PostgreSQL schema..."
	@if [ ! -f scripts/postgres-init.sql ]; then \
		echo "PostgreSQL init script not found!"; \
		exit 1; \
	fi
	@echo "Waiting for PostgreSQL to be ready..."
	@sudo docker exec postgres-local pg_isready -U dataplatform || (echo "PostgreSQL not ready, waiting..." && sleep 5)
	sudo docker exec -i postgres-local psql -U dataplatform -d dataplatform < scripts/postgres-init.sql
	@echo "PostgreSQL schema initialized!"

postgres-seed:
	@echo "Seeding PostgreSQL with test data..."
	@if [ ! -f fixtures/test-data/fake_1000_from_splink_demos.csv ]; then \
		echo "Test data not found. Downloading from Splink repository..."; \
		mkdir -p fixtures/test-data; \
		curl -s https://raw.githubusercontent.com/moj-analytical-services/splink/master/tests/datasets/fake_1000_from_splink_demos.csv \
			-o fixtures/test-data/fake_1000_from_splink_demos.csv; \
		echo "Test data downloaded successfully!"; \
	fi
	@echo "Loading test data into PostgreSQL..."
	@pip install -q psycopg2-binary 2>/dev/null || true
	@python scripts/seed_postgres.py || (echo "Failed to seed data. Ensure PostgreSQL is running and psycopg2 is installed." && exit 1)
	@echo "Test data loaded successfully!"

postgres-quick-start: postgres-stop postgres-local postgres-init 
# postgres-seed ## Quick start PostgreSQL setup

# Quick start commands
quick-start:
	@echo "Quick start setup..."
	$(MAKE) setup-all
	$(MAKE) postgres-local
	@sleep 5  # Wait for PostgreSQL to start
	$(MAKE) postgres-init
	$(MAKE) postgres-seed
	@echo "========================================" 
	@echo "Quick start complete!"
	@echo "PostgreSQL is running on localhost:5432"
	@echo "Database: dataplatform"
	@echo "User: dataplatform"
	@echo "Password: dataplatform"
	@echo ""
	@echo "Test data loaded from Splink repository!"
	@echo ""
	@echo "To start working on a project:"
	@echo "  cd <project-name>"
	@echo "  uv run <command>"
	@echo "========================================"
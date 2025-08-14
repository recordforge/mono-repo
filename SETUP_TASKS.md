# Setup Tasks After Dev Container Rebuild

## Context
The monorepo structure has been created with UV for Python environment management. The dev container Dockerfile has been updated to include `make`. After rebuilding the container, these tasks need to be completed.

## Tasks to Complete

### 1. Install make (if not in rebuilt container)
```bash
sudo apt-get update && sudo apt-get install -y make
```

### 2. Initialize UV environments for all projects
Run from the repository root:
```bash
make setup-all
```

This will run `uv sync` in each of these projects:
- `application/orchestration` (Python 3.11)
- `application/data-connectors/ingress` (Python 3.10)
- `application/data-connectors/egress` (Python 3.10)
- `application/transformation` (Python 3.11)
- `application/entity-resolution` (Python 3.10)
- `application/reporting` (Python 3.11)
- `application/research` (Python 3.12)
- `application/shared-lib` (Python 3.10+)

### 3. Set up ClickHouse (Optional - for local development)
```bash
# Start ClickHouse container
make clickhouse-local

# Wait a few seconds for it to start, then initialize schema
make clickhouse-init
```

### 4. Verify the setup
```bash
# Test that each environment works
cd application/orchestration && uv run python --version  # Should show 3.11.x
cd ../data-connectors/ingress && uv run python --version  # Should show 3.10.x
cd ../egress && uv run python --version  # Should show 3.10.x
cd ../../transformation && uv run python --version  # Should show 3.11.x
cd ../entity-resolution && uv run python --version  # Should show 3.10.x
cd ../reporting && uv run python --version  # Should show 3.11.x
cd ../research && uv run python --version  # Should show 3.12.x
cd ../shared-lib && uv run python --version  # Should show 3.10.x or higher
```

### 5. Quick Start Alternative
If you want to do everything at once:
```bash
make quick-start
```
This will:
- Set up all project environments
- Start ClickHouse locally
- Initialize the ClickHouse schema

## Project Structure Reference
```
/workspaces/mono-repo/
├── application/
│   ├── orchestration/          # Dagster (Python 3.11)
│   ├── data-connectors/
│   │   ├── ingress/           # dlt ingress (Python 3.10)
│   │   └── egress/            # dlt egress (Python 3.10)
│   ├── transformation/         # SQLMesh (Python 3.11)
│   ├── entity-resolution/      # Splink (Python 3.10)
│   ├── reporting/              # Lightdash/dbt (Python 3.11)
│   ├── research/               # Notebooks (Python 3.12)
│   └── shared-lib/             # Shared utilities (Python 3.10+)
├── infrastructure/
├── scripts/
├── docs/
├── Makefile
└── ARCHITECTURE.md
```

## Key Files
- `/workspaces/mono-repo/ARCHITECTURE.md` - Complete architecture documentation
- `/workspaces/mono-repo/Makefile` - Global management commands
- Each project has its own `pyproject.toml` with specific Python version and dependencies

## Notes
- UV automatically detects and uses the correct Python environment when you `cd` into any project directory
- No manual virtual environment activation is needed
- All projects are self-contained with their own dependencies
- ClickHouse is the central data warehouse for all tools
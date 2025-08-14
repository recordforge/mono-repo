# Dev Container Setup with Automatic Virtual Environment Activation

## Overview
This dev container now includes `direnv` for automatic Python virtual environment activation based on the directory you're in. The active virtual environment will be displayed in your terminal prompt with a Python icon (🐍) and the project name.

## How It Works

1. **direnv** is installed in the dev container
2. When you `cd` into any project directory with a `pyproject.toml` and `.venv`, direnv will automatically:
   - Activate the virtual environment
   - Make `python`, `pip`, and other tools available in your PATH

## Initial Setup (After Container Rebuild)

1. Rebuild the dev container to get direnv installed
2. Run the setup script to create `.envrc` files for all projects:
   ```bash
   /workspaces/mono-repo/scripts/setup-direnv.sh
   ```

## Usage

Once set up, simply `cd` into any project directory:

```bash
cd /workspaces/mono-repo/application/orchestration
# Your prompt will show: 🐍 (orchestration) Python 3.11.2
which python  # Will show: /workspaces/mono-repo/application/orchestration/.venv/bin/python
python --version  # Will show: Python 3.11.2
```

The terminal prompt will automatically display:
- 🐍 Python icon indicating a virtual environment is active
- Project name (e.g., "orchestration", "ingress", "transformation")
- Python version being used

No need to:
- Manually activate virtual environments
- Use `uv run` prefix for commands
- Remember which Python version each project uses

## Manual Setup for New Projects

If you create a new project with UV, direnv will automatically set it up when you enter the directory. You can also manually create an `.envrc` file:

```bash
cd your-new-project
echo "source .venv/bin/activate" > .envrc
direnv allow
```

## Troubleshooting

If direnv doesn't activate automatically:

1. Make sure you have `.envrc` in the project directory
2. Run `direnv allow` to trust the `.envrc` file
3. Check that the `.venv` directory exists (run `uv sync` if needed)

## Benefits

- **Automatic activation**: No manual venv activation needed
- **Project isolation**: Each project automatically uses its own Python version
- **Tool compatibility**: Works with all Python tools (pip, pytest, etc.)
- **IDE friendly**: VS Code will also detect the activated environment
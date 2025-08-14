#!/bin/bash

# Script to set up direnv .envrc files for all UV projects in the monorepo

echo "Setting up direnv for all UV projects..."

PROJECTS=(
    "application/orchestration"
    "application/data-connectors/ingress"
    "application/data-connectors/egress"
    "application/transformation"
    "application/entity-resolution"
    "application/reporting"
    "application/research"
    "application/shared-lib"
)

for project in "${PROJECTS[@]}"; do
    if [ -d "$project" ] && [ -f "$project/pyproject.toml" ] && [ -d "$project/.venv" ]; then
        echo "Setting up $project..."
        cat > "$project/.envrc" << 'EOF'
# Automatically activate UV virtual environment
source .venv/bin/activate

# Set custom prompt name to show project name instead of .venv
export VIRTUAL_ENV_PROMPT="($(basename $(pwd)))"

# Optional: Set project-specific environment variables
export PROJECT_NAME=$(basename $(pwd))

# Optional: Add project bin directory to PATH
export PATH="$(pwd)/bin:$PATH"
EOF
        
        # Allow the .envrc file
        (cd "$project" && direnv allow)
        echo "✅ Set up direnv for $project"
    else
        echo "⚠️  Skipping $project (no venv found)"
    fi
done

echo ""
echo "🎉 Direnv setup complete!"
echo ""
echo "Now when you cd into any project directory, the virtual environment will automatically activate."
echo "You can verify this by running 'which python' after entering a project directory."
"""dbt assets for transformation layer."""

from pathlib import Path
from dagster import AssetExecutionContext
from dagster_dbt import DbtCliResource, dbt_assets

# Path to dbt project
DBT_PROJECT_PATH = Path(__file__).parent.parent.parent.parent / "transformation"
DBT_PROFILES_PATH = DBT_PROJECT_PATH / "profiles.yml"


@dbt_assets(
    manifest=DBT_PROJECT_PATH / "target" / "manifest.json",
    project_dir=DBT_PROJECT_PATH,
    profiles_dir=DBT_PROJECT_PATH,
    select="data_transformation",
)
def dbt_assets(context: AssetExecutionContext, dbt: DbtCliResource):
    """Run dbt models."""
    yield from dbt.cli(["build"], context=context).stream()
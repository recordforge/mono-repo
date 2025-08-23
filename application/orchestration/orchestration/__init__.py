"""Dagster orchestration for data platform."""

from dagster import Definitions
from .resources import postgres_resource
from .assets import dbt_assets
from .jobs import daily_data_pipeline
from .schedules import daily_schedule

defs = Definitions(
    assets=[dbt_assets],
    jobs=[daily_data_pipeline],
    schedules=[daily_schedule],
    resources={
        "postgres": postgres_resource,
    }
)
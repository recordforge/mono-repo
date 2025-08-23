"""Schedule definitions."""

from dagster import schedule
from ..jobs.data_pipeline import daily_data_pipeline


@schedule(
    cron_schedule="0 6 * * *",  # Run at 6 AM daily
    job=daily_data_pipeline,
    execution_timezone="UTC",
)
def daily_schedule(context):
    """Daily schedule for data pipeline."""
    return {}
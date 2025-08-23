"""Data pipeline jobs."""

from dagster import job, op, In, Out, DynamicOutput, DynamicOut
import pandas as pd


@op(
    ins={"start": In(bool)},
    out=Out(bool),
    required_resource_keys={"postgres"}
)
def check_raw_data(context, start):
    """Check if raw data is available."""
    with context.resources.postgres.cursor() as cursor:
        cursor.execute("SELECT COUNT(*) FROM raw.person_records")
        count = cursor.fetchone()[0]
        context.log.info(f"Found {count} records in raw.person_records")
        return count > 0


@op(
    ins={"has_data": In(bool)},
    out=Out(bool)
)
def run_transformations(context, has_data):
    """Trigger dbt transformations."""
    if has_data:
        context.log.info("Running dbt transformations...")
        # dbt transformations are handled by dbt_assets
        return True
    else:
        context.log.warning("No data to transform")
        return False


@op(
    ins={"transformed": In(bool)},
    required_resource_keys={"postgres"}
)
def validate_results(context, transformed):
    """Validate transformation results."""
    if transformed:
        with context.resources.postgres.cursor() as cursor:
            # Check staging layer
            cursor.execute("SELECT COUNT(*) FROM staging.stg_person_records")
            staging_count = cursor.fetchone()[0]
            
            # Check analytics layer
            cursor.execute("SELECT COUNT(*) FROM analytics.dim_person")
            analytics_count = cursor.fetchone()[0]
            
            context.log.info(f"Staging records: {staging_count}")
            context.log.info(f"Analytics records: {analytics_count}")
            
            if staging_count > 0 and analytics_count > 0:
                context.log.info("Validation successful!")
            else:
                context.log.error("Validation failed - no records in transformed tables")


@job(resource_defs={"postgres": postgres_resource})
def daily_data_pipeline():
    """Daily data processing pipeline."""
    has_data = check_raw_data(start=True)
    transformed = run_transformations(has_data)
    validate_results(transformed)
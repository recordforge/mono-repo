"""Jobs for Dagster orchestration."""

from .data_pipeline import daily_data_pipeline

__all__ = ["daily_data_pipeline"]
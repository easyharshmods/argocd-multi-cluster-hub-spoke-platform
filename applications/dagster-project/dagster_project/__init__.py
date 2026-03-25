"""
Dagster project with example pipelines.
"""
from dagster_project.telemetry import setup_otel

setup_otel()

from dagster_project.definitions import defs

__all__ = ["defs"]
__version__ = "1.0.0"

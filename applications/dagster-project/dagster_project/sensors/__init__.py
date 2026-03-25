"""
Sensors package - event-driven pipelines.
"""
from dagster_project.sensors.failure_sensor import pipeline_failure_sensor

__all__ = ["pipeline_failure_sensor"]

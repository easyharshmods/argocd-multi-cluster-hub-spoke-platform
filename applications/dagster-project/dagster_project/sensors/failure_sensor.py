"""Run-failure sensor: logs a marker when any Dagster run fails."""
from dagster import run_failure_sensor, RunFailureSensorContext, DefaultSensorStatus


ALERT_MARKER = "ALERT_DAGSTER_RUN_FAILURE"


@run_failure_sensor(name="pipeline_failure_sensor", default_status=DefaultSensorStatus.RUNNING)
def pipeline_failure_sensor(context: RunFailureSensorContext):
    """
    Triggered when any Dagster run fails; logs a single structured marker line
    that CloudWatch Logs metric filters use for alerting.
    """
    dagster_run = context.dagster_run

    if dagster_run.status.value == "FAILURE":
        # Single-line, easy-to-match marker for CloudWatch metric filter.
        context.log.error(
            f"{ALERT_MARKER} job={dagster_run.job_name} run_id={dagster_run.run_id} status={dagster_run.status.value}"
        )

    # Return empty list: we're only monitoring, not launching follow-up runs
    return []


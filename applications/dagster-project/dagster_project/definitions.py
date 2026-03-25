"""
Main definitions file - brings together all assets, jobs, schedules, sensors, and resources.
"""
from dagster import Definitions, ScheduleDefinition, define_asset_job, AssetSelection

# Import assets
from dagster_project.assets.hackernews import (
    hackernews_top_story_ids,
    hackernews_top_stories,
    most_frequent_words,
)
from dagster_project.assets.weather_pipeline import (
    raw_weather_data,
    cleaned_weather_data,
    aggregated_weather_metrics,
    weather_quality_report,
)
from dagster_project.assets.simple_examples import (
    greeting_asset,
    random_numbers,
    number_statistics,
    simple_counter,
)

# Import resources
from dagster_project.resources.resources import hackernews_api_resource

# Import sensors
from dagster_project.sensors.failure_sensor import pipeline_failure_sensor

# Define jobs
hackernews_job = define_asset_job(
    name="hackernews_pipeline",
    selection=AssetSelection.assets(
        hackernews_top_story_ids,
        hackernews_top_stories,
        most_frequent_words,
    ),
    description="Fetch and analyze HackerNews top stories",
)

weather_job = define_asset_job(
    name="weather_pipeline",
    selection=AssetSelection.assets(
        raw_weather_data,
        cleaned_weather_data,
        aggregated_weather_metrics,
        weather_quality_report,
    ),
    description="Process weather data from sensors",
)

simple_examples_job = define_asset_job(
    name="simple_examples",
    selection=AssetSelection.assets(
        greeting_asset,
        random_numbers,
        number_statistics,
        simple_counter,
    ),
    description="Simple example assets for quick testing",
)

# Define schedules
hackernews_schedule = ScheduleDefinition(
    name="daily_hackernews_schedule",
    job=hackernews_job,
    cron_schedule="0 1 * * *",  # Daily at 1 AM UTC
    description="Run HackerNews analysis daily",
)

weather_schedule = ScheduleDefinition(
    name="hourly_weather_schedule",
    job=weather_job,
    cron_schedule="0 * * * *",  # Every hour
    description="Process weather data hourly",
)

# Bring it all together
defs = Definitions(
    assets=[
        # HackerNews assets
        hackernews_top_story_ids,
        hackernews_top_stories,
        most_frequent_words,
        # Weather assets
        raw_weather_data,
        cleaned_weather_data,
        aggregated_weather_metrics,
        weather_quality_report,
        # Simple example assets
        greeting_asset,
        random_numbers,
        number_statistics,
        simple_counter,
    ],
    jobs=[
        hackernews_job,
        weather_job,
        simple_examples_job,
    ],
    schedules=[
        hackernews_schedule,
        weather_schedule,
    ],
    sensors=[
        pipeline_failure_sensor,
    ],
    resources={
        "hackernews_api": hackernews_api_resource,
    },
)

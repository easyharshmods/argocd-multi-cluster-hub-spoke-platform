"""
Assets package - contains all data assets and pipelines.
"""
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

__all__ = [
    "hackernews_top_story_ids",
    "hackernews_top_stories",
    "most_frequent_words",
    "raw_weather_data",
    "cleaned_weather_data",
    "aggregated_weather_metrics",
    "weather_quality_report",
    "greeting_asset",
    "random_numbers",
    "number_statistics",
    "simple_counter",
]

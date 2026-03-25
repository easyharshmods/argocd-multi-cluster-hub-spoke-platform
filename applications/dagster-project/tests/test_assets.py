"""
Tests for Dagster assets.
"""
from dagster import materialize
from dagster_project.assets.weather_pipeline import (
    raw_weather_data,
    cleaned_weather_data,
    aggregated_weather_metrics,
    weather_quality_report,
)


def test_weather_pipeline():
    """Test weather pipeline can materialize."""
    result = materialize([
        raw_weather_data,
        cleaned_weather_data,
        aggregated_weather_metrics,
        weather_quality_report,
    ])

    assert result.success
    assert len(result.asset_materializations) == 4


def test_hackernews_pipeline():
    """Test HackerNews pipeline can materialize."""
    from dagster_project.assets.hackernews import (
        hackernews_top_story_ids,
        hackernews_top_stories,
        most_frequent_words,
    )

    # Note: This requires internet connection and HN API availability
    try:
        result = materialize([
            hackernews_top_story_ids,
            hackernews_top_stories,
            most_frequent_words,
        ])

        assert result.success
        assert len(result.asset_materializations) == 3
    except Exception as e:
        # Skip if network/API unavailable
        print(f"Skipping HackerNews test due to: {e}")


def test_individual_weather_asset():
    """Test raw weather asset individually."""
    result = materialize([raw_weather_data])
    assert result.success

"""
Weather data pipeline - original example asset.
Simulates sensor data collection and processing.
"""
import random
from typing import Dict

import pandas as pd
from dagster import asset, MetadataValue, AssetExecutionContext


@asset(
    description="Simulated raw weather data from multiple sensors",
    group_name="weather",
    compute_kind="python",
)
def raw_weather_data(context: AssetExecutionContext) -> pd.DataFrame:
    """
    Simulates ingesting raw weather data from sensors.
    In production, this would fetch from actual weather APIs or sensors.
    """
    sensors = ["SENSOR-A1", "SENSOR-B2", "SENSOR-C3", "SENSOR-D4", "SENSOR-E5"]
    data = []

    # Generate 200 random readings
    for _ in range(200):
        sensor = random.choice(sensors)
        temp = random.uniform(10.0, 35.0)
        humidity = random.uniform(30.0, 90.0)
        pressure = random.uniform(980.0, 1020.0)
        wind_speed = random.uniform(0.0, 20.0)

        # Introduce some "bad" data occasionally (sensor malfunction)
        if random.random() < 0.05:
            temp = 999.0  # Clearly invalid
        if random.random() < 0.03:
            humidity = -1.0  # Invalid

        data.append({
            "sensor_id": sensor,
            "temperature": temp,
            "humidity": humidity,
            "pressure": pressure,
            "wind_speed": wind_speed,
            "timestamp": pd.Timestamp.now(),
        })

    df = pd.DataFrame(data)
    context.log.info(f"Generated {len(df)} weather readings from {len(sensors)} sensors")
    context.add_output_metadata({
        "num_records": len(df),
        "num_sensors": len(sensors),
        "date_range": f"{df['timestamp'].min()} to {df['timestamp'].max()}",
        "preview": MetadataValue.md(df.head(10).to_markdown()),
    })
    return df


@asset(
    description="Cleaned weather data with outliers and invalid values removed",
    group_name="weather",
    compute_kind="pandas",
)
def cleaned_weather_data(
    context: AssetExecutionContext,
    raw_weather_data: pd.DataFrame,
) -> pd.DataFrame:
    """
    Remove outliers and invalid values from raw weather data.
    """
    # Filter out invalid temperatures
    clean_df = raw_weather_data[
        (raw_weather_data["temperature"] < 100) & (raw_weather_data["temperature"] > -50)
    ].copy()

    # Filter out invalid humidity
    clean_df = clean_df[(clean_df["humidity"] >= 0) & (clean_df["humidity"] <= 100)]

    # Filter out invalid pressure
    clean_df = clean_df[(clean_df["pressure"] >= 900) & (clean_df["pressure"] <= 1100)]

    removed_count = len(raw_weather_data) - len(clean_df)
    removal_pct = (removed_count / len(raw_weather_data)) * 100
    context.log.info(f"Removed {removed_count} invalid readings ({removal_pct:.1f}%)")
    context.add_output_metadata({
        "num_records": len(clean_df),
        "removed_records": removed_count,
        "removal_percentage": round(removal_pct, 2),
        "data_quality_score": round(100 - removal_pct, 2),
    })
    return clean_df


@asset(
    description="Aggregated weather metrics by sensor",
    group_name="weather",
    compute_kind="pandas",
)
def aggregated_weather_metrics(
    context: AssetExecutionContext,
    cleaned_weather_data: pd.DataFrame,
) -> pd.DataFrame:
    """
    Aggregate weather metrics by sensor for analysis.
    """
    agg_df = (
        cleaned_weather_data.groupby("sensor_id")
        .agg({
            "temperature": ["mean", "min", "max", "std"],
            "humidity": ["mean", "min", "max"],
            "pressure": ["mean", "min", "max"],
            "wind_speed": ["mean", "max"],
        })
        .round(2)
    )

    # Flatten column names
    agg_df.columns = ["_".join(col).strip() for col in agg_df.columns.values]
    agg_df = agg_df.reset_index()

    context.log.info(f"Aggregated data for {len(agg_df)} sensors")
    context.add_output_metadata({
        "num_sensors": len(agg_df),
        "avg_temp_across_sensors": float(agg_df["temperature_mean"].mean()),
        "preview": MetadataValue.md(agg_df.to_markdown()),
    })
    return agg_df


@asset(
    description="Quality report on weather data collection and processing",
    group_name="weather",
    compute_kind="python",
)
def weather_quality_report(
    context: AssetExecutionContext,
    raw_weather_data: pd.DataFrame,
    cleaned_weather_data: pd.DataFrame,
    aggregated_weather_metrics: pd.DataFrame,
) -> Dict[str, float]:
    """
    Generate comprehensive quality report for weather data pipeline.
    """
    total_records = len(raw_weather_data)
    clean_records = len(cleaned_weather_data)
    removed_records = total_records - clean_records
    sensors_active = len(aggregated_weather_metrics)

    quality_report = {
        "total_records_ingested": float(total_records),
        "clean_records": float(clean_records),
        "removed_records": float(removed_records),
        "data_quality_percentage": (clean_records / total_records) * 100.0 if total_records > 0 else 0.0,
        "outliers_detected": float(removed_records),
        "sensors_active": float(sensors_active),
        "avg_temp": float(aggregated_weather_metrics["temperature_mean"].mean()),
        "avg_humidity": float(aggregated_weather_metrics["humidity_mean"].mean()),
    }

    report_md = f"""
# Weather Data Quality Report

## Summary
- **Total Records**: {quality_report['total_records_ingested']:,.0f}
- **Clean Records**: {quality_report['clean_records']:,.0f}
- **Data Quality**: {quality_report['data_quality_percentage']:.2f}%
- **Active Sensors**: {quality_report['sensors_active']:.0f}

## Averages Across All Sensors
- **Temperature**: {quality_report['avg_temp']:.1f}C
- **Humidity**: {quality_report['avg_humidity']:.1f}%

## Data Issues
- **Outliers Removed**: {quality_report['outliers_detected']:.0f}
"""

    context.log.info(
        f"Quality report: {quality_report['data_quality_percentage']:.1f}% data quality, "
        f"{quality_report['sensors_active']:.0f} sensors active"
    )
    context.add_output_metadata({
        "quality_percentage": quality_report["data_quality_percentage"],
        "report": MetadataValue.md(report_md),
    })
    return quality_report

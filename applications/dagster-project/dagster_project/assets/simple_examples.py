"""
Simple example assets for quick testing.
These are self-contained and don't require external dependencies.
"""
import random
from typing import Dict, List
from datetime import datetime

from dagster import asset, MetadataValue, AssetExecutionContext


@asset(
    description="Generate a simple greeting message",
    group_name="examples",
    compute_kind="python",
)
def greeting_asset(context: AssetExecutionContext) -> str:
    # TEMP: force a failure to test monitoring
    raise RuntimeError("Intentional failure for monitoring test")

    # (old code below – keep it so you can restore)
    # """
    # A simple asset that generates a greeting.
    # Perfect for testing Dagster without external dependencies.
    # """
    #greeting = "Hello from Dagster! 🎉"
    # context.log.info(f"Generated greeting: {greeting}")
    # context.add_output_metadata({
    #     "message": greeting,
    #     "timestamp": datetime.now().isoformat(),
    #     "asset_type": "simple_example",
    # })
    # return greeting


@asset(
    description="Generate random numbers for demonstration",
    group_name="examples",
    compute_kind="python",
)
def random_numbers(context: AssetExecutionContext) -> List[int]:
    """
    Generate a list of random numbers.
    """
    numbers = [random.randint(1, 100) for _ in range(10)]
    context.log.info(f"Generated {len(numbers)} random numbers")
    context.add_output_metadata({
        "count": len(numbers),
        "min": min(numbers),
        "max": max(numbers),
        "sum": sum(numbers),
        "avg": sum(numbers) / len(numbers),
        "numbers": MetadataValue.json(numbers),
    })
    return numbers


@asset(
    description="Process random numbers and calculate statistics",
    group_name="examples",
    compute_kind="python",
)
def number_statistics(
    context: AssetExecutionContext,
    random_numbers: List[int],
) -> Dict[str, float]:
    """
    Calculate statistics from random numbers.
    """
    total = sum(random_numbers)
    n = len(random_numbers)
    mn = min(random_numbers)
    mx = max(random_numbers)
    stats: Dict[str, float] = {
        "count": float(n),
        "sum": float(total),
        "average": total / n if n else 0.0,
        "min": float(mn),
        "max": float(mx),
        "range": float(mx - mn),
    }
    
    context.log.info(
        f"Calculated stats: avg={stats['average']:.2f}, "
        f"min={stats['min']}, max={stats['max']}"
    )
    stats_table = f"""
| Metric | Value |
|--------|-------|
| Count | {stats['count']} |
| Sum | {stats['sum']} |
| Average | {stats['average']:.2f} |
| Min | {stats['min']} |
| Max | {stats['max']} |
| Range | {stats['range']} |
"""
    context.add_output_metadata({
        "statistics": MetadataValue.md(stats_table),
        "timestamp": datetime.now().isoformat(),
    })
    return stats


@asset(
    description="Simple counter that increments each run",
    group_name="examples",
    compute_kind="python",
)
def simple_counter(context: AssetExecutionContext) -> int:
    """
    A simple counter asset. In a real scenario, this would use a persistent store.
    For now, it just returns a random number to simulate counting.
    """
    counter_value = random.randint(1, 1000)
    context.log.info(f"Counter value: {counter_value}")
    context.add_output_metadata({
        "counter": counter_value,
        "note": "This is a demo counter. In production, use a persistent store.",
    })
    return counter_value

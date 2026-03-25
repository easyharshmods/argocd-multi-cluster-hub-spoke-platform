# Dagster User Code

## Purpose
Contains the Dagster user code package — all assets, jobs, schedules, sensors, and resources that define the data orchestration logic. This layer is built into a Docker image and pushed to ECR for deployment on EKS.

## Why This Approach?
- **Isolated user code**: Dagster user code runs in its own deployment, separate from the webserver and daemon, enabling independent updates without downtime
- **OpenTelemetry integration**: Traces are automatically exported to AWS X-Ray for end-to-end pipeline observability
- **Failure alerting**: A dedicated sensor logs structured markers that CloudWatch metric filters convert into alarms

## Pipelines

| Pipeline | Assets | Schedule | Description |
|----------|--------|----------|-------------|
| HackerNews | 3 | Daily (1 AM UTC) | Fetches and analyzes top stories from the HackerNews API |
| Weather | 4 | Hourly | Simulates sensor data ingestion, cleaning, aggregation, and quality reporting |
| Simple Examples | 4 | — | Dependency-free assets for smoke tests (`greeting_asset`, `random_numbers`, etc.) |

## Prerequisites
- Python 3.12+
- Docker (for building the deployment image)
- Infrastructure applied (for ECR repository URL) -- see `infrastructure/`

## Development
```bash
# Install dependencies
pip install -e ".[dev]"

# Run tests
pytest tests/ -v

# Run Dagster UI locally
dagster dev
```

## Deployment
```bash
# Build and push Docker image to ECR
./build-push.sh
```

## Monitoring Hooks
- **`dagster_project/telemetry.py`**: Initializes OpenTelemetry tracing (OTLP/gRPC) when `OTEL_EXPORTER_OTLP_ENDPOINT` is set. Auto-instruments HTTP requests.
- **`sensors/failure_sensor.py`**: Logs `ALERT_DAGSTER_RUN_FAILURE` markers on failed runs, consumed by CloudWatch metric filters and alarms.

## Structure
```
dagster_project/
├── assets/              # Data assets
│   ├── hackernews.py
│   ├── weather_pipeline.py
│   └── simple_examples.py
├── resources/           # Reusable resources
│   └── resources.py
├── sensors/             # Event-driven triggers
│   └── failure_sensor.py
├── jobs/                # Asset job definitions
├── partitions/          # Time-based partitions
├── telemetry.py         # OpenTelemetry initialization
└── definitions.py       # Main Dagster definitions
```

## Time
~5-10 minutes (build + push)

## Validation
```bash
# Verify image in ECR
aws ecr describe-images --repository-name dagster-user-code --region eu-central-1

# Run tests locally
pytest tests/ -v
```

## Troubleshooting

### Build fails with dependency errors
Ensure `requirements.txt` versions are compatible. Check that `dagster`, `dagster-k8s`, `dagster-postgres`, and `dagster-aws` all share the same version.

### Image push fails (authentication)
```bash
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.eu-central-1.amazonaws.com
```

FROM --platform=linux/amd64 python:3.12.8-slim

ENV PYTHONUNBUFFERED=1 \
    DAGSTER_HOME=/opt/dagster/app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libpq-dev \
    gcc \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create dagster user
RUN useradd -m -u 1000 dagster && \
    mkdir -p /opt/dagster/app && \
    chown -R dagster:dagster /opt/dagster

# Switch to dagster user
USER dagster
WORKDIR /opt/dagster/app

# pip install --user puts scripts in ~/.local/bin; Helm runs "dagster" CLI so it must be on PATH
ENV PATH="/home/dagster/.local/bin:$PATH"

# Copy dependency metadata first (cache layer)
COPY --chown=dagster:dagster pyproject.toml setup.py* ./

# Copy application code
COPY --chown=dagster:dagster . .

# Install the package and all dependencies
RUN pip install --no-cache-dir --user -e .

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:3030/server_info || exit 1

# Expose gRPC port
EXPOSE 3030

# Default command - run Dagster gRPC server with OpenTelemetry auto-instrumentation
CMD ["opentelemetry-instrument", "dagster", "api", "grpc", "-h", "0.0.0.0", "-p", "3030", "-m", "dagster_project"]

FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim

WORKDIR /app

# Copy dependency manifests first for layer caching
COPY pyproject.toml uv.lock ./

# Install production dependencies (no dev, no conversion extras)
RUN uv sync --no-dev --frozen

# Copy application source
COPY src ./src

# Ensure data directories exist
RUN mkdir -p /app/data/raw /app/data/knowledge_base

EXPOSE 8000

VOLUME ["/app/data"]

CMD ["uv", "run", "python", "-m", "distill_anything.main"]

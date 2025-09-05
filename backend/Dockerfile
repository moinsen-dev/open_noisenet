# Use Python 3.9 slim image for librosa compatibility
FROM python:3.9-slim

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    libpq-dev \
    libsndfile1 \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# Install UV package manager
RUN pip install uv

# Create app user
RUN groupadd -r app && useradd -r -g app app

# Set work directory
WORKDIR /app

# Copy project configuration
COPY pyproject.toml ./

# Install dependencies using UV
RUN uv pip install --system -e .

# Copy application code
COPY . .

# Create uploads directory
RUN mkdir -p /app/uploads && chown -R app:app /app/uploads

# Change to app user
USER app

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
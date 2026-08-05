# Stage 1: Builder
FROM python:3.11-slim as builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-slim
WORKDIR /app

# Non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Copy deps from builder with correct ownership
COPY --from=builder --chown=appuser:appuser /root/.local /home/appuser/.local
ENV PATH=/home/appuser/.local/bin:$PATH

# Copy app
COPY --chown=appuser:appuser . .

USER appuser

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

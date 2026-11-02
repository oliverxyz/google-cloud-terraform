# Build context is services/: docker build -f services/api/Dockerfile services
FROM python:3.13-slim-trixie

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.lock ./
RUN pip install --no-cache-dir --no-compile -r requirements.lock

COPY common/ common/
COPY api/ api/

USER 10001:10001

CMD ["python", "-m", "api.main"]

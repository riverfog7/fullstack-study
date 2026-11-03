# 빌드 단계: 외부 의존성을 준비한 뒤 앱을 설치한다.
FROM python:3.12-slim-bookworm AS build
COPY --from=ghcr.io/astral-sh/uv:0.13.4 /uv /bin/uv
WORKDIR /app
ENV UV_PYTHON_DOWNLOADS=0

COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-dev --no-install-project

COPY src/ src/
COPY README.md ./
RUN uv sync --locked --no-dev --no-editable

# 실행 단계: 설치된 앱과 의존성만 가져온다.
FROM python:3.12-slim-bookworm AS runtime
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    APP_ENV=production \
    APP_DATABASE_PATH=/data/tasks.db

COPY --from=build /app/.venv /app/.venv
RUN useradd --create-home app \
    && mkdir /data \
    && chown app:app /data
USER app

EXPOSE 8000
CMD ["backend", "--host", "0.0.0.0", "--port", "8000"]

# TaskBoard backend (FastAPI). Build context: application/backend
FROM python:3.13-alpine
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
RUN apk upgrade --no-cache
COPY requirements.txt .
# install deps, then drop pip/setuptools from the runtime image (build-time tools, frequent CVE source)
RUN pip install --no-cache-dir -r requirements.txt \
 && pip uninstall -y pip setuptools wheel \
 && adduser -D -H -u 10001 appuser
COPY alembic.ini ./
COPY alembic ./alembic
COPY app ./app
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}
USER 10001
EXPOSE 8000
# run DB migrations, then serve
CMD ["sh", "-c", "alembic upgrade head && exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --proxy-headers"]

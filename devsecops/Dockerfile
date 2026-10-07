# Hardened image: small alpine base, OS packages upgraded, non-root user, no debug server.
FROM python:3.13-alpine
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
RUN apk upgrade --no-cache
COPY requirements.txt .
# Install app deps, then remove pip/setuptools from the runtime image: they are only needed at
# build time, and Trivy flagged HIGH CVEs in pip's vendored urllib3/msgpack and in old setuptools.
RUN pip install --no-cache-dir -r requirements.txt \
 && pip uninstall -y pip setuptools wheel
COPY app ./app
RUN adduser -D -H appuser
USER appuser
EXPOSE 5001
CMD ["gunicorn", "--bind", "0.0.0.0:5001", "--workers", "2", "app.app:app"]

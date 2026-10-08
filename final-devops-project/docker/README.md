# Docker — TaskBoard

| File | Image | Notes |
|---|---|---|
| [`backend.Dockerfile`](./backend.Dockerfile) | `taskboard-backend` | `python:3.13-alpine`, deps installed then pip removed, uid 10001, runs `alembic upgrade head` then uvicorn on :8000 |
| [`frontend.Dockerfile`](./frontend.Dockerfile) | `taskboard-frontend` | multi-stage: `node:22-alpine` builds the Vite app → `nginx-unprivileged` (uid 101, :8080) serves it; `BACKEND_URL` env is rendered into the nginx config at start-up |
| [`docker-compose.yml`](./docker-compose.yml) | — | local stack: postgres (healthcheck) + backend + frontend on http://localhost:3000 |

Build contexts are the app folders, so the Dockerfiles live here and are referenced with `-f`:
```bash
docker build -f docker/backend.Dockerfile  -t taskboard-backend  application/backend
docker build -f docker/frontend.Dockerfile -t taskboard-frontend application/frontend
docker compose -f docker/docker-compose.yml up --build
```

# TaskBoard frontend (React + Vite) served by unprivileged nginx. Build context: application/frontend
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginxinc/nginx-unprivileged:1.29-alpine
USER root
# worker_processes "auto" starts one nginx worker per CPU the NODE has (10 on my laptop) - that blew
# through the 64Mi memory limit and got the pods OOMKilled in production. A static site needs 2.
RUN apk upgrade --no-cache \
 && sed -i 's/^worker_processes.*/worker_processes 2;/' /etc/nginx/nginx.conf
USER 101
COPY --from=build /app/dist /usr/share/nginx/html
# the official image renders /etc/nginx/templates/*.template with envsubst at start-up
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
ENV BACKEND_URL=http://backend:8000 \
    NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1
EXPOSE 8080

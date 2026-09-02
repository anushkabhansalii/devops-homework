# Docker Multi-Stage Build Homework

**Name:** Anushka Jain
**Enrollment number:** 24BCS10193

## Task 1: Run the multi-stage Dockerfile

```bash
git clone <repo shared in class>      # repo containing the multi-stage Dockerfile
cd <repo>
docker build -t multistage-app .
docker run -d --name multistage -p 8080:8080 multistage-app
curl http://localhost:8080
docker ps
```

Expected page text: **Hello World from Docker multi-stage build**

### Output

```text
<!-- paste output of: docker build -t multistage-app . -->
```

```text
<!-- paste output of: curl http://localhost:8080 -->
```

```text
<!-- paste output of: docker ps   (must show 0.0.0.0:8080->8080/tcp) -->
```

### Screenshots

![app running](screenshots/app.png)
![docker ps](screenshots/docker-ps.png)

## What a multi-stage build is

A Dockerfile with more than one `FROM`. The first stage (builder) has compilers and dev dependencies and produces the artifact (jar / dist folder / binary). The final stage starts from a small runtime image and only `COPY --from=build` the artifact. Result: much smaller image, no build tools shipped to production.

## Task 3: Deploying 3 different application types with Docker

Done in [`../docker-fundamentals`](../docker-fundamentals): Node.js (port 3000), Python Flask (port 5000), Java (port 8080), plus Apache, React (multi-stage) and Nginx. See that README for Dockerfiles and outputs.

#!/bin/bash
# Builds and runs all 6 Hello World apps, verifies each with curl, and writes README.md.
# Requires Docker Desktop running.  Usage: ./run_all.sh
cd "$(dirname "$0")"
OUT=/tmp/docker-fund-output.txt
: > "$OUT"

log() { echo "$@" | tee -a "$OUT"; }
runcmd() { log "\$ $*"; eval "$@" 2>&1 | tee -a "$OUT"; log ""; }

# name | folder | host port | container port
APPS=(
  "nodejs|nodejs-app|3000|3000"
  "python|python-app|5001|5000"
  "java|java-app|8080|8080"
  "apache|Apache-app|8081|80"
  "react|React-app|8082|80"
  "nginx|nginx-app|8083|80"
)

for entry in "${APPS[@]}"; do
  IFS='|' read -r name folder hport cport <<< "$entry"
  log "=================== $folder ==================="
  runcmd "docker build -t hello-$name ./$folder"
  runcmd "docker run -d --name hello-$name -p $hport:$cport hello-$name"
  sleep 3
  runcmd "curl -s http://localhost:$hport"
done

log "=================== docker ps ==================="
runcmd "docker ps"
log "=================== docker images ==================="
runcmd "docker images | grep hello-"

# ---------------- write README ----------------
cat > README.md <<EOF
# Docker Fundamentals Homework - Hello World Applications

**Name:** Anushka Jain

Six Hello World web apps, each in its own folder with its own Dockerfile. Every app was built, run in a container, and verified in the browser / with \`curl\`.

## Folder structure

\`\`\`text
docker-fundamentals/
├── nodejs-app/   server.js, package.json, Dockerfile        -> port 3000
├── python-app/   app.py (Flask), requirements.txt, Dockerfile -> port 5001
├── java-app/     HelloServer.java, Dockerfile               -> port 8080
├── Apache-app/   index.html, Dockerfile (httpd)             -> port 8081
├── React-app/    Vite + React, multi-stage Dockerfile       -> port 8082
├── nginx-app/    index.html, Dockerfile (nginx)             -> port 8083
├── run_all.sh    builds + runs + verifies everything
└── README.md
\`\`\`

## How each one works

| App | Base image | What the Dockerfile does |
|---|---|---|
| Node.js | \`node:20-alpine\` | copies \`server.js\`, runs \`npm start\` (plain \`http\` server on 3000) |
| Python | \`python:3.12-slim\` | installs Flask from \`requirements.txt\`, runs \`app.py\` on 5000 |
| Java | \`eclipse-temurin:21-jdk-alpine\` | compiles \`HelloServer.java\` with \`javac\`, runs built-in \`HttpServer\` on 8080 |
| Apache | \`httpd:2.4-alpine\` | copies \`index.html\` into \`/usr/local/apache2/htdocs\` |
| React | \`node:20-alpine\` -> \`nginx:alpine\` | stage 1 runs \`npm run build\` (Vite), stage 2 serves \`dist/\` with nginx |
| Nginx | \`nginx:alpine\` | copies \`index.html\` into \`/usr/share/nginx/html\` |

## Commands to build and run

\`\`\`bash
docker build -t hello-nodejs ./nodejs-app  && docker run -d --name hello-nodejs -p 3000:3000 hello-nodejs
docker build -t hello-python ./python-app  && docker run -d --name hello-python -p 5001:5000 hello-python
docker build -t hello-java   ./java-app    && docker run -d --name hello-java   -p 8080:8080 hello-java
docker build -t hello-apache ./Apache-app  && docker run -d --name hello-apache -p 8081:80   hello-apache
docker build -t hello-react  ./React-app   && docker run -d --name hello-react  -p 8082:80   hello-react
docker build -t hello-nginx  ./nginx-app   && docker run -d --name hello-nginx  -p 8083:80   hello-nginx
\`\`\`

Or just run \`./run_all.sh\`.

## Verification

Open in browser: http://localhost:3000, :5001, :8080, :8081, :8082, :8083. Each page shows **Hello World from &lt;app&gt; in Docker**.

## Output from my machine

\`\`\`text
$(cat "$OUT")
\`\`\`

## Screenshots

<!-- add screenshots of the browser pages here, e.g. -->
<!-- ![nodejs](screenshots/nodejs.png) -->

## Cleanup

\`\`\`bash
docker rm -f hello-nodejs hello-python hello-java hello-apache hello-react hello-nginx
\`\`\`
EOF

echo
echo "README.md written. Add browser screenshots to a screenshots/ folder if you want, then push."

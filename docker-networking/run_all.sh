#!/bin/bash
# Docker networking & volume homework. Requires Docker running.  Usage: ./run_all.sh
cd "$(dirname "$0")"
OUT=/tmp/docker-net.txt; : > "$OUT"
run() { echo "\$ $*" | tee -a "$OUT"; eval "$@" 2>&1 | tee -a "$OUT"; echo | tee -a "$OUT"; }

echo "### TASK 1: container networking" | tee -a "$OUT"
docker rm -f frontend backend database apache2-host nginx-bind >/dev/null 2>&1
docker network rm net-frontend net-backend net-db >/dev/null 2>&1
run 'docker network create net-frontend'
run 'docker network create net-backend'
run 'docker network create net-db'
run 'docker run -d --name frontend --network net-frontend nginx:alpine'
run 'docker run -d --name backend  --network net-backend  alpine sleep 3600'
run 'docker run -d --name database --network net-db -e MYSQL_ROOT_PASSWORD=root mysql:8'
echo "# backend joins a second network so it can reach both frontend and database" | tee -a "$OUT"
run 'docker network connect net-frontend backend'
run 'docker network connect net-db backend'
run 'docker network ls'
run 'docker inspect backend --format "{{json .NetworkSettings.Networks}}"'
sleep 5
echo "# connectivity checks" | tee -a "$OUT"
run 'docker exec backend ping -c 2 frontend'
run 'docker exec backend ping -c 2 database'
echo "# frontend and database are NOT on a shared network, so this should FAIL:" | tee -a "$OUT"
run 'docker exec frontend ping -c 2 database'

echo "### TASK 2: host network (Apache2)" | tee -a "$OUT"
run 'docker pull httpd:2.4'
run 'docker run -d --name apache2-host --network host httpd:2.4'
sleep 2
run 'curl -s http://localhost:80'
echo "# NOTE: --network host only works on Linux. On Mac/Windows Docker Desktop use: docker run -d --name apache2-host -p 80:80 httpd:2.4" | tee -a "$OUT"

echo "### TASK 3: bind mount" | tee -a "$OUT"
run 'cat html/index.html'
run 'docker run -d --name nginx-bind -p 8090:80 -v "$(pwd)/html:/usr/share/nginx/html" nginx:alpine'
sleep 2
run 'curl -s http://localhost:8090'
echo "# modify the file on host, no restart" | tee -a "$OUT"
run 'echo "<h1>Hello students - updated without restart</h1>" > html/index.html'
run 'curl -s http://localhost:8090'
run 'echo "<h1>Hello students</h1>" > html/index.html'

run 'docker ps'

cat > README.md <<EOF2
# Docker Networking & Volume Homework

**Name:** Anushka Jain

All output generated on my machine by [\`run_all.sh\`](./run_all.sh).

## Task 1: Container networking
Three containers (frontend = nginx, backend = alpine, database = mysql) on three separate networks. Backend is connected to two extra networks so it can talk to both frontend and database, while frontend and database cannot see each other. Docker's built-in DNS lets containers reach each other by **name** on a shared user-defined network.

## Task 2: Host network
\`--network host\` removes network isolation: the container shares the host's network stack, so Apache is directly on port 80 with no \`-p\` mapping. Only works natively on Linux.

## Task 3: Bind mount
\`-v /host/path:/container/path\` mounts a host folder into the container. Editing \`index.html\` on the host is instantly visible in nginx because it is the same file, no rebuild or restart needed.

## Task 4: Overlay network (research)
- An **overlay network** spans multiple Docker hosts (used with Docker Swarm). Containers on different physical machines get one flat virtual network and can talk by name.
- Works by encapsulating container traffic in **VXLAN** packets over the host network; Swarm manages the routing and a distributed key-value store keeps the IP/MAC mappings in sync.
- Use cases: multi-node microservices, service discovery and load balancing across a cluster, keeping DB traffic on a private network across hosts.
- Create with: \`docker network create -d overlay --attachable my-overlay\` (needs \`docker swarm init\`).

## Full command log with output

\`\`\`text
$(cat "$OUT")
\`\`\`

## Screenshots
<!-- ![task1](screenshots/task1.png) etc. -->

## Cleanup
\`\`\`bash
docker rm -f frontend backend database apache2-host nginx-bind
docker network rm net-frontend net-backend net-db
\`\`\`
EOF2
echo "README.md written in docker-networking/. Push it."

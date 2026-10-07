#!/bin/bash
# Packages the application source into build/ with build metadata (used by the CI "build" job).
set -e
cd "$(dirname "$0")"
rm -rf build && mkdir -p build
cp -r app requirements.txt Dockerfile build/
cat > build/build-info.txt <<INFO
Application: calculator-api (Session 16)
Commit:      ${GITHUB_SHA:-local}
Run:         ${GITHUB_RUN_NUMBER:-local}
Build Date:  $(date -u +%Y-%m-%dT%H:%M:%SZ)
INFO
echo "Build files:"; find build -type f | sort
echo "Build completed successfully."

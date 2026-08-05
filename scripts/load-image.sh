#!/bin/bash
set -euo pipefail
docker build -t hello:local -f app/Dockerfile .
docker tag hello:local localhost:5000/hello:latest
docker push localhost:5000/hello:latest
kind load docker-image localhost:5000/hello:latest

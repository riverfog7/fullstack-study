#!/usr/bin/env bash
# EC2의 ~/fullstack-study/deploy에서 실행합니다.
set -e

docker compose pull
docker compose down
docker compose up -d --wait
docker compose ps
curl -f http://localhost:8080/api/health

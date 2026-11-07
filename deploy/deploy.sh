#!/usr/bin/env bash
set -euo pipefail

# EC2의 ~/study-app/에서 수동 배포와 자동 배포가 같은 파일을 사용한다.
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

docker compose --env-file .env config --quiet
docker compose --env-file .env pull

# 두 서비스를 함께 다시 만들어 Nginx의 백엔드 연결도 갱신한다.
docker compose --env-file .env up -d --force-recreate --wait --wait-timeout 90
docker compose --env-file .env ps

# EC2의 공개 포트를 통해 Nginx와 API의 연결까지 확인한다.
curl --fail --silent --show-error \
  --retry 5 --retry-connrefused --retry-delay 2 \
  http://127.0.0.1:8080/api/health
printf '\n'

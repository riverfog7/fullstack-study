#!/usr/bin/env bash
set -euo pipefail

# 이 파일은 GitHub Actions runner에서 실행한다.
: "${DOCKERHUB_USERNAME:?Set DOCKERHUB_USERNAME}"
: "${IMAGE_TAG:?Set IMAGE_TAG}"
: "${EC2_HOST:?Set EC2_HOST}"
: "${EC2_USER:?Set EC2_USER}"
: "${EC2_SSH_KEY:?Set EC2_SSH_KEY}"
: "${EC2_KNOWN_HOSTS:?Set EC2_KNOWN_HOSTS}"

[[ "$DOCKERHUB_USERNAME" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || exit 1
[[ "$IMAGE_TAG" =~ ^[0-9a-f]{40}$ ]] || exit 1
[[ "$EC2_HOST" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] || exit 1
[[ "$EC2_USER" =~ ^[a-z_][a-z0-9_-]*$ ]] || exit 1

deploy_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ssh_dir="$(mktemp -d)"
trap 'rm -rf -- "$ssh_dir"' EXIT
umask 077

printf '%s\n' "$EC2_SSH_KEY" > "$ssh_dir/key"
printf '%s\n' "$EC2_KNOWN_HOSTS" > "$ssh_dir/known_hosts"
ssh-keygen -F "$EC2_HOST" -f "$ssh_dir/known_hosts" > /dev/null

ssh_options=(
  -i "$ssh_dir/key"
  -o BatchMode=yes
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=yes
  -o "UserKnownHostsFile=$ssh_dir/known_hosts"
  -o ConnectTimeout=15
  -o ServerAliveInterval=15
  -o ServerAliveCountMax=3
)
target="$EC2_USER@$EC2_HOST"

# 앱의 비밀값이 아니라, 이번에 받을 이미지 이름과 버전이다.
printf 'DOCKERHUB_USERNAME=%s\nIMAGE_TAG=%s\n' \
  "$DOCKERHUB_USERNAME" "$IMAGE_TAG" > "$ssh_dir/.env"

ssh "${ssh_options[@]}" "$target" 'mkdir -p ~/study-app'
scp "${ssh_options[@]}" \
  "$deploy_dir/compose.yaml" "$deploy_dir/deploy.sh" "$ssh_dir/.env" \
  "$target:study-app/"
ssh "${ssh_options[@]}" "$target" 'cd ~/study-app && bash deploy.sh'

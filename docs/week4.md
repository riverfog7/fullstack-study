# 4주차: GitHub Actions와 EC2 배포

3주차에 만든 Docker 이미지를 EC2에서 실행합니다. 직접 배포한 뒤 같은 작업을 GitHub Actions로 자동화합니다. 강의 예제를 참고해 각자 만든 프로젝트에 적용합니다.

명령은 Bash 기준입니다. macOS와 Linux는 터미널, Windows는 Git Bash나 WSL을 사용합니다. 모든 로컬 명령은 별도 설명이 없으면 저장소 루트에서 실행합니다.

## 1. 실행 장소와 파일

| 장소 | 실행하는 작업 |
| --- | --- |
| 내 컴퓨터 | 코드 수정, 수동 이미지 빌드·업로드, 처음 EC2 설정 |
| GitHub Actions runner | 검사, 이미지 빌드·업로드, EC2에 배포 명령 전달 |
| EC2 | Docker 이미지 받기, 컨테이너 실행, 서비스 응답 |
| Docker Hub | 빌드한 이미지를 저장하고 전달 |

이번 주 추가 파일입니다.

```text
project/
├── .github/
│   └── workflows/
│       └── deploy.yml
├── deploy/
│   ├── compose.yaml
│   ├── .env.example
│   ├── deploy.sh
│   └── remote.sh
├── backend/
└── frontend/
```

- 루트의 `compose.yaml`: 3주차 로컬 실습용입니다. `build:`로 이미지를 만듭니다.
- `deploy/compose.yaml`: EC2 배포용입니다. `image:`에 적힌 이미지를 받습니다.
- `deploy/deploy.sh`: EC2에서 실행하는 배포 명령입니다. 수동·자동 배포가 같은 파일을 사용합니다.
- `deploy/remote.sh`: Actions runner에서 SSH 접속 정보와 파일을 준비하고 EC2에 명령을 보냅니다.

완성 코드는 `week4` 태그에 있습니다. 3주차 상태에서 직접 추가하려면 변경 사항을 먼저 커밋하고 `git switch -c my-week4 week3`으로 시작합니다. 이 문서의 배포 파일은 4주차에서 추가하는 파일입니다.

## 2. 사전 준비

- 3주차 프로젝트가 `docker compose up --build -d`로 정상 실행되어야 합니다.
- 자기 GitHub 저장소와 `main` 브랜치를 준비합니다.
- Docker Hub 계정을 만들고 로그인합니다.
- AWS 계정 로그인과 계정의 요금·크레딧 조건을 확인합니다.

예제는 Ubuntu 24.04 LTS, x86_64 EC2 한 대와 공개 Docker Hub 이미지 두 개를 사용합니다. Nginx가 웹 요청을 받고 FastAPI로 API 요청을 전달하는 구조는 3주차와 같습니다. 이 앱은 사용자 인증이 없는 실습용 앱이므로 공개해도 되는 테스트 데이터만 사용합니다.

## 3. 내 컴퓨터에서 이미지 업로드

### 3.1 Docker Hub 저장소

Docker Hub에서 자신의 계정 아래에 `study-backend`, `study-frontend` 저장소를 만들고 공개 상태로 설정합니다. 예제의 EC2는 공개 이미지를 받으므로 Docker Hub 로그인 정보가 필요하지 않습니다.

내 컴퓨터의 저장소 루트에서 다음 변수를 설정합니다. `myname`은 실제 Docker Hub 계정명으로 바꿉니다.

```bash
export DOCKERHUB_USERNAME=myname
export IMAGE_TAG=week4-demo
docker login --username "$DOCKERHUB_USERNAME"
```

로그인에는 Docker Hub에서 발급한 Personal Access Token을 사용합니다. 토큰에는 이미지 업로드에 필요한 Read & Write 권한을 주고, 비밀번호 입력 위치에 토큰을 입력합니다. 명령 뒤에 토큰 문자열을 직접 적거나 Git에 저장하지 않습니다.

### 3.2 백엔드 이미지

```bash
docker build --platform linux/amd64 \
  -t "docker.io/$DOCKERHUB_USERNAME/study-backend:$IMAGE_TAG" ./backend
docker push "docker.io/$DOCKERHUB_USERNAME/study-backend:$IMAGE_TAG"
```

### 3.3 프론트 이미지

```bash
docker build --platform linux/amd64 \
  -t "docker.io/$DOCKERHUB_USERNAME/study-frontend:$IMAGE_TAG" ./frontend
docker push "docker.io/$DOCKERHUB_USERNAME/study-frontend:$IMAGE_TAG"
```

Apple Silicon Mac에서도 x86_64 EC2에서 실행할 수 있도록 `--platform linux/amd64`를 사용합니다. Docker Hub에서 두 저장소에 `week4-demo` 태그가 생겼는지 확인합니다.

## 4. EC2 준비

### 4.1 인스턴스 생성

AWS 콘솔에서 리전을 하나 정하고 EC2 인스턴스를 만듭니다.

| 설정 | 예제 기준 |
| --- | --- |
| 이름 | `study-app` |
| AMI | Ubuntu Server 24.04 LTS, 64-bit x86 |
| 인스턴스 유형 | x86_64 유형 한 대, 예: `t3.micro` |
| SSH 사용자 | `ubuntu` |
| 키 페어 | 관리용 키를 생성하고 개인 키를 보관 |
| 네트워크 | 인터넷 연결이 가능한 퍼블릭 서브넷, 공인 IPv4 할당 |
| 스토리지 | 실습에 필요한 용량을 확인하고 생성 |

인스턴스 유형을 골랐다는 이유만으로 무료가 되는 것은 아닙니다. 콘솔의 현재 요금, 계정 플랜, 크레딧을 확인합니다. 이 예제는 서버에서 이미지를 빌드하지 않습니다.

보안 그룹의 초기 인바운드 규칙은 다음과 같습니다.

| 포트 | 용도 | 소스 |
| --- | --- | --- |
| TCP 22 | 내 컴퓨터에서 SSH 접속 | My IP |
| TCP 8080 | 브라우저에서 웹 앱 접속 | 실습 공개 범위, 예: `0.0.0.0/0` |

백엔드 8000번 포트는 컨테이너 네트워크 안에서 사용하므로 외부 인바운드 규칙을 추가하지 않습니다. `0.0.0.0/0`은 모든 IPv4 주소를 뜻합니다.

### 4.2 서버의 호스트 키 확인

관리용 개인 키를 내 컴퓨터의 `~/.ssh/week4-admin.pem`에 보관합니다. EC2 공인 IPv4 주소를 아래 변수에 넣습니다.

```bash
export EC2_HOST=203.0.113.10
chmod 600 ~/.ssh/week4-admin.pem
ssh-keyscan -T 10 -t ed25519 "$EC2_HOST" > ec2_known_hosts
ssh-keygen -lf ec2_known_hosts
```

`203.0.113.10`은 문서용 예시 주소입니다. 실제 인스턴스 주소로 바꿉니다.

AWS 콘솔에서 인스턴스를 선택한 뒤 **Actions → Monitor and troubleshoot → Get system log**를 엽니다. `BEGIN SSH HOST KEY FINGERPRINTS` 구간의 ED25519 SHA256 지문과 위 명령의 지문을 대조합니다. **두 지문이 일치한 경우에만** 다음 접속을 진행합니다. `ssh-keyscan`으로 받은 값만으로는 서버의 신원을 확인할 수 없습니다.

AWS의 Key pairs 화면에 보이는 지문은 사용자 키 페어의 지문입니다. 여기서 비교하는 서버 호스트 키와 다릅니다. 처음 확인한 `ec2_known_hosts`는 이후 수동 접속과 GitHub Secret 등록에 사용합니다.

### 4.3 SSH 접속

내 컴퓨터에서 실행합니다.

```bash
ssh -i ~/.ssh/week4-admin.pem \
  -o UserKnownHostsFile=ec2_known_hosts \
  -o StrictHostKeyChecking=yes \
  ubuntu@"$EC2_HOST"
```

이제 입력하는 명령은 EC2에서 실행됩니다. 접속을 끝내고 내 컴퓨터로 돌아오려면 `exit`를 입력합니다.

### 4.4 Docker와 Compose 설치

새 Ubuntu 24.04 EC2 안에서 실행합니다. 공식 Docker apt 저장소를 추가합니다.

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: noble
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker ubuntu
exit
```

위의 SSH 명령으로 다시 접속한 뒤 확인합니다. 그룹 변경은 새 로그인부터 적용됩니다.

```bash
docker version
docker compose version
```

`docker` 그룹은 Docker 데몬을 조작할 수 있는 강한 권한을 줍니다. 이 실습에서는 `ubuntu` 계정으로 서버를 관리합니다. 이를 제한된 권한의 운영 계정으로 보지는 않습니다.

## 5. EC2에 수동 배포

### 5.1 배포 파일 복사

내 컴퓨터의 저장소 루트에서 실행합니다. EC2 접속 상태라면 먼저 `exit`로 돌아옵니다.

```bash
ssh -i ~/.ssh/week4-admin.pem \
  -o UserKnownHostsFile=ec2_known_hosts \
  -o StrictHostKeyChecking=yes \
  ubuntu@"$EC2_HOST" 'mkdir -p ~/study-app'

scp -i ~/.ssh/week4-admin.pem \
  -o UserKnownHostsFile=ec2_known_hosts \
  -o StrictHostKeyChecking=yes \
  deploy/compose.yaml deploy/deploy.sh deploy/.env.example \
  ubuntu@"$EC2_HOST":study-app/
```

서버에는 배포 파일과 설정만 복사합니다. Python·Node 프로젝트 소스는 이미 빌드한 이미지 안에 들어 있습니다.

### 5.2 이미지 이름과 버전 설정

EC2에 다시 SSH 접속하고 실행합니다.

```bash
cd ~/study-app
cp .env.example .env
nano .env
```

`.env`를 실제 Docker Hub 계정명으로 수정합니다.

```dotenv
DOCKERHUB_USERNAME=myname
IMAGE_TAG=week4-demo
```

이 값은 Compose 파일의 `${DOCKERHUB_USERNAME}`, `${IMAGE_TAG}` 자리에 들어갑니다. `.env`에 썼다는 이유로 모든 값이 자동으로 앱의 환경 변수가 되는 것은 아닙니다. 앱에 전달할 값은 Compose의 `environment:`에 적습니다.

### 5.3 실행과 확인

EC2의 `~/study-app/`에서 실행합니다.

```bash
bash deploy.sh
```

`deploy.sh`는 설정 확인, 이미지 받기, 컨테이너 갱신, API 응답 확인을 순서대로 실행합니다.

```bash
docker compose --env-file .env config --quiet
docker compose --env-file .env pull
docker compose --env-file .env up -d --force-recreate --wait --wait-timeout 90
docker compose --env-file .env ps
curl --fail http://127.0.0.1:8080/api/health
```

- `--wait`는 healthcheck가 있는 백엔드의 정상 상태를 기다립니다. 프론트는 실행 상태를 기다립니다.
- 마지막 HTTP 요청은 EC2의 8080번 포트에서 Nginx를 거쳐 FastAPI까지 응답하는지 확인합니다.
- `--force-recreate`로 두 컨테이너를 같이 갱신합니다. Nginx가 변경된 백엔드 컨테이너 주소를 다시 찾게 합니다. 교체 중에는 잠깐 접속이 끊길 수 있습니다.
- Compose의 `name: study-app`으로 프로젝트 이름을 고정합니다. 수동·자동 배포가 같은 `study-app_task-data` 볼륨을 사용하므로 컨테이너 교체 후에도 DB를 유지합니다. 이 볼륨은 해당 EC2 안에 저장됩니다.

내 컴퓨터의 브라우저에서 `http://<EC2 공인 IP>:8080`에 접속합니다. 할 일을 하나 추가해둡니다.

## 6. GitHub Actions로 검사 실행

완성된 workflow는 [.github/workflows/deploy.yml](../.github/workflows/deploy.yml)에 있습니다. `main`에 push하거나 Actions 화면에서 **Run workflow**를 누르면 시작합니다.

`test` job은 다음 순서입니다.

1. 해당 커밋의 코드를 runner에 가져옵니다.
2. uv 0.13.4, Python 3.12, Node.js 24를 준비합니다.
3. `uv sync --locked --project backend`와 `npm --prefix frontend ci`로 의존성을 설치합니다.
4. `pre-commit run --all-files`로 기존 공통 검사, 백엔드 테스트, 프론트 검사·테스트를 실행합니다.
5. 프론트를 빌드하고 배포 파일의 문법과 Compose 설정을 확인합니다.

pre-commit 안에서 이미 pytest·ESLint·TypeScript·Vitest를 실행하므로 같은 테스트를 별도 step으로 다시 실행하지 않습니다. Actions의 검사 로그에서 각 hook의 결과를 확인합니다.

완성 workflow에는 이미지 업로드와 배포도 들어 있으므로, 전체 실행 전에 다음 절의 Secrets를 준비합니다. 강의에서 CI 부분만 먼저 작성할 때는 `test` job까지만 작성해 실행한 뒤 `publish`, `deploy`를 이어 붙입니다.

## 7. 자동 배포 연결

### 7.1 CI 전용 SSH 키

내 컴퓨터에서 CI에 사용할 별도 키를 만듭니다. 기존 키 파일이 있다면 덮어쓰지 말고 다른 이름을 사용합니다.

```bash
ssh-keygen -t ed25519 -C week4-github-actions \
  -f ~/.ssh/week4-deploy -N ''
```

공개 키를 관리용 접속으로 EC2에 등록합니다.

```bash
cat ~/.ssh/week4-deploy.pub | ssh -i ~/.ssh/week4-admin.pem \
  -o UserKnownHostsFile=ec2_known_hosts \
  -o StrictHostKeyChecking=yes \
  ubuntu@"$EC2_HOST" \
  'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys'
```

개인 키 `~/.ssh/week4-deploy`는 GitHub Secret에 넣고, 공개 키 `.pub`는 EC2에서 접속을 허용하는 데 사용합니다. 서버의 신원을 확인하는 `ec2_known_hosts`와는 용도가 다릅니다.

### 7.2 GitHub Secrets

자신의 저장소에서 **Settings → Secrets and variables → Actions → New repository secret**으로 다음 값을 등록합니다.

| 이름 | 넣을 값 |
| --- | --- |
| `DOCKERHUB_USERNAME` | Docker Hub 계정명 |
| `DOCKERHUB_TOKEN` | Docker Hub Read & Write Personal Access Token |
| `EC2_HOST` | 현재 EC2 공인 IPv4 주소 또는 고정한 DNS 이름 |
| `EC2_USER` | `ubuntu` |
| `EC2_SSH_KEY` | `~/.ssh/week4-deploy` 개인 키 전체, BEGIN/END 줄 포함 |
| `EC2_KNOWN_HOSTS` | 지문을 검증한 `ec2_known_hosts` 파일 전체 |

`EC2_KNOWN_HOSTS`는 Secret의 `EC2_HOST`와 정확히 같은 IP 또는 이름으로 만들어야 합니다. workflow 안에서 새 호스트 키를 자동으로 신뢰하지 않습니다. 사용자 이름과 주소가 모두 비밀인 것은 아니지만, 예제에서는 연결 설정을 같은 화면에서 등록합니다.

### 7.3 Actions가 SSH로 접속할 수 있는 범위

내 컴퓨터에서 SSH가 성공해도 Actions runner에서 접속할 수 있다는 뜻은 아닙니다. **My IP 규칙은 내 컴퓨터만 허용합니다.** 표준 GitHub-hosted runner의 출발 IP는 실행마다 달라질 수 있습니다.

이 수업의 자동 배포 시연은 다음 조건으로 진행합니다.

1. SSH 개인 키, 검증한 서버 호스트 키, GitHub Secrets를 준비합니다.
2. **시연 시간에만** TCP 22번의 소스를 `0.0.0.0/0`으로 임시 변경합니다. 이는 모든 IPv4 주소에서 SSH 연결을 시도할 수 있게 하는 설정입니다. 키 인증을 사용하고 암호 로그인을 켜지 않습니다.
3. 배포가 끝나면 즉시 22번 규칙을 My IP로 되돌립니다.

**My IP로 되돌린 뒤에는 일반 hosted runner의 자동 SSH 배포가 다시 차단됩니다.** 이 넓은 접근 범위를 상시 운영 설정으로 유지하지 않습니다. 지속적인 자동 배포에는 고정된 송신 IP의 runner 등 접속 범위를 제한할 구성이 필요합니다. 이 예제는 AWS 키를 사용하거나 보안 그룹을 자동으로 변경하지 않습니다.

### 7.4 검사, 이미지 업로드, 배포

workflow의 세 job은 `test`, `publish`, `deploy`입니다. `needs`로 순서를 연결합니다.

| job | 작업 |
| --- | --- |
| `test` | 기존 검사와 프론트 빌드, 배포 파일 문법 확인 |
| `publish` | 성공한 커밋으로 두 이미지를 만들고 Docker Hub에 업로드 |
| `deploy` | EC2에 Compose·배포 스크립트·이미지 설정을 복사하고 실행 |

두 이미지의 `IMAGE_TAG`는 같은 `${{ github.sha }}`입니다. 여기에는 workflow를 시작한 커밋의 전체 ID가 들어갑니다. EC2는 그 버전의 이미지 두 개를 받습니다. `publish`는 `main`에서만 진행합니다.

`concurrency`와 `cancel-in-progress: false`는 이미 진행 중인 배포를 중간에 취소하거나 같은 서버에 동시에 배포하는 일을 막습니다. 새 실행들이 쌓이면 대기 중인 실행이 더 새로운 실행으로 대체될 수 있습니다.

`remote.sh`는 runner의 임시 폴더에 키와 `known_hosts`를 만들고 `StrictHostKeyChecking=yes`로 접속합니다. 복사할 때마다 EC2의 같은 `~/study-app/`을 사용합니다. 종료 시 runner의 임시 키 파일은 지웁니다.

## 8. 전체 흐름 확인

1. 화면 문구를 바꾸고 짧은 Conventional Commit 메시지로 커밋합니다.
2. `main`에 push합니다.
3. Actions의 `test`, `publish`, `deploy` 결과를 확인합니다.
4. Docker Hub에서 두 저장소에 같은 커밋 태그가 생겼는지 확인합니다.
5. 웹을 새로고침해 화면 변경과 이전에 저장한 할 일을 확인합니다.
6. 시연을 마치면 SSH 인바운드를 My IP로 복구합니다.

검사나 이미지 업로드가 실패하면 `deploy` job은 실행되지 않습니다. 서버 갱신 도중 실패한 경우에는 이미 일부 컨테이너가 바뀌었을 수 있습니다. 이 예제는 자동 롤백을 구현하지 않습니다. 로그를 확인하고 정상 동작했던 이미지 태그로 `.env`를 바꾼 뒤 `bash deploy.sh`로 다시 실행할 수 있습니다.

## 9. 오류 확인

| 증상 | 확인할 곳 |
| --- | --- |
| `test` 실패 | Actions에서 실패한 hook·step의 로그 |
| Docker Hub 업로드 거부 | 계정명, PAT의 쓰기 권한, 저장소 이름 |
| `no matching manifest` | 이미지 플랫폼과 EC2 아키텍처가 모두 amd64인지 |
| SSH timeout | EC2 공인 IP, 보안 그룹 22번의 출발 IP 허용 범위 |
| `Permission denied (publickey)` | `EC2_USER`, 개인 키, 서버의 `authorized_keys` |
| 호스트 키 확인 실패 | 현재 서버의 지문을 다시 검증하고 `EC2_KNOWN_HOSTS` 갱신 |
| `unhealthy` 또는 API 응답 실패 | EC2의 `docker compose logs backend frontend` |
| 웹 접속 실패 | 보안 그룹 8080번, `docker compose ps`, 공인 IP |

EC2에서 실행하는 기본 확인 명령입니다.

```bash
cd ~/study-app
docker compose ps --all
docker compose logs --tail 100 backend frontend
curl --fail http://127.0.0.1:8080/api/health
```

일반 공인 IPv4 주소는 인스턴스를 중지했다가 시작하면 바뀔 수 있습니다. 바뀌면 브라우저 접속 주소와 `EC2_HOST`, 검증한 `EC2_KNOWN_HOSTS`를 함께 갱신합니다. 호스트 키 불일치를 해결하려고 확인 기능을 끄지 않습니다.

## 10. 과제와 정리

자기 프로젝트에 Docker 이미지 저장소, EC2 배포 설정, GitHub Actions 검사를 적용합니다. 코드 수정 후 검사와 이미지 업로드, 배포 결과를 확인하고 저장소에 남깁니다. 토큰·개인 키·실제 `.env`를 커밋하지 않습니다.

실습을 계속할 때는 컨테이너와 데이터를 유지할 수 있습니다. 실습을 마쳤으면 AWS 콘솔에서 인스턴스와 남은 리소스를 확인해 정리합니다. EC2 중지 후에도 보관한 스토리지 등의 비용이 남을 수 있습니다. EC2 종료 시 삭제되는 스토리지에는 이 앱의 DB도 있으므로 필요한 데이터는 먼저 따로 보관합니다.

다음 주에는 이번에 콘솔로 만든 인프라를 Terraform으로 구성합니다.

## 공식 문서

- [EC2 시작하기](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EC2_GetStarted.html)
- [EC2 접속 전 준비와 호스트 키 확인](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/connection-prereqs-general.html)
- [EC2 보안 그룹 규칙](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/security-group-rules-reference.html)
- [Docker Ubuntu 설치](https://docs.docker.com/engine/install/ubuntu/)
- [Docker Hub 토큰](https://docs.docker.com/security/access-tokens/)
- [Docker Compose pull](https://docs.docker.com/reference/cli/docker/compose/pull/)
- [Docker Compose up](https://docs.docker.com/reference/cli/docker/compose/up/)
- [GitHub Actions workflow 문법](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets)
- [Docker 이미지 게시](https://docs.github.com/en/actions/tutorials/publish-packages/publish-docker-images)
- [GitHub-hosted runner의 IP 주소](https://docs.github.com/en/actions/reference/runners/github-hosted-runners#ip-addresses)
- [uv의 GitHub Actions 연동](https://docs.astral.sh/uv/guides/integration/github/)
- [Ubuntu 24.04 runner의 설치 도구](https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md)

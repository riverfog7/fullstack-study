# 4주차: GitHub Actions와 EC2 배포

3주차에 만든 앱을 EC2에서 실행하고, 같은 배포 작업을 GitHub Actions로 연결합니다. 예제의 이름과 검사 명령은 각자 만든 프로젝트에 맞게 바꾸면 됩니다.

명령은 **macOS·Linux의 Bash 터미널 기준**입니다. Windows에서는 키를 실제로 저장한 폴더에서 시작하고 [AWS의 OpenSSH 접속 안내](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/connect-linux-inst-ssh.html)를 참고합니다. 아래 `~/Downloads`가 Windows의 다운로드 폴더와 같다는 뜻은 아닙니다. 각 코드 위에 실행할 컴퓨터와 폴더를 표시했습니다.

## 1. 이번에 사용하는 파일

| 파일 | 역할 |
| --- | --- |
| 루트의 `compose.yaml` | 3주차 로컬 실행용. `build:`로 이미지를 만듭니다. |
| `deploy/compose.yaml` | EC2 배포용. `image:`에 적힌 이미지를 받습니다. |
| `deploy/.env.example` | Docker Hub 계정명과 이미지 태그의 예시입니다. |
| `deploy/deploy.sh` | EC2에서 실행하는 배포 명령입니다. |
| `.github/workflows/deploy.yml` | 검사, 이미지 게시, EC2 배포 순서입니다. |

수정된 완성 코드는 현재 `main`에 있습니다. `week2`, `week3`, `week4` 태그로 각 주차의 기존 시점도 확인할 수 있습니다. 실습에서는 **자기 공개 GitHub 저장소의 `main`**에 설정을 추가합니다. 배포 파일을 먼저 커밋·push해 두어야 EC2에서 clone할 때 함께 내려받습니다.

이번 예제는 공개 GitHub 저장소, 공개 Docker Hub 이미지 두 개, Ubuntu 24.04 LTS의 x86_64 EC2 한 대를 사용합니다. 데이터는 공개해도 되는 테스트 내용으로 준비합니다.

## 2. Docker Hub 준비

### 2.1 이미지 저장소 만들기

Docker Hub에 로그인하고 **My Hub → Repositories → Create repository**에서 두 저장소를 만듭니다.

- `study-backend`: Public
- `study-frontend`: Public

이 문서의 `myname`은 자신의 **Docker Hub 계정명**으로 바꿉니다. GitHub 사용자 이름과 같을 필요는 없습니다.

### 2.2 PAT 발급과 로그인

PAT는 Docker Hub에서 비밀번호 대신 사용할 로그인 토큰입니다.

1. Docker Home에 로그인합니다.
2. 프로필 메뉴에서 **Account settings → Personal access tokens**를 엽니다.
3. **Generate new token**을 누릅니다.
4. 설명에 `study-deploy`, 만료일에 `30 days`, 권한에 **Repo Read & Write**를 선택합니다.
5. 생성된 토큰을 복사해 보관합니다. 전체 토큰은 생성 직후에만 볼 수 있습니다.

내 컴퓨터의 터미널에서 실행합니다.

```bash
docker login -u myname
```

`Password:`에 토큰을 붙여넣고 Enter를 누릅니다. 입력한 글자가 화면에 보이지 않아도 정상입니다. 같은 토큰을 뒤에서 GitHub의 `DOCKERHUB_TOKEN`에 등록합니다.

[Docker 공식 PAT 안내](https://docs.docker.com/security/access-tokens/personal-access-tokens/)

## 3. 내 컴퓨터에서 이미지 업로드

### 3.1 백엔드

내 컴퓨터의 저장소 루트에서 시작합니다.

```bash
cd backend
docker build --platform linux/amd64 -t study-backend .
docker tag study-backend myname/study-backend:week4-demo
docker push myname/study-backend:week4-demo
```

첫 줄은 폴더 이동입니다. `build`는 이미지 생성, `tag`는 Docker Hub에 올릴 이름 추가, `push`는 업로드입니다. `--platform linux/amd64`는 Apple Silicon Mac에서도 이번 수업의 x86_64 EC2에서 실행할 이미지를 만들기 위해 사용합니다.

### 3.2 프론트엔드

위 명령을 실행한 backend 폴더에서 이어서 실행합니다.

```bash
cd ../frontend
docker build --platform linux/amd64 -t study-frontend .
docker tag study-frontend myname/study-frontend:week4-demo
docker push myname/study-frontend:week4-demo
cd ..
```

Docker Hub에서 두 저장소의 **Tags**에 `week4-demo`가 생겼는지 확인합니다. 마지막 `cd ..`는 저장소 루트로 돌아오는 명령입니다.

## 4. 배포용 Compose 준비

3주차의 Compose 설정을 이어 사용합니다. 내 컴퓨터에서 `deploy` 폴더를 만들고 기존 `compose.yaml`을 참고해 `deploy/compose.yaml`을 작성합니다. **이미지 준비 방법을 `build:`에서 `image:`로 바꾸며, 포트·환경 변수·볼륨·healthcheck·시작 순서는 유지합니다.**

다음은 제공 예제의 전체 배포용 Compose입니다.

```yaml
name: study-app

services:
  backend:
    image: ${DOCKERHUB_USERNAME}/study-backend:${IMAGE_TAG}
    restart: unless-stopped
    environment:
      APP_ENV: production
      APP_DATABASE_PATH: /data/tasks.db
    expose:
      - "8000"
    volumes:
      - task-data:/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://127.0.0.1:8000/api/health"]
      interval: 5s
      timeout: 3s
      retries: 5
      start_period: 5s

  frontend:
    image: ${DOCKERHUB_USERNAME}/study-frontend:${IMAGE_TAG}
    restart: unless-stopped
    ports:
      - "8080:80"
    depends_on:
      backend:
        condition: service_healthy

volumes:
  task-data:
```

| 설정 | 배포할 때의 역할 |
| --- | --- |
| `name: study-app` | 수동·자동 배포에서 같은 Compose 프로젝트와 볼륨 이름을 사용합니다. |
| `image` | Docker Hub에서 받을 이미지와 버전을 지정합니다. |
| `restart: unless-stopped` | 중지하지 않은 서비스가 종료되면 다시 실행하도록 설정합니다. |
| 백엔드 `environment` | 앱에 production 설정과 DB 파일 경로를 전달합니다. |
| 백엔드 `expose` | 백엔드가 사용하는 컨테이너 포트를 표시합니다. EC2 외부에 포트를 공개하지는 않습니다. |
| 백엔드 `volumes` | `task-data`를 `/data`에 연결해 DB 파일을 보관합니다. |
| 백엔드 `healthcheck` | 실제 API 응답을 확인해 준비 상태를 판단합니다. |
| 프론트 `ports` | EC2의 8080을 Nginx의 80에 연결합니다. |
| 프론트 `depends_on` | 백엔드가 healthy 상태가 된 뒤 프론트를 시작합니다. |
| 최상위 `volumes` | `task-data`라는 named volume을 선언합니다. |

`APP_DATABASE_PATH`, `/api/health`, 이미지 이름은 예제 앱의 값입니다. 자기 앱의 환경 변수·데이터 경로·API 주소로 바꿉니다. 프론트의 `nginx.conf`도 자기 API 전달 경로와 맞춥니다.

`deploy/.env.example`은 다음과 같이 준비합니다.

```dotenv
DOCKERHUB_USERNAME=myname
IMAGE_TAG=week4-demo
```

`${...}`에는 같은 폴더의 `.env` 값이 들어갑니다. `.env`는 Compose가 이미지 이름을 구성할 때 읽는 파일이며, 앱으로 전달할 환경 변수는 `environment:`에 적습니다. 실제 `.env`, PAT, 개인키를 Git에 넣지 않습니다.

내 컴퓨터의 저장소 루트에서 변경 파일을 확인하고 배포 설정을 올립니다.

```bash
git status
git add deploy
git commit -m "build: add deployment"
git push
```

[Compose 환경 변수](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/) · [Compose services](https://docs.docker.com/reference/compose-file/services/)

## 5. 키를 준비한 뒤 EC2 만들기

### 5.1 접속용 키 먼저 만들기

AWS 콘솔에서 EC2를 열고 사용할 리전을 정합니다. 이 예제는 서울 리전을 사용합니다.

1. 왼쪽 메뉴의 **Network & Security → Key pairs**를 엽니다.
2. **Create key pair**를 누릅니다.
3. 이름은 `study-key`, 유형은 **RSA**, 개인키 파일 형식은 **.pem**으로 선택합니다.
4. **Create key pair**를 누르면 `study-key.pem`이 내 컴퓨터에 다운로드됩니다.

이 파일을 SSH 접속에 사용합니다. 개인키는 다시 다운로드할 수 없으므로 보관하고 Git에 올리지 않습니다. 다음 단계에서 **방금 만든 키를 인스턴스에 선택한 뒤** 인스턴스를 시작합니다.

### 5.2 프리 티어 표시를 확인하고 인스턴스 설정

**Instances → Launch instances**를 엽니다.

| 설정 | 예제에서 선택할 값 |
| --- | --- |
| 이름 | `study-app` |
| AMI | Ubuntu Server 24.04 LTS, 64-bit x86 |
| Instance type | **프리 티어 사용 가능(Free tier eligible)** 표시가 있는 x86_64 유형 |
| Key pair | 먼저 만들어 둔 **`study-key` 선택** |
| Public IP | 자동 할당 활성화 |
| Storage | 프리 티어 적용 조건과 용량을 확인한 gp3 볼륨 |

예를 들어 `t3.micro`에 프리 티어 표시가 있다면 선택합니다. 계정마다 적용 기간과 크레딧 조건이 다르므로 **콘솔 표시와 잔여 혜택을 확인합니다.** 이번 자료의 이미지는 `linux/amd64`로 만들었으므로 x86_64 유형을 사용합니다.

**Network settings → Edit**에서 보안 그룹 규칙을 추가합니다.

| 유형·포트 | Source | 용도 |
| --- | --- | --- |
| SSH · TCP 22 | My IP | 내 컴퓨터의 SSH 접속 |
| Custom TCP · 8080 | Anywhere-IPv4 (`0.0.0.0/0`) | 브라우저의 웹 앱 접속 |

**키 페어 `study-key`, 인스턴스 유형, 네트워크 설정을 확인한 뒤 Launch instance를 누릅니다.** 생성 후 인스턴스를 선택해 Public IPv4 address를 복사합니다.

자동 배포 시연 때는 22번 Source도 잠시 **Anywhere-IPv4**로 바꿉니다. GitHub runner의 IP가 내 컴퓨터와 다르기 때문입니다. 시연 뒤에는 **My IP로 복구**합니다. 복구 후에는 hosted runner의 SSH 배포가 차단됩니다. 백엔드 8000번은 컨테이너 사이에서 쓰므로 추가하지 않습니다.

[키 페어 생성](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html) · [인스턴스 시작과 프리 티어 조건](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-launch-instance-wizard.html)

### 5.3 다운로드한 키로 SSH 접속

내 컴퓨터에서 키를 저장한 폴더로 이동합니다. 아래 `203.0.113.10`은 실제 EC2의 공인 IP로 바꿉니다.

```bash
cd ~/Downloads
chmod 400 study-key.pem
ssh -i study-key.pem ubuntu@203.0.113.10
```

- `chmod 400`: macOS·Linux에서 내 계정만 키 파일을 읽게 합니다.
- `-i study-key.pem`: 사용할 개인키 파일을 고릅니다.
- `ubuntu@...`: EC2의 `ubuntu` 사용자로 접속합니다.

첫 접속의 서버 지문은 EC2의 **Actions → Monitor and troubleshoot → Get system log**에 있는 ED25519 SHA256 지문과 확인하고 `yes`를 입력합니다. 접속 후의 명령은 EC2에서 실행됩니다. `exit`를 입력하면 내 컴퓨터로 돌아옵니다.

### 5.4 Docker와 Git 설치

새 Ubuntu 24.04 EC2 안에서 실행합니다. 이 예제는 Ubuntu 패키지를 사용합니다.

```bash
sudo apt update
sudo apt install docker.io
sudo apt install docker-compose-v2 git curl
sudo usermod -aG docker ubuntu
exit
```

설치 확인 질문에는 `Y`를 입력합니다. `usermod`는 `ubuntu`가 Docker를 사용할 수 있게 그룹에 추가하는 명령입니다. 그룹 변경을 적용하기 위해 로그아웃했습니다.

내 컴퓨터에서 다시 접속합니다.

```bash
ssh -i study-key.pem ubuntu@203.0.113.10
```

EC2에서 설치 결과를 확인합니다.

```bash
docker version
docker compose version
```

[Ubuntu Docker 패키지](https://packages.ubuntu.com/noble/docker.io) · [Compose v2 패키지](https://packages.ubuntu.com/noble/docker-compose-v2)

## 6. EC2에서 처음 배포하기

### 6.1 자기 GitHub 저장소 clone

내 컴퓨터에서 준비한 `deploy/`를 자기 공개 GitHub 저장소에 커밋·push해 둡니다. GitHub의 **Code → Local → HTTPS**에서 주소를 복사합니다.

접속해 둔 EC2 터미널로 돌아와 실행합니다. URL은 자기 저장소 주소로 바꿉니다.

```bash
cd ~
git clone https://github.com/myname/my-project.git study-app
cd study-app/deploy
cp .env.example .env
nano .env
```

`study-app`은 EC2에 만들 폴더 이름입니다. 이후 배포 명령은 `~/study-app/deploy`에서 실행합니다. GitHub에서는 설정과 배포 스크립트를 받고, 실행할 이미지는 Docker Hub에서 받습니다.

### 6.2 이미지 계정과 태그 설정

`.env`의 계정명을 자기 값으로 바꿉니다.

```dotenv
DOCKERHUB_USERNAME=myname
IMAGE_TAG=week4-demo
```

nano에서 **Ctrl+O → Enter**로 저장하고 **Ctrl+X**로 닫습니다. 여기에 Docker Hub 비밀번호나 PAT를 적지 않습니다.

### 6.3 컨테이너 실행과 확인

EC2의 `~/study-app/deploy`에서 한 줄씩 실행합니다.

```bash
docker compose pull
docker compose down
docker compose up -d --wait
docker compose ps
curl -f http://localhost:8080/api/health
```

| 명령 | 하는 일 |
| --- | --- |
| `pull` | Docker Hub에서 두 이미지를 받습니다. |
| `down` | 기존 컨테이너와 기본 네트워크를 정리합니다. 최초 배포에는 기존 컨테이너가 없을 수 있습니다. |
| `up -d --wait` | 백그라운드로 실행하고 백엔드 healthy와 프론트 실행 상태를 기다립니다. |
| `ps` | 컨테이너 상태를 봅니다. |
| `curl -f ...` | Nginx를 거친 API 응답을 확인합니다. HTTP 오류이면 실패합니다. |

예제의 정상 응답은 `{"status":"ok"}`입니다. 자기 앱의 상태 API로 바꿉니다. 내 컴퓨터의 브라우저에서 `http://공인IP:8080`에 접속하고 기능이 동작하는지 확인합니다.

위 명령을 모아 둔 파일이 `deploy.sh`입니다. 같은 폴더에서 `bash deploy.sh`로 실행할 수 있습니다. `set -e`는 앞선 명령이 실패하면 진행을 멈추게 합니다.

이 예제는 기존 컨테이너를 내리고 다시 올리므로 **배포 중 잠깐 접속이 끊깁니다.** `down`에 `-v`가 없으므로 DB를 담은 `study-app_task-data` 볼륨은 유지됩니다. 볼륨은 이 EC2의 디스크에 있습니다.

[Compose 실행](https://docs.docker.com/reference/cli/docker/compose/up/) · [Compose 종료](https://docs.docker.com/reference/cli/docker/compose/down/)

## 7. GitHub Actions로 검사하기

Workflow 위치는 [`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml)입니다. `main`에 push하면 실행되며 **Actions → Test and deploy → Run workflow**로 직접 실행할 수도 있습니다. 직접 실행할 때도 `main`을 선택합니다.

`test` job은 코드를 가져오고 uv·Python·Node를 설치한 뒤 기존 검사 명령을 실행합니다. **아래는 이 예제 프로젝트의 설정입니다.** 다른 프로젝트는 폴더와 검사 명령을 맞추면 됩니다.

| 작업 | working-directory | 명령 |
| --- | --- | --- |
| 백엔드 의존성 설치 | `backend` | `uv sync --locked` |
| 프론트 의존성 설치 | `frontend` | `npm ci` |
| 공통·백엔드·프론트 검사 | `backend` | `uv run pre-commit run --all-files` |
| 프론트 빌드 | `frontend` | `npm run build` |

`working-directory`는 명령을 실행할 폴더입니다. `uv sync --locked`는 lockfile과 프로젝트 설정의 일치를 확인해 설치합니다. `npm ci`도 lockfile에 기록된 버전으로 설치합니다. pre-commit은 저장소 루트의 설정을 사용해 pytest·ESLint·TypeScript·Vitest를 실행합니다.

강의의 **4.4는 실패 로그를 읽는 설명용 예시**입니다. 정상 코드를 일부러 망가뜨리거나 로컬 검사를 건너뛸 필요가 없습니다. 실패했다면 **Actions → 실행 항목 → test → Run checks**에서 오류 위치와 이유를 확인한 뒤 수정 커밋을 push합니다.

[Workflow 문법](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax) · [pre-commit 실행](https://pre-commit.com/#pre-commit-run)

## 8. 자동 배포 연결하기

### 8.1 GitHub Secrets 등록

저장소의 **Settings → Secrets and variables → Actions → New repository secret**에서 Name과 Secret을 입력하고 Add secret을 누릅니다.

| Name | Secret에 넣을 값 |
| --- | --- |
| `DOCKERHUB_USERNAME` | 자기 Docker Hub 계정명 |
| `DOCKERHUB_TOKEN` | 앞서 만든 Repo Read & Write PAT |
| `EC2_HOST` | EC2의 현재 공인 IPv4 |
| `EC2_SSH_KEY` | 다운로드한 `study-key.pem`의 전체 내용 |
| `EC2_FINGERPRINT` | 서버 지문 중 `SHA256:...` 값 |

`EC2_SSH_KEY`는 내 컴퓨터의 키 파일을 편집기로 열어 BEGIN과 END 줄까지 전부 복사합니다. 새 키를 만들거나 서버의 `authorized_keys`를 따로 편집하지 않습니다.

`EC2_FINGERPRINT`는 이미 접속한 EC2에서 확인합니다.

```bash
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

출력 중 `SHA256:`로 시작하는 값만 복사합니다. 개인키와 서버 지문은 서로 다른 값입니다. 서버 사용자는 workflow의 `username: ubuntu`에 적으므로 별도의 Secret을 만들지 않습니다.

### 8.2 검사한 커밋을 이미지 태그로 사용

`publish`는 `test`가 성공한 뒤 실행합니다. `IMAGE_TAG`에 `${{ github.sha }}`를 넣어 검사한 커밋의 전체 ID를 사용합니다. 두 이미지는 같은 태그로 Docker Hub에 올라갑니다.

```yaml
env:
  DOCKERHUB_USERNAME: ${{ secrets.DOCKERHUB_USERNAME }}
  IMAGE_TAG: ${{ github.sha }}
```

`deploy`에도 같은 두 `env` 값을 선언합니다. Job 사이에서 환경 변수가 자동 공유되는 것은 아닙니다. SSH Action의 `envs`는 이 값을 EC2 셸에 전달합니다.

### 8.3 EC2에서 같은 커밋의 파일 사용

SSH Action의 `script`는 EC2에서 실행합니다.

```yaml
script: |
  set -e
  cd ~/study-app
  git fetch origin main
  git checkout ${{ github.sha }}
  cd deploy
  bash deploy.sh
```

`fetch`로 새 커밋을 받고, 검사한 커밋의 파일로 전환합니다. `${{ github.sha }}`는 workflow에서 치환하는 표현이므로 터미널에 그대로 입력하지 않습니다. 서버의 저장소 파일을 직접 수정하는 대신 내 컴퓨터에서 수정하고 커밋합니다.

전달한 환경 변수는 EC2의 `.env` 값보다 우선합니다. 자동 배포는 `.env`의 내용을 바꾸지 않습니다. 이후 수동 배포를 한다면 `.env`의 `IMAGE_TAG`를 배포하려는 태그로 맞춥니다.

### 8.4 코드 변경 후 확인

검사와 배포 설정을 처음 추가했다면 내 컴퓨터에서 커밋하고 push합니다.

```bash
git add .github
git commit -m "ci: add deployment"
git push
```

자기 앱의 화면에서 확인하기 쉬운 문구를 하나 바꾸고 커밋·push합니다. Actions의 `test`, `publish`, `deploy`가 모두 성공한 뒤 EC2 웹 화면에 변경이 반영됐는지 확인합니다. 예제의 4.4 실패 코드를 일부러 만들 필요는 없습니다.

[GitHub Secrets](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets) · [SSH Action](https://github.com/appleboy/ssh-action)

## 9. 문제가 생겼을 때

| 실패한 곳 | 먼저 확인할 내용 |
| --- | --- |
| `test` | 실패한 검사 명령과 오류 메시지 |
| `publish` | Docker Hub 계정명, PAT 권한, 이미지 이름 |
| SSH 연결 | EC2 주소, 개인키, 서버 지문, 현재 인바운드 규칙 |
| 웹 접속 | 8080 포트와 컨테이너 실행 상태 |

EC2의 `~/study-app/deploy`에서 상태와 로그를 확인합니다.

```bash
docker compose ps
docker compose logs
```

이 예제에는 자동 롤백이 없습니다. 서버 교체 도중 실패했다면 앱이 멈춰 있을 수 있으므로 로그에서 원인을 고친 뒤 다시 배포합니다.

## 10. 실습 후 AWS 리소스 정리

먼저 변경된 화면과 성공한 Actions 실행을 README에 남깁니다. 출석 증빙을 위해 EC2를 계속 켜둘 필요는 없습니다.

### 10.1 어떤 항목에서 비용이 생기는가

| 항목 | 과금 기준 |
| --- | --- |
| EC2 | 서버가 실행 중인 시간 |
| EBS 디스크 | 할당한 용량과 보관 기간 |
| 스냅샷 | 별도로 만든 백업 데이터 보관 |
| 공인 IPv4 | AWS 공인 IP를 사용하거나 보유한 시간 |
| 데이터 전송 | 전송량과 전송 경로 |

프리 티어 적용 여부와 잔여 크레딧은 자기 계정에서 확인합니다. T 계열의 Unlimited 모드를 사용하면 CPU 사용량에 따라 초과 크레딧 요금이 생길 수 있습니다. `docker compose down`은 컨테이너를 내릴 뿐 EC2를 종료하지 않습니다.

### 10.2 EC2 인스턴스 종료

1. 필요한 화면과 데이터를 저장합니다.
2. EC2 콘솔에서 실습한 리전을 고르고 **Instances**에서 `study-app`을 선택합니다.
3. **Storage**에서 Volume ID와 **Delete on termination**을 확인합니다. Yes이면 종료 시 함께 삭제하고, No이면 볼륨이 남습니다.
4. **Instance state → Terminate (delete) instance**를 선택하고 확인 창에서 종료합니다.
5. 상태가 **terminated**인지 확인합니다. 종료된 항목이 잠시 목록에 남을 수 있습니다.

**Stop**은 다시 켤 수 있는 중지이며 EBS 등의 비용은 남습니다. **Terminate**는 인스턴스 삭제입니다. 함께 삭제된 디스크의 DB와 파일도 사라집니다.

### 10.3 남은 디스크와 고정 IP 정리

같은 리전에서 **실습용으로 만든 리소스만** 확인합니다.

| 리소스 | 확인과 정리 순서 |
| --- | --- |
| EBS 볼륨 | **Volumes**에서 기록한 Volume ID 검색. 남은 볼륨이 Available이면 **Actions → Delete volume**, 확인 창에서 `delete` 입력 후 Delete. |
| 스냅샷 | 직접 만든 경우 **Snapshots**에서 실습 백업 선택. **Actions → Delete snapshot**, 확인 후 Delete. |
| Elastic IP | 별도 할당한 경우 **Elastic IPs**에서 선택. 연결 중이면 Disassociate로 해제한 뒤 **Actions → Release Elastic IP addresses → Release**. |

기본 자동 할당 공인 IPv4는 인스턴스 종료와 함께 반납됩니다. 별도로 할당한 Elastic IP는 연결만 해제해도 계정에 남으므로 반납까지 해야 합니다. 볼륨을 삭제해도 따로 만든 스냅샷은 남습니다.

### 10.4 청구 내역 확인

**Billing and Cost Management → Bills**에서 이번 달을 선택합니다. **Charges by service**에서 비용이 표시된 서비스와 실습 리전을 펼쳐 확인합니다.

리소스를 삭제해도 이미 사용한 요금은 남습니다. 청구 화면 반영에는 시간이 걸릴 수 있으므로 이후 갱신된 내역도 확인합니다. 서버를 계속 사용할 계획이면 남는 비용을 확인하고 임시로 넓힌 SSH 인바운드를 My IP로 복구합니다.

[EC2 종료](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/terminating-instances.html) · [EBS 삭제](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-deleting-volume.html) · [스냅샷 삭제](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-deleting-snapshot.html) · [Elastic IP 반납](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-instance-addressing-eips-releasing.html) · [요금 확인](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/getting-viewing-bill.html)

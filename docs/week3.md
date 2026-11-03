# 3주차: Docker와 Docker Compose

각자 만든 프로젝트를 Docker 이미지로 빌드하고 Compose로 함께 실행하는 실습입니다. 이 저장소의 앱과 내부 폴더 배치는 참고 예제입니다.

## 시작과 종료

[Docker 설치 안내](https://docs.docker.com/get-started/get-docker/)에 따라 Docker를 설치하고 실행합니다. 저장소 루트에서 버전과 엔진 연결을 확인합니다.

```bash
docker --version
docker compose version
docker info
```

앱을 빌드하고 백그라운드로 실행합니다.

```bash
docker compose up --build -d
docker compose ps
```

[http://localhost:8080](http://localhost:8080)에서 할 일을 추가하고 완료·삭제를 확인합니다. API 상태는 [http://localhost:8080/api/health](http://localhost:8080/api/health)에서 확인합니다.

```bash
docker compose logs -f
```

로그 화면의 `Ctrl+C`는 로그 보기를 끝냅니다. 백그라운드 앱을 종료하려면 다음 명령을 실행합니다.

```bash
docker compose down
```

## 실행 구조

| 위치 | 역할 |
| --- | --- |
| 브라우저의 `localhost:8080` | 내 컴퓨터에서 공개한 주소 |
| `frontend` 서비스의 80번 | Nginx가 정적 파일과 API 요청을 받음 |
| `backend` 서비스의 8000번 | FastAPI가 API 요청을 처리 |
| `task-data` 볼륨 | `/data/tasks.db`를 보관 |

Compose가 만드는 기본 네트워크에서 Nginx는 `backend:8000`으로 백엔드를 찾습니다. 브라우저는 `/api/tasks`로 요청합니다.

`8080:80`의 왼쪽은 내 컴퓨터 포트, 오른쪽은 컨테이너 포트입니다. 백엔드는 호스트 포트를 공개하지 않습니다. `expose`는 사용하는 내부 포트를 나타내며 방화벽 규칙을 만드는 설정은 아닙니다.

## 프론트 Dockerfile

[frontend/Dockerfile](../frontend/Dockerfile)은 두 스테이지로 구성합니다.

1. Node 이미지에서 빌드를 준비합니다.
2. `package.json`과 `package-lock.json`을 먼저 복사합니다.
3. `npm ci`로 빌드 도구를 포함한 의존성을 설치합니다.
4. 소스와 빌드 설정을 복사합니다.
5. `npm run build`로 `dist/`를 만듭니다.
6. Nginx 이미지에 `dist/`와 Nginx 설정을 복사합니다.

최종 프론트 이미지에는 Node와 `node_modules/`를 넣지 않습니다. Nginx가 정적 파일을 제공합니다.

## 백엔드 Dockerfile

[backend/Dockerfile](../backend/Dockerfile)도 두 스테이지입니다.

1. Python과 uv를 준비합니다.
2. `pyproject.toml`과 `uv.lock`을 복사합니다.
3. `uv sync --locked --no-dev --no-install-project`로 외부 의존성만 설치합니다.
4. `src/`와 `README.md`를 복사합니다.
5. `uv sync --locked --no-dev --no-editable`로 앱을 가상환경에 설치합니다.
6. 실행용 Python 이미지에 상태 검사에 사용할 curl을 설치합니다.
7. 빌드 단계와 같은 Python 기반 이미지에 설치된 `.venv/`를 복사합니다.
8. `backend --host 0.0.0.0 --port 8000`으로 실행합니다.

`--locked`는 lockfile 일치를 확인합니다. `--no-dev`는 테스트 도구 등 개발 의존성을 제외합니다. `--no-install-project`는 아직 소스가 없는 단계에서 자기 패키지 설치를 미룹니다.

두 번째 `uv sync`의 `--no-editable`은 앱 코드를 가상환경에 설치해 원본 `src/`를 참조하지 않게 합니다. 이때 `pyproject.toml`에 지정한 `uv_build` 빌드 백엔드를 사용합니다.

빌드와 실행 스테이지의 Python 버전과 OS 계열, `.venv` 경로를 맞춥니다. 설치된 앱을 복사하므로 런타임에 원래 `src/` 경로가 필요하지 않습니다.

`app` 사용자에게 데이터 디렉터리 쓰기 권한을 주고 이 사용자로 서버를 실행합니다. `0.0.0.0`은 컨테이너의 네트워크 인터페이스에서 요청을 받기 위한 주소입니다.

### 백엔드만 먼저 확인

```bash
docker build -t study-backend ./backend
docker run --rm --name study-api -p 8000:8000 study-backend
```

[http://localhost:8000/api/health](http://localhost:8000/api/health)를 확인한 뒤 `Ctrl+C`로 종료합니다. 프론트의 `backend` 이름은 Compose 네트워크에서 사용하므로 전체 연결은 Compose로 확인합니다.

## 캐시와 멀티 스테이지

의존성 파일과 lockfile을 먼저 복사하면 소스만 바뀐 경우 의존성 설치 단계의 캐시를 재사용할 수 있습니다. 기존 캐시가 있는 상태에서 소스 한 줄을 바꾸고 다음 빌드 로그를 비교합니다.

```bash
docker compose --progress plain build frontend
```

`COPY --from=build`는 빌드 스테이지에서 실행 스테이지로 결과물을 가져옵니다. 캐시는 재빌드할 범위를 줄이고, 멀티 스테이지는 최종 이미지에 담을 파일을 구분합니다.

`.dockerignore`는 각 빌드 컨텍스트에 있습니다. 로컬 `.venv/`, `node_modules/`, `.env`, DB, 기존 빌드 결과를 제외합니다.

## Nginx 설정

[frontend/nginx.conf](../frontend/nginx.conf)에서 핵심 부분은 다음과 같습니다.

- `listen 80`: 컨테이너의 80번 포트에서 요청을 받습니다.
- `root /usr/share/nginx/html`: 정적 파일의 기준 경로입니다.
- `location /`: 화면 파일을 제공합니다. 파일이 없으면 `index.html`로 SPA 화면을 제공합니다.
- `location /api/`: API 요청을 백엔드로 전달합니다.
- `proxy_pass http://backend:8000;`: `/api/tasks` 경로를 유지해 전달합니다.

이 설정에서 `proxy_pass` 뒤에 URI `/`를 추가하면 경로를 처리하는 방식이 달라집니다. 자신의 백엔드 API 경로와 맞춰야 합니다.

## Compose와 실행 설정

[compose.yaml](../compose.yaml)에 빌드 경로, 포트, 환경 변수, 시작 순서, 볼륨을 모았습니다.

`APP_ENV=production`과 `APP_DATABASE_PATH=/data/tasks.db`를 백엔드에 전달합니다. 예제에서는 프로덕션 모드의 FastAPI 문서를 비활성화하고 자동 reload를 사용하지 않습니다. 로컬 `backend/.env`를 이미지에 복사하지 않습니다.

백엔드 healthcheck는 같은 컨테이너 안에서 curl로 `/api/health`에 요청을 보냅니다.

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://127.0.0.1:8000/api/health"]
  interval: 5s
  timeout: 3s
  retries: 5
  start_period: 5s
```

`CMD`는 뒤의 명령을 직접 실행하는 형식입니다. `curl -f`는 HTTP 오류 응답을 실패로 처리합니다. 연결하지 못해도 검사에 실패하며, 정상 응답을 받으면 성공합니다. 앱이 준비되는 동안에는 검사에 실패할 수 있습니다. `start_period`는 초기 준비 시간의 실패를 집계하지 않게 합니다.

프론트의 `depends_on: condition: service_healthy`는 백엔드가 준비된 뒤 Nginx를 시작하도록 합니다. 서비스가 시작됐다는 것과 요청을 받을 준비가 됐다는 것을 구분합니다.

자주 쓰는 명령:

```bash
docker compose up --build -d
docker compose ps
docker compose logs -f backend
docker compose logs -f frontend
docker compose down
```

## 데이터 유지 확인

1. 앱에서 할 일을 추가합니다.
2. `docker compose down`으로 컨테이너를 정리합니다.
3. `docker compose up -d`로 다시 실행합니다.
4. 같은 할 일이 남아 있는지 확인합니다.

`task-data:/data`가 컨테이너의 `/data`를 named volume에 연결합니다. 같은 Compose 프로젝트에서 `down`과 `up`을 반복해도 named volume은 남습니다.

**데이터를 초기화할 때만** 다음 명령을 사용합니다. `-v`는 이 Compose 프로젝트의 볼륨도 삭제합니다.

```bash
docker compose down -v
```

## 자기 프로젝트에 맞추기

| 항목 | 확인할 부분 |
| --- | --- |
| 빌드 컨텍스트 | Compose의 `build`와 Dockerfile의 `COPY` 기준 경로 |
| 백엔드 실행 | 패키지 이름, CLI 또는 Uvicorn 모듈 경로 |
| 서버 주소·포트 | 컨테이너의 리슨 주소와 포트, Nginx 전달 대상 |
| 프론트 빌드 | `package.json`의 build 명령과 결과 디렉터리 |
| API 경로 | 프론트 요청 경로와 Nginx location, 백엔드 경로 |
| 데이터 저장 | 실제 DB·파일 경로와 volume 연결 위치 |

### main.py로 실행하는 프로젝트

이 예제는 `uv sync --no-editable`로 `src/` 패키지를 설치하고 CLI로 실행합니다. 자기 프로젝트가 `main.py`에 `app = FastAPI()`를 두는 형태라면 다음처럼 실행 명령을 맞출 수 있습니다.

```dockerfile
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

자기 프로젝트를 패키지로 설치하지 않는 경우에는 runtime 스테이지에도 `main.py`와 사용하는 모듈을 복사해야 합니다. 외부 의존성을 설치한 `.venv`와 실제 소스를 실행 이미지에 함께 넣고, 실행에 사용하는 Uvicorn도 의존성에 포함합니다.

내부 폴더 구조나 Typer CLI까지 이 예제와 같게 바꿀 필요는 없습니다.

## 문제 확인

| 증상 | 먼저 확인할 내용 |
| --- | --- |
| Docker 엔진 연결 오류 | Docker Desktop 또는 Docker daemon이 실행 중인지 |
| 파일 COPY 실패 | 빌드 컨텍스트와 원본 파일 경로 |
| npm ci 실패 | package.json과 package-lock.json 일치 여부 |
| backend 명령을 못 찾음 | 패키지 설치, project.scripts, PATH |
| Nginx에서 502 | backend 로그, 리슨 주소, 포트, 서비스 이름 |
| API에서 404 | /api 경로가 유지되는지, 자신의 라우터 경로 |
| 브라우저에서 backend 주소를 못 찾음 | 브라우저는 /api로 요청하고 Nginx가 서비스 이름 사용 |
| 포트가 이미 사용 중 | ports의 왼쪽 호스트 포트 변경 |
| 재실행 후 데이터가 사라짐 | 실제 저장 경로와 volume 경로가 같은지 |

## 과제

자기 프로젝트에 다음을 적용하고 GitHub에 커밋을 올립니다.

- 백엔드와 프론트엔드 Dockerfile.
- 의존성 파일을 먼저 복사하는 빌드 순서와 멀티 스테이지.
- 프론트 정적 파일 제공과 API 전달 설정.
- `docker compose up --build`로 전체 앱 실행.
- 자기 앱의 데이터 저장 방식을 고려한 볼륨 설정과 재실행 확인.

실습 중 커밋은 한 목적씩 나누고 `build: add backend image`처럼 짧은 Conventional Commit 메시지를 사용합니다.

## 공식 문서

- [Docker 설치](https://docs.docker.com/get-started/get-docker/)
- [Dockerfile](https://docs.docker.com/reference/dockerfile/)
- [빌드 캐시](https://docs.docker.com/build/cache/optimize/)
- [멀티 스테이지](https://docs.docker.com/build/building/multi-stage/)
- [uv와 Docker](https://docs.astral.sh/uv/guides/integration/docker/)
- [curl 명령과 옵션](https://curl.se/docs/manpage.html)
- [Nginx 입문](https://nginx.org/en/docs/beginners_guide.html)
- [Compose 네트워크](https://docs.docker.com/compose/how-tos/networking/)
- [Compose 시작 순서](https://docs.docker.com/compose/how-tos/startup-order/)
- [볼륨](https://docs.docker.com/engine/storage/volumes/)

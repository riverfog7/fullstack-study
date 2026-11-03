# 개발 스터디 예제

FastAPI와 React로 만든 작은 할 일 앱입니다. 할 일을 추가하고, 완료 상태를 바꾸고, 삭제할 수 있습니다. 데이터는 SQLite 파일에 저장합니다.

강사가 프로젝트를 정리하는 한 가지 예시입니다. 스터디 참가자는 각자 만든 프로젝트를 계속 사용하고, 필요한 구조와 설정을 참고하면 됩니다.

## 버전

- `week2`: 로컬에서 프론트와 백엔드를 실행하는 과제 예제.
- `week3`: Dockerfile, Nginx, Compose, 볼륨을 적용한 완성 예제.
- Docker 실습을 시작할 때는 `week2` 태그에서 새 브랜치를 만듭니다.

압축 파일에는 `.git/`도 포함되어 있습니다. 압축을 푼 뒤 이 디렉터리에서 Git 명령을 실행합니다.

```bash
git log --oneline --decorate
git tag
git switch -c my-week3 week2
```

변경한 파일이 있으면 먼저 커밋한 뒤 전환합니다. 원래 브랜치로 돌아갈 때는 `git switch main`을 사용합니다. 태그는 해당 시점의 코드 위치이며, 실제 작업은 새 브랜치에서 진행하면 됩니다.

3주차에서 추가한 파일은 다음 명령으로 확인합니다.

```bash
git diff --stat week2..week3
```

## Docker로 실행

Docker가 실행 중인 상태에서 저장소 루트에서 실행합니다.

```bash
docker compose up --build -d
```

[http://localhost:8080](http://localhost:8080)에서 사용합니다. 종료는 `docker compose down`입니다. 설정별 설명, 데이터 유지 확인, 자기 프로젝트에 맞추는 방법은 [3주차 실습 안내](docs/week3.md)에 있습니다.

백엔드 이미지에서는 `uv sync --locked --no-dev --no-editable`로 앱을 설치합니다. 원본 `src/`를 참조하지 않는 설치이므로, 실행 이미지에는 설치된 `.venv/`를 복사합니다. `pyproject.toml`의 빌드 백엔드는 `uv_build`입니다.

## 준비

- Python 3.12 이상과 [uv](https://docs.astral.sh/uv/getting-started/installation/)
- Node.js 24 LTS와 npm
- Git

이 예제의 Python 기준 버전은 `backend/.python-version`에 있습니다. 의존성 버전은 `uv.lock`과 `package-lock.json`으로 고정합니다.

## 로컬 실행

저장소 루트에서 터미널 두 개를 열어 각각 실행합니다.

### 터미널 1: 백엔드

```bash
cd backend
uv sync
cp .env.example .env
uv run backend --reload
```

기본 설정으로 실행하려면 `.env` 복사는 생략해도 됩니다. 이미 만든 `.env`가 있다면 필요한 값만 수정합니다.

- API 상태: [http://localhost:8000/api/health](http://localhost:8000/api/health)
- 개발용 API 문서: [http://localhost:8000/docs](http://localhost:8000/docs)

### 터미널 2: 프론트엔드

```bash
cd frontend
npm ci
npm run dev
```

[http://localhost:5173](http://localhost:5173)에서 사용합니다. 5173번 포트를 이미 사용 중이면 기존 프로그램을 종료하거나 Vite 설정을 변경합니다.

브라우저는 같은 주소의 `/api/tasks`로 요청합니다. Vite가 `/api` 요청을 `http://127.0.0.1:8000`으로 전달합니다. 백엔드와 프론트가 모두 실행되어야 합니다.

종료는 각각의 터미널에서 `Ctrl+C`를 누릅니다.

## 코드 구성

### 백엔드: backend/src/backend/

| 경로 | 역할 |
| --- | --- |
| `core/database.py` | SQLite 연결, 테이블 초기화 |
| `models/task.py` | API 입력·출력 Pydantic 모델 |
| `repositories/tasks.py` | SQL을 이용한 데이터 조회와 변경 |
| `routers/tasks.py` | HTTP 경로와 응답 |
| `settings.py` | 환경 변수와 .env 설정 |
| `app.py` | FastAPI 생성과 라우터 등록 |
| `cli.py` | Typer 실행 명령과 Uvicorn 구동 |
| `backend/tests/` | 임시 DB를 사용하는 pytest 테스트 |

요청이 끝나기 전에 DB 변경을 확정하고 연결을 닫습니다. 앱을 import하기만 해서는 DB 파일을 생성하지 않습니다.

### 프론트엔드: frontend/src/

| 경로 | 역할 |
| --- | --- |
| `api/tasks.ts` | HTTP 요청과 응답 오류 처리 |
| `types/task.ts` | 데이터 타입 |
| `hooks/useTasks.ts` | 목록, 로딩, 오류, 저장 후 갱신 |
| `components/` | 입력 폼, 목록, 할 일 한 개 |
| `pages/TasksPage.tsx` | 화면과 상태 처리 연결 |
| `App.tsx`, `main.tsx` | 앱 구성과 시작 |
| `frontend/tests/` | 가짜 API 응답으로 확인하는 화면 테스트 |

추가·완료 변경·삭제가 성공하면 서버에서 목록을 다시 받습니다. 저장에는 성공했지만 재조회가 실패한 경우에는 별도 메시지를 표시합니다.

## API

기본 주소는 `http://localhost:8000`입니다.

| 메서드 | 경로 | 입력 | 결과 |
| --- | --- | --- | --- |
| GET | `/api/health` | 없음 | 200, 상태 확인 |
| GET | `/api/tasks` | 없음 | 200, id 순서의 목록 |
| POST | `/api/tasks` | `{"title": "Docker 실습"}` | 201, 새 할 일 |
| PATCH | `/api/tasks/{id}` | `{"completed": true}` | 200, 변경한 할 일 |
| DELETE | `/api/tasks/{id}` | 없음 | 204, 본문 없음 |

할 일의 데이터 형태는 `id`, `title`, `completed`입니다. 제목 양끝 공백을 제거하고 1~100자로 제한합니다. 입력이 잘못되면 422, 없는 할 일을 수정·삭제하면 404를 반환합니다.

## 설정과 CLI

`backend/`에서 실행할 때 같은 폴더의 `.env`를 읽습니다.

| 환경 변수 | 기본값 | 용도 |
| --- | --- | --- |
| `APP_ENV` | `development` | development 또는 production |
| `APP_DATABASE_PATH` | `data/tasks.db` | SQLite 파일 위치 |
| `APP_HOST` | `127.0.0.1` | 서버 주소 |
| `APP_PORT` | `8000` | 서버 포트 |

환경 변수가 `.env`보다 우선합니다. CLI의 `--host`, `--port`를 지정하면 해당 설정값보다 우선합니다.

```bash
uv run backend --help
uv run backend --host 127.0.0.1 --port 8000
```

`APP_ENV=production`에서는 Swagger UI, ReDoc, OpenAPI JSON을 비활성화하고 `--reload` 사용을 거부합니다. 문서 공개 여부와 API 인증은 서로 다른 설정입니다.

`pyproject.toml`의 실행 명령 등록은 다음과 같습니다.

```toml
[project.scripts]
backend = "backend.cli:main"
```

`uv sync`로 패키지를 설치하면 `backend` 명령이 생깁니다. CLI가 Uvicorn을 실행하고 `backend.app:create_app`에서 FastAPI 앱을 만듭니다.

## 테스트와 빌드

백엔드 디렉터리에서:

```bash
uv run pytest
uv build
```

프론트엔드 디렉터리에서:

```bash
npm run lint
npm run typecheck
npm test
npm run build
```

백엔드 테스트는 임시 SQLite 파일을 사용합니다. 프론트 테스트는 API 응답을 준비해서 화면의 사용자 동작을 확인합니다. 두 테스트 모두 별도로 서버를 실행할 필요가 없습니다.

`uv build`는 `backend/dist/`에 wheel과 sdist를 만듭니다. `npm run build`는 `frontend/dist/`에 브라우저용 정적 파일을 만듭니다.

## pre-commit

위의 `uv sync`, `npm ci`를 먼저 실행합니다. 저장소 루트에서 다음 명령으로 Git hook을 설치합니다.

```bash
uv run --project backend pre-commit install
uv run --project backend pre-commit run --all-files
```

`--project backend`는 backend의 Python 환경에 설치한 pre-commit을 사용한다는 뜻입니다.

- 공통: 줄 끝 공백, 파일 끝 개행, YAML 문법.
- 백엔드 파일 변경: pytest.
- 프론트 파일 변경: ESLint, TypeScript, Vitest.
- pre-commit 설정 변경: 양쪽 검사.

자동 수정으로 커밋이 멈추면 수정 결과를 확인하고 다시 `git add`한 뒤 커밋합니다. 이 예제의 커밋은 Conventional Commits 형식을 사용합니다.

## 새 프론트를 만들 때

원래 스터디의 선택값은 다음과 같습니다.

```bash
npm create vite@latest
```

- Project name: `frontend`
- Framework: `React`
- Variant: `TypeScript`
- Linter: `ESLint`
- Install with npm and start now: `Yes`

제공된 예제는 해당 선택으로 생성한 뒤 TypeScript와 ESLint의 호환 버전을 맞췄습니다. 예제를 실행할 때는 새로 생성하지 않고 `npm ci`로 lockfile의 버전을 설치합니다.

## 공식 자료

- [uv 프로젝트 관리](https://docs.astral.sh/uv/guides/projects/)
- [uv 빌드 백엔드](https://docs.astral.sh/uv/concepts/build-backend/)
- [FastAPI 여러 파일로 구성하기](https://fastapi.tiangolo.com/tutorial/bigger-applications/)
- [Pydantic Settings](https://docs.pydantic.dev/latest/concepts/pydantic_settings/)
- [Typer 패키징과 CLI 등록](https://typer.tiangolo.com/tutorial/package/)
- [Vite](https://vite.dev/guide/)
- [Vitest](https://vitest.dev/guide/)
- [pre-commit](https://pre-commit.com/)

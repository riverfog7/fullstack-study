# 백엔드

FastAPI와 SQLite로 만든 할 일 API입니다. 전체 실행 방법과 Git 태그 사용법은 저장소 루트의 README를 참고하세요.

## 실행

이 디렉터리에서 실행합니다.

```bash
uv sync
uv run backend --reload
```

개발 모드의 API 문서는 <http://localhost:8000/docs>에서 확인합니다.
설정 예시는 `.env.example`에 있습니다. 필요한 값을 `.env`에 작성하면 `settings.py`가 읽습니다.

## 검사와 패키징

```bash
uv run pytest
uv build
```

테스트는 임시 SQLite 파일을 사용합니다. `uv build` 결과는 `dist/`에 생성됩니다.

# 프론트엔드

React + TypeScript + Vite로 만든 할 일 목록입니다. ESLint로 코드를 검사하고 Vitest와 React Testing Library로 동작을 확인합니다.

## 실행

백엔드가 `127.0.0.1:8000`에서 실행 중이어야 합니다. `frontend/`에서 실행합니다.

```bash
npm ci
npm run dev
```

브라우저에서 <http://localhost:5173>을 엽니다. 프론트는 `/api/tasks`로 요청하며, 개발 서버의 프록시가 백엔드에 전달합니다.

## 검사와 빌드

```bash
npm run lint
npm run typecheck
npm test
npm run build
```

`npm test`는 한 번 실행한 뒤 종료합니다. 테스트를 계속 감시하려면 `npm run test:watch`를 실행합니다. 빌드 결과는 `dist/`에 생성됩니다.

## 코드 구조

| 경로 | 역할 |
| --- | --- |
| `src/api/` | HTTP 요청과 응답 처리 |
| `src/types/` | 할 일 데이터의 TypeScript 타입 |
| `src/hooks/` | 목록, 로딩, 오류 상태와 저장 후 갱신 |
| `src/components/` | 입력 폼과 목록의 화면 요소 |
| `src/pages/` | 컴포넌트를 연결한 화면 |
| `tests/` | API 응답을 준비해서 화면 동작을 확인하는 테스트 |

설치에는 Node.js 22.12 이상이 필요하며, 이 예제는 Node.js 24에서 확인합니다. TypeScript는 ESLint 도구의 지원 범위에 맞춘 6.0 버전을 사용합니다.

import sqlite3
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

from fastapi import Request


@contextmanager
def connect_database(path: Path) -> Iterator[sqlite3.Connection]:
    # FastAPI의 동기 함수는 서로 다른 작업 스레드에서 실행될 수 있습니다.
    connection = sqlite3.connect(path, check_same_thread=False)
    connection.row_factory = sqlite3.Row
    try:
        # 정상 종료하면 commit, 오류가 발생하면 rollback합니다.
        with connection:
            yield connection
    finally:
        connection.close()


def initialize_database(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with connect_database(path) as connection:
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS tasks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                completed INTEGER NOT NULL DEFAULT 0
                    CHECK (completed IN (0, 1))
            )
            """
        )


def get_connection(request: Request) -> Iterator[sqlite3.Connection]:
    """요청마다 연결을 만들고, 요청 처리가 끝나면 닫습니다."""
    with connect_database(request.app.state.settings.database_path) as connection:
        yield connection

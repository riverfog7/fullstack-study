import pytest
from fastapi.testclient import TestClient

from backend.app import create_app
from backend.settings import Settings


@pytest.fixture
def settings(tmp_path):
    return Settings(
        _env_file=None,
        env="development",
        database_path=tmp_path / "tasks.db",
    )


@pytest.fixture
def client(settings):
    with TestClient(create_app(settings)) as test_client:
        yield test_client

import pytest
from fastapi.testclient import TestClient

from backend.app import create_app
from backend.settings import Settings


@pytest.mark.parametrize("path", ["/docs", "/redoc", "/openapi.json"])
def test_development_docs(client, path):
    assert client.get(path).status_code == 200


def test_production_hides_docs(settings):
    production = settings.model_copy(update={"env": "production"})
    with TestClient(create_app(production)) as client:
        for path in ["/docs", "/redoc", "/openapi.json"]:
            assert client.get(path).status_code == 404
        assert client.get("/api/health").json() == {"status": "ok"}
        assert client.get("/api/tasks").status_code == 200


def test_data_survives_app_restart(settings):
    with TestClient(create_app(settings)) as client:
        task = client.post("/api/tasks", json={"title": "다음 시간에도 유지"}).json()

    with TestClient(create_app(settings)) as client:
        assert client.get("/api/tasks").json() == [task]


def test_database_is_created_on_startup(settings):
    app = create_app(settings)
    assert not settings.database_path.exists()
    with TestClient(app):
        assert settings.database_path.exists()


def test_environment_overrides_dotenv(tmp_path, monkeypatch):
    env_file = tmp_path / ".env"
    env_file.write_text("APP_PORT=8100\n", encoding="utf-8")
    monkeypatch.setenv("APP_PORT", "8200")
    assert Settings(_env_file=env_file).port == 8200

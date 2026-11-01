from typer.testing import CliRunner

from backend.cli import cli

runner = CliRunner()


def test_production_rejects_reload(monkeypatch):
    monkeypatch.setenv("APP_ENV", "production")
    result = runner.invoke(cli, ["--reload"])
    assert result.exit_code == 2
    assert "production" in result.output


def test_cli_options_override_settings(monkeypatch):
    monkeypatch.setenv("APP_ENV", "development")
    monkeypatch.setenv("APP_PORT", "8100")
    captured = {}

    def capture_run(app, **options):
        captured.update(app=app, **options)

    monkeypatch.setattr("backend.cli.uvicorn.run", capture_run)
    result = runner.invoke(cli, ["--host", "0.0.0.0", "--port", "8200"])
    assert result.exit_code == 0
    assert captured["app"] == "backend.app:create_app"
    assert captured["factory"] is True
    assert captured["host"] == "0.0.0.0"
    assert captured["port"] == 8200
    assert captured["reload"] is False

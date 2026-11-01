from typing import Annotated

import typer
import uvicorn

from backend.settings import Settings

cli = typer.Typer(add_completion=False)


@cli.command()
def serve(
    host: Annotated[str | None, typer.Option(help="요청을 받을 서버 주소")] = None,
    port: Annotated[
        int | None, typer.Option(min=1, max=65535, help="서버 포트")
    ] = None,
    reload: Annotated[
        bool, typer.Option("--reload", help="개발 중 코드가 바뀌면 서버를 다시 실행")
    ] = False,
) -> None:
    """FastAPI 서버를 실행합니다."""
    settings = Settings()
    if settings.env == "production" and reload:
        raise typer.BadParameter(
            "production 환경에서는 reload를 사용할 수 없습니다.",
            param_hint="--reload",
        )

    uvicorn.run(
        "backend.app:create_app",
        factory=True,
        host=host if host is not None else settings.host,
        port=port if port is not None else settings.port,
        reload=reload,
    )


def main() -> None:
    cli()


if __name__ == "__main__":
    main()

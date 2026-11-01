import sqlite3
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Response

from backend.core.database import get_connection
from backend.models.task import TaskCreate, TaskRead, TaskUpdate
from backend.repositories import tasks

router = APIRouter(prefix="/api/tasks", tags=["tasks"])
# 응답을 보내기 전에 DB 변경을 commit하고 연결을 닫습니다.
Database = Annotated[
    sqlite3.Connection, Depends(get_connection, scope="function")
]


@router.get("")
def list_tasks(connection: Database) -> list[TaskRead]:
    return tasks.list_tasks(connection)


@router.post("", status_code=201)
def create_task(body: TaskCreate, connection: Database) -> TaskRead:
    return tasks.create_task(connection, body.title)


@router.patch("/{task_id}")
def update_task(task_id: int, body: TaskUpdate, connection: Database) -> TaskRead:
    task = tasks.update_task(connection, task_id, body.completed)
    if task is None:
        raise HTTPException(status_code=404, detail="할 일을 찾을 수 없습니다.")
    return task


@router.delete("/{task_id}", status_code=204)
def delete_task(task_id: int, connection: Database) -> Response:
    if not tasks.delete_task(connection, task_id):
        raise HTTPException(status_code=404, detail="할 일을 찾을 수 없습니다.")
    return Response(status_code=204)

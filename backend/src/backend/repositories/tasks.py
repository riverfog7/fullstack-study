import sqlite3

from backend.models.task import TaskRead


def to_task(row: sqlite3.Row) -> TaskRead:
    return TaskRead(
        id=row["id"],
        title=row["title"],
        completed=bool(row["completed"]),
    )


def list_tasks(connection: sqlite3.Connection) -> list[TaskRead]:
    rows = connection.execute(
        "SELECT id, title, completed FROM tasks ORDER BY id"
    ).fetchall()
    return [to_task(row) for row in rows]


def get_task(connection: sqlite3.Connection, task_id: int) -> TaskRead | None:
    row = connection.execute(
        "SELECT id, title, completed FROM tasks WHERE id = ?", (task_id,)
    ).fetchone()
    return to_task(row) if row is not None else None


def create_task(connection: sqlite3.Connection, title: str) -> TaskRead:
    cursor = connection.execute("INSERT INTO tasks (title) VALUES (?)", (title,))
    return TaskRead(id=cursor.lastrowid, title=title, completed=False)


def update_task(
    connection: sqlite3.Connection, task_id: int, completed: bool
) -> TaskRead | None:
    cursor = connection.execute(
        "UPDATE tasks SET completed = ? WHERE id = ?", (completed, task_id)
    )
    if cursor.rowcount == 0:
        return None
    return get_task(connection, task_id)


def delete_task(connection: sqlite3.Connection, task_id: int) -> bool:
    cursor = connection.execute("DELETE FROM tasks WHERE id = ?", (task_id,))
    return cursor.rowcount > 0

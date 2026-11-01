import pytest


def test_task_lifecycle(client):
    assert client.get("/api/tasks").json() == []

    response = client.post("/api/tasks", json={"title": "  Docker 공부  "})
    assert response.status_code == 201
    task = response.json()
    assert task == {"id": task["id"], "title": "Docker 공부", "completed": False}
    assert client.get("/api/tasks").json() == [task]

    response = client.patch(
        f"/api/tasks/{task['id']}", json={"completed": True}
    )
    assert response.status_code == 200
    assert response.json()["completed"] is True
    assert client.get("/api/tasks").json()[0]["completed"] is True

    response = client.patch(
        f"/api/tasks/{task['id']}", json={"completed": False}
    )
    assert response.json()["completed"] is False

    response = client.delete(f"/api/tasks/{task['id']}")
    assert response.status_code == 204
    assert response.content == b""
    assert client.get("/api/tasks").json() == []


@pytest.mark.parametrize("title", ["", "   ", "가" * 101])
def test_invalid_title(client, title):
    response = client.post("/api/tasks", json={"title": title})
    assert response.status_code == 422
    assert client.get("/api/tasks").json() == []


def test_title_at_limit_and_sql_characters(client):
    title = "'" + "가" * 99
    response = client.post("/api/tasks", json={"title": title})
    assert response.status_code == 201
    assert client.get("/api/tasks").json()[0]["title"] == title


def test_missing_task(client):
    response = client.patch("/api/tasks/999", json={"completed": True})
    assert response.status_code == 404
    assert client.delete("/api/tasks/999").status_code == 404


@pytest.mark.parametrize("body", [{}, {"completed": "false"}])
def test_completed_must_be_boolean(client, body):
    task = client.post("/api/tasks", json={"title": "테스트"}).json()
    response = client.patch(f"/api/tasks/{task['id']}", json=body)
    assert response.status_code == 422
    assert client.get("/api/tasks").json()[0]["completed"] is False


def test_list_keeps_creation_order(client):
    client.post("/api/tasks", json={"title": "첫 번째"})
    client.post("/api/tasks", json={"title": "두 번째"})
    assert [task["title"] for task in client.get("/api/tasks").json()] == [
        "첫 번째",
        "두 번째",
    ]

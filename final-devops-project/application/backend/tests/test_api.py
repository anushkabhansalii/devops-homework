import os

os.environ["DATABASE_URL"] = "sqlite:///./test.db"

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.db import Base, engine  # noqa: E402
from app.main import app  # noqa: E402


@pytest.fixture(autouse=True)
def fresh_db():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c


def make(client, **kw):
    body = {"title": "Deploy application", "priority": "HIGH", "assignee": "Anushka"} | kw
    r = client.post("/api/tasks", json=body)
    assert r.status_code == 201
    return r.json()


def test_health(client):
    assert client.get("/health").json() == {"status": "UP"}


def test_ready_checks_database(client):
    assert client.get("/ready").json() == {"status": "READY"}


def test_root_and_info(client):
    assert client.get("/").json()["service"] == "TaskBoard API"
    info = client.get("/api/info").json()
    assert set(info) == {"service", "version", "environment"}


def test_create_and_get_task(client):
    task = make(client)
    assert task["title"] == "Deploy application"
    assert task["status"] == "TODO"
    assert client.get(f"/api/tasks/{task['id']}").json()["assignee"] == "Anushka"


def test_list_newest_first(client):
    make(client, title="first")
    make(client, title="second")
    titles = [t["title"] for t in client.get("/api/tasks").json()]
    assert titles == ["second", "first"]


def test_update_status(client):
    task = make(client)
    r = client.put(f"/api/tasks/{task['id']}", json={"status": "DONE"})
    assert r.status_code == 200
    assert r.json()["status"] == "DONE"


def test_stats(client):
    make(client, status="TODO")
    make(client, status="IN_PROGRESS")
    make(client, status="DONE")
    make(client, status="DONE")
    assert client.get("/api/tasks/stats").json() == {"total": 4, "todo": 1, "inProgress": 1, "done": 2}


def test_delete_task(client):
    task = make(client)
    assert client.delete(f"/api/tasks/{task['id']}").status_code == 204
    assert client.get(f"/api/tasks/{task['id']}").status_code == 404


def test_validation_rejects_bad_input(client):
    assert client.post("/api/tasks", json={"title": ""}).status_code == 422
    assert client.post("/api/tasks", json={"title": "x", "priority": "URGENT"}).status_code == 422


def test_missing_task_404(client):
    assert client.get("/api/tasks/9999").status_code == 404
    assert client.put("/api/tasks/9999", json={"status": "DONE"}).status_code == 404


def test_metrics_exposed(client):
    client.get("/health")
    body = client.get("/metrics").text
    assert "http_requests_total" in body

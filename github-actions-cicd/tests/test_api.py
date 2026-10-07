import pytest

from app.main import app


@pytest.fixture
def client():
    app.config["TESTING"] = True
    return app.test_client()


def test_index(client):
    body = client.get("/").get_json()
    assert body["app"] == "calculator-api"


def test_health(client):
    assert client.get("/health").get_json() == {"status": "ok"}


@pytest.mark.parametrize("op,expected", [("add", 15), ("subtract", 5), ("multiply", 50), ("divide", 2)])
def test_operations(client, op, expected):
    body = client.get(f"/api/{op}?a=10&b=5").get_json()
    assert body["result"] == expected


def test_divide_by_zero_returns_400(client):
    resp = client.get("/api/divide?a=1&b=0")
    assert resp.status_code == 400


def test_unknown_operation_returns_404(client):
    assert client.get("/api/power?a=2&b=3").status_code == 404


def test_missing_params_returns_400(client):
    assert client.get("/api/add?a=1").status_code == 400

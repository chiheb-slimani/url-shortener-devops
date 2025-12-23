import os

os.environ["DB_PATH"] = ":memory:"

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_healthz():
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_shorten_and_redirect():
    response = client.post("/shorten", json={"url": "https://example.com"})
    assert response.status_code == 200
    payload = response.json()
    assert "code" in payload
    assert payload["short_url"].endswith("/" + payload["code"])
    redirect = client.get(f"/{payload['code']}", allow_redirects=False)
    assert redirect.status_code == 302
    assert redirect.headers["location"] == "https://example.com"


def test_invalid_url():
    response = client.post("/shorten", json={"url": "ftp://example.com"})
    assert response.status_code == 400


def test_not_found():
    response = client.get("/nope")
    assert response.status_code == 404
    assert response.json()["error"] == "not found"


def test_metrics():
    response = client.get("/metrics")
    assert response.status_code == 200
    assert "request_count" in response.text

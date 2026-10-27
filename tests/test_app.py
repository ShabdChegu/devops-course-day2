"""Placeholder tests - ch.1's point is that `make test` already works.

ch.2 adds a real smoke test (tests/test_smoke.py) that exercises the
SQLite layer, so the CI pipeline in ch.7 has something meaningful to run.
"""

from fastapi.testclient import TestClient

from notes_app.main import app

client = TestClient(app)


def test_index():
    r = client.get("/")
    assert r.status_code == 200
    assert r.json()["app"] == "notes"


def test_crud_cycle():
    r = client.post("/notes", json={"title": "first note", "body": "hello"})
    assert r.status_code == 201
    note_id = r.json()["id"]

    assert client.get(f"/notes/{note_id}").status_code == 200
    assert client.delete(f"/notes/{note_id}").status_code == 204
    assert client.get(f"/notes/{note_id}").status_code == 404

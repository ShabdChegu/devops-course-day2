"""App tests - one per face of the API.

ch.1's point was that `make test` works from day one. ch.3 adds the HTML
face, so this file now covers both: the JSON API (the "API") and the
browser-rendered pages (the "UI"). ch.2's persistence proof lives in
test_smoke.py; the full CI-ready suite grows in ch.14.
"""

from fastapi.testclient import TestClient

from notes_app.main import app

client = TestClient(app)


def test_home_page_is_html():
    r = client.get("/")
    assert r.status_code == 200
    assert "notes-app" in r.text
    assert "text/html" in r.headers["content-type"]


def test_json_crud_cycle():
    r = client.post("/notes", json={"title": "first note", "body": "hello"})
    assert r.status_code == 201
    note_id = r.json()["id"]

    assert client.get(f"/notes/{note_id}").status_code == 200
    assert client.delete(f"/notes/{note_id}").status_code == 204
    assert client.get(f"/notes/{note_id}").status_code == 404


def test_html_flow():
    """The browser's journey: list, write a note through the form, open it,
    all against the *same* model layer the JSON API uses."""
    assert "New note" in client.get("/new").text

    # 303 = "created, look at the new page" - don't follow it, it's a lesson
    r = client.post(
        "/new",
        data={"title": "from the form", "body": "html face"},
        follow_redirects=False,
    )
    assert r.status_code == 303

    show = client.get(r.headers["location"])
    assert show.status_code == 200
    assert "from the form" in show.text
    assert "html face" in show.text

    # ...and the note written through HTML is visible to the JSON API:
    new_id = int(r.headers["location"].rsplit("/", 1)[-1])
    ids = [n["id"] for n in client.get("/notes").json()]
    assert new_id in ids


def test_html_delete():
    """Delete through the show page's button: POST /note/{id}/delete
    (forms can't send DELETE verbs) - 303 home, then gone on both faces."""
    r = client.post("/notes", json={"title": "doomed", "body": ""})
    note_id = r.json()["id"]

    d = client.post(f"/note/{note_id}/delete", follow_redirects=False)
    assert d.status_code == 303
    assert d.headers["location"] == "/"

    assert client.get(f"/note/{note_id}").status_code == 404
    assert client.get(f"/notes/{note_id}").status_code == 404


def test_missing_note_is_404_on_both_faces():
    assert client.get("/note/999999").status_code == 404
    assert client.get("/notes/999999").status_code == 404

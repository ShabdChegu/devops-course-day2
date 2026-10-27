"""The first *real* smoke test - ch.2's reason to exist.

ch.1's test_app.py only proved the API returns the right status codes against
an in-memory dict. These tests prove notes actually reach the database: a
*second* session against the same engine must see what the app's own session
wrote. If someone "fixes" the layer by quietly putting a dict back inside
models.py, the second-session proof below does not hold - which is the part
that keeps CI (ch.7) honest about whether data survived.
"""

from sqlalchemy.orm import Session

from notes_app import models


def test_note_round_trips_through_database():
    """Write a note, read it back, delete it - the plain CRUD cycle."""
    note = models.create_note("smoke", "did it reach the DB?")
    assert note.id > 0  # the DB assigned an id, not our old in-memory counter

    fetched = models.get_note(note.id)
    assert fetched is not None
    assert fetched.title == "smoke"

    assert models.delete_note(note.id) is True
    assert models.get_note(note.id) is None
    assert models.delete_note(note.id) is False  # gone means gone


def test_a_second_session_sees_the_written_row():
    """The persistence proof: open a fresh session against the same engine
    (like another process opening the same file) and confirm the row is
    there - that only works if the write truly committed to SQLite."""
    written = models.create_note("visible", "across connections")
    with Session(models.engine) as other_session:
        fresh = other_session.get(models.NoteRow, written.id)
    assert fresh is not None
    assert fresh.title == "visible"

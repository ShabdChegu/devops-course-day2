"""Model layer - where notes are stored.

ch.1: an in-memory dict. The moment the server restarts, notes are gone -
that is the exact problem ch.2 fixes by swapping this module's *inside*
for SQLite while keeping the same public functions. views.py never notices.
"""

from dataclasses import dataclass
from datetime import UTC, datetime


@dataclass
class Note:
    id: int
    title: str
    body: str
    created_at: str


_notes: dict[int, Note] = {}
_next_id = 1


def list_notes() -> list[Note]:
    """All notes, in insertion order."""
    return list(_notes.values())


def get_note(note_id: int) -> Note | None:
    return _notes.get(note_id)


def create_note(title: str, body: str) -> Note:
    global _next_id
    note = Note(
        id=_next_id,
        title=title,
        body=body,
        created_at=datetime.now(UTC).isoformat(),
    )
    _notes[note.id] = note
    _next_id += 1
    return note


def delete_note(note_id: int) -> bool:
    """True if a note was deleted, False if the id didn't exist."""
    return _notes.pop(note_id, None) is not None

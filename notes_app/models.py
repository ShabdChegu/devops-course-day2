"""Model layer - where notes live.

ch.1 kept notes in an in-process dict: instant, but everything vanished the
moment the server stopped. ch.2 (here) moves the storage to a SQLite file via
SQLAlchemy 2.0 while keeping the *exact same four public functions*, so
views.py and main.py don't change at all. That's the layering lesson of this
chapter: the swap happens inside one module.

Two types that look similar:
- Note    a plain dataclass - what the controllers serialize to JSON (unchanged since ch.1)
- NoteRow the SQLAlchemy ORM mapping - one row of the `notes` table

`DATABASE_URL` (env var) picks the storage. Default is `sqlite:///notes.db`,
a file in the working directory. In ch.5 the same module points at Postgres
by changing just that variable - nothing below it moves.
"""

import os
from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy import String, Text, create_engine
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column

# Default: a file-based SQLite DB next to where the app is started.
# Tests (tests/conftest.py) point this at a throwaway file; ch.5 points it
# at Postgres.
DATABASE_URL = os.environ.get("DATABASE_URL", "sqlite:///notes.db")

# SQLite-only connection options:
# - check_same_thread: False lets uvicorn's request threads share pooled
#   connections safely.
# - timeout: 30s is SQLite's "busy wait" - if another writer briefly holds
#   the DB lock, wait instead of erroring with "database is locked".
# Postgres (ch.5) needs neither, so connect_args stays empty there.
if DATABASE_URL.startswith("sqlite"):
    connect_args = {"check_same_thread": False, "timeout": 30}
else:
    connect_args = {}

engine = create_engine(DATABASE_URL, connect_args=connect_args)


class Base(DeclarativeBase):
    pass


class NoteRow(Base):
    """One row of the `notes` table, as the ORM sees it."""

    __tablename__ = "notes"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    body: Mapped[str] = mapped_column(Text, default="", nullable=False)
    created_at: Mapped[str] = mapped_column(String(64), nullable=False)


# Create the table on import (no-op if it already exists). This is the whole
# of this course's migrations story - ch.14 mentions `alembic` as the real
# tool when schemas start evolving.
Base.metadata.create_all(engine)


@dataclass
class Note:
    """The note shape the API returns - byte-for-byte what ch.1 returned."""

    id: int
    title: str
    body: str
    created_at: str


def _to_note(row: NoteRow) -> Note:
    """Translate an ORM row into the API's shape."""
    return Note(id=row.id, title=row.title, body=row.body, created_at=row.created_at)


def list_notes() -> list[Note]:
    """All notes, oldest first (id order = insertion order)."""
    with Session(engine) as session:
        rows = session.query(NoteRow).order_by(NoteRow.id).all()
        return [_to_note(r) for r in rows]


def get_note(note_id: int) -> Note | None:
    with Session(engine) as session:
        row = session.get(NoteRow, note_id)
        return _to_note(row) if row is not None else None


def create_note(title: str, body: str) -> Note:
    row = NoteRow(title=title, body=body, created_at=datetime.now(UTC).isoformat())
    with Session(engine) as session:
        session.add(row)
        session.commit()  # durable; releases the SQLite write lock; SQLite assigns the id
        session.refresh(row)  # commit() expires every attribute on the instance;
        # reload them *while we still hold the session* so _to_note(row)
        # below can read them. Forgetting this is the classic
        # DetachedInstanceError.
    return _to_note(row)


def delete_note(note_id: int) -> bool:
    """True if a note was deleted, False if the id didn't exist."""
    with Session(engine) as session:
        row = session.get(NoteRow, note_id)
        if row is None:
            return False
        session.delete(row)
        session.commit()
        return True

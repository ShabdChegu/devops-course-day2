"""Controller layer - HTTP routes (JSON API).

ch.1 ships JSON only. ch.3 adds Jinja-rendered HTML routes to this same
file, served from the same model functions - two faces of one dataset.
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from .models import Note, create_note, delete_note, get_note, list_notes

router = APIRouter()


class NoteIn(BaseModel):
    """Request body for POST /notes."""

    title: str = Field(min_length=1, examples=["Buy milk"])
    body: str = Field(default="", examples=["2L, whole milk"])


@router.get("/")
def index() -> dict:
    """Landing page - tells you where the API lives."""
    return {"app": "notes", "api": ["/notes", "/notes/{id}", "/docs"]}


@router.get("/notes", response_model=list[Note])
def read_notes() -> list[Note]:
    return list_notes()


@router.get("/notes/{note_id}", response_model=Note)
def read_note(note_id: int) -> Note:
    note = get_note(note_id)
    if note is None:
        raise HTTPException(status_code=404, detail=f"note {note_id} not found")
    return note


@router.post("/notes", status_code=201, response_model=Note)
def add_note(payload: NoteIn) -> Note:
    return create_note(payload.title, payload.body)


@router.delete("/notes/{note_id}", status_code=204)
def remove_note(note_id: int) -> None:
    if not delete_note(note_id):
        raise HTTPException(status_code=404, detail=f"note {note_id} not found")

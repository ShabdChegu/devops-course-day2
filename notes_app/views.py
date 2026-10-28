"""Controller layer - HTTP routes.

ch.1 shipped the JSON API. ch.3 adds a Jinja2 *HTML face* on top of the exact
same model functions - two faces of one dataset. Read the file top to bottom:
the HTML section is what a browser wants, the JSON section is what a client
wants. Both call the same `create_note`/`list_notes`/... - the layering from
ch.1-2 paying off: we added a whole UI and `models.py` never changed.

ch.6: the controllers log the two business events ("note created/deleted").
The *shape* of every line (JSON, one object per line) lives in
logging_config.py; the controller just says what happened, with fields in
`extra=` - those ride into the JSON object by name.
"""

import logging

from fastapi import APIRouter, Form, HTTPException, Request
from fastapi.responses import RedirectResponse
from pydantic import BaseModel, Field

from .models import Note, create_note, delete_note, get_note, list_notes

logger = logging.getLogger(__name__)

router = APIRouter()


def _render(request: Request, name: str, **context):
    """Render a Jinja template - main.py mounted the templates on the app."""
    return request.app.state.templates.TemplateResponse(request, name, context)


# ---------------------------------------------------------------------------
# HTML face (ch.3) - rendered pages a browser opens
# ---------------------------------------------------------------------------


@router.get("/")
def index_page(request: Request):
    """Home page - the full note list, from templates/index.html."""
    return _render(request, "index.html", notes=list_notes())


@router.get("/new")
def new_page(request: Request):
    """The 'write a note' form - templates/new.html."""
    return _render(request, "new.html")


@router.post("/new")
def new_note(
    request: Request, title: str = Form(min_length=1), body: str = Form("")
) -> RedirectResponse:
    """Create a note from the HTML form, then redirect to the fresh note."""
    note = create_note(title, body)
    logger.info("note created", extra={"event": "note_created", "note_id": note.id})
    return RedirectResponse(url=f"/note/{note.id}", status_code=303)


@router.get("/note/{note_id}")
def show_page(request: Request, note_id: int):
    """A single note - templates/show.html (404 if it doesn't exist)."""
    note = get_note(note_id)
    if note is None:
        raise HTTPException(status_code=404, detail=f"note {note_id} not found")
    return _render(request, "show.html", note=note)


@router.post("/note/{note_id}/delete")
def delete_page(note_id: int) -> RedirectResponse:
    """HTML delete: forms can't send DELETE verbs, so the show page POSTs
    here. Same PRG pattern as /new - redirect home, not to a page that no
    longer exists."""
    if not delete_note(note_id):
        raise HTTPException(status_code=404, detail=f"note {note_id} not found")
    logger.info("note deleted", extra={"event": "note_deleted", "note_id": note_id})
    return RedirectResponse(url="/", status_code=303)


# ---------------------------------------------------------------------------
# JSON face (ch.1) - the API a client calls; unchanged in behavior
# ---------------------------------------------------------------------------


class NoteIn(BaseModel):
    """Request body for POST /notes."""

    title: str = Field(min_length=1, examples=["Buy milk"])
    body: str = Field(default="", examples=["2L, whole milk"])


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
    note = create_note(payload.title, payload.body)
    logger.info("note created", extra={"event": "note_created", "note_id": note.id})
    return note


@router.delete("/notes/{note_id}", status_code=204)
def remove_note(note_id: int) -> None:
    if not delete_note(note_id):
        raise HTTPException(status_code=404, detail=f"note {note_id} not found")
    logger.info("note deleted", extra={"event": "note_deleted", "note_id": note_id})

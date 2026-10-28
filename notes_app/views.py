"""Controller layer - HTTP routes.

ch.1 shipped the JSON API. ch.3 adds a Jinja2 *HTML face* on top of the exact
same model functions - two faces of one dataset. Read the file top to bottom:
the HTML section is what a browser wants, the JSON section is what a client
wants. Both call the same `create_note`/`list_notes`/... - the layering from
ch.1-2 paying off: we added a whole UI and `models.py` never changed.
"""

from fastapi import APIRouter, Form, HTTPException, Request
from fastapi.responses import RedirectResponse
from pydantic import BaseModel, Field

from .models import Note, create_note, delete_note, get_note, list_notes

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
    return RedirectResponse(url=f"/note/{note.id}", status_code=303)


@router.get("/note/{note_id}")
def show_page(request: Request, note_id: int):
    """A single note - templates/show.html (404 if it doesn't exist)."""
    note = get_note(note_id)
    if note is None:
        raise HTTPException(status_code=404, detail=f"note {note_id} not found")
    return _render(request, "show.html", note=note)


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
    return create_note(payload.title, payload.body)


@router.delete("/notes/{note_id}", status_code=204)
def remove_note(note_id: int) -> None:
    if not delete_note(note_id):
        raise HTTPException(status_code=404, detail=f"note {note_id} not found")

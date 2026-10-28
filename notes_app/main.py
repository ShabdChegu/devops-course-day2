"""App entry point.

`notes_app.main:app` is the object uvicorn (and ch.4's Dockerfile) imports.
Keeping the app instance in one tiny file is the whole MVC point:
main.py wires things together, views.py handles requests, models.py holds data.

ch.3: main.py learns to serve HTML - Jinja2 templates and a static mount are
wired here (wiring belongs at the app level), while the actual HTML routes
live in views.py, right next to the JSON routes they mirror.
"""

from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from .logging_config import setup_logging
from .views import router

# ch.6: structured logging, one call at startup. main.py is the entry
# point - so `make run`, the ch.4 container, and Compose's app service all
# get it, and pytest (which imports the app but never main's body) does
# not reconfigure logging behind its back.
setup_logging()

app = FastAPI(title="notes-app")
app.include_router(router)

# Templates & static assets live at the repo root, next to the notes_app
# package (convention: code in the package, assets beside it - the same
# split ch.4's Dockerfile COPYs).
ROOT_DIR = Path(__file__).resolve().parent.parent

templates = Jinja2Templates(directory=ROOT_DIR / "templates")
app.mount("/static", StaticFiles(directory=ROOT_DIR / "static"), name="static")
# Views reach the templates through the app instance - no module-level
# import cycle, and it's the documented FastAPI way.
app.state.templates = templates

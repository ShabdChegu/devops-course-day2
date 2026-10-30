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

from .health import router as health_router
from .logging_config import setup_logging
from .otel import setup_otel
from .views import router

# ch.6: structured logging, one call at startup. main.py is the entry
# point - so `make run`, the ch.4 container, and Compose's app service all
# get it, and pytest (which imports the app but never main's body) does
# not reconfigure logging behind its back.
setup_logging()

app = FastAPI(title="notes-app")
app.include_router(router)
# ch.9: liveness + readiness. A router, mounted like the app router, so
# /health and /ready live with the other routes - one place to find them.
app.include_router(health_router)

# Templates & static assets live at the repo root, next to the notes_app
# package (convention: code in the package, assets beside it - the same
# split ch.4's Dockerfile COPYs).
ROOT_DIR = Path(__file__).resolve().parent.parent

templates = Jinja2Templates(directory=ROOT_DIR / "templates")
app.mount("/static", StaticFiles(directory=ROOT_DIR / "static"), name="static")
# Views reach the templates through the app instance - no module-level
# import cycle, and it's the documented FastAPI way.
app.state.templates = templates

# ch.9: instrumentation, last - after the app is fully built. FastAPI
# auto-spans every route; otel.py also registers the trace_id hook with
# ch.6's formatter (so each log line during a request carries that
# request's trace). OTEL_ENABLED=false skips all of it (tests rely on that
# - see tests/conftest.py).
setup_otel(app)

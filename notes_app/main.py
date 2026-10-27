"""App entry point.

`notes_app.main:app` is the object uvicorn (and ch.4's Dockerfile) imports.
Keeping the app instance in one tiny file is the whole MVC point:
main.py wires things together, views.py handles requests, models.py holds data.
"""

from fastapi import FastAPI

from .views import router

app = FastAPI(title="notes-app")
app.include_router(router)

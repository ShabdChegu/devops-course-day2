"""notes-app - the running example for the DevOps course.

Package layout (ch.1):
    main.py        app instance + router mount
    models.py      data layer (in-memory -> SQLite in ch.2 -> Postgres in ch.5)
    views.py       controller layer (JSON API; Jinja HTML routes in ch.3)
Later chapters add otel.py (ch.10) and logging_config.py (ch.6) here too.
"""

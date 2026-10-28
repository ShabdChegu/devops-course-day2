# DevOps course command surface. Grows one target group per chapter:
#   ch.0 check+help | ch.1 run/test/lint | ch.4 build | ch.5 up/down
#   ch.7 pipeline | ch.8 deploy | ch.15 polish

IMAGE ?= notes-app

.DEFAULT_GOAL := help

help:
	@echo "DevOps course - available commands"
	@echo ""
	@echo "  make check   verify prerequisites (tools, docker daemon, free ports)"
	@echo "  make run     start the app on :8000 locally (dev, auto-reload)"
	@echo "  make build   build the Docker image (tag: notes-app)"
	@echo "  make run-docker  run the built image on :8000 (validates the artifact)"
	@echo "  make test    run the test suite"
	@echo "  make lint    ruff check + format check"
	@echo "  make lint-fix  ruff auto-fix + format"
	@echo "  make up      start the stack: app + postgres (compose profile core)"
	@echo "  make down    stop the stack"
	@echo "  make scan    secret scan (the pre-commit hook + CI run this same script)"
	@echo "  make help    this list"

# Prerequisites gate - see scripts/check.sh
check:
	@bash scripts/check.sh

# uv owns the venv: `uv run` creates .venv on first use from pyproject/uv.lock.
run:
	uv run uvicorn notes_app.main:app --reload --port 8000

test:
	uv run pytest -q

lint:
	uv run ruff check . && uv run ruff format --check .

# ch.4: build the container image. .dockerignore trims the build context;
# the lockfile makes the install reproducible.
build:
	docker build -t $(IMAGE) .

# ch.5: start/stop the core stack (app + postgres). `up` rebuilds the app
# image first, then runs the core profile detached. Only core - monitoring /
# jenkins / jaeger / signoz stay OFF until their chapters add a profile.
# .env is created from .env.example on first run so `make up` just works;
# change the password in .env before you rely on it (it never gets committed).
up:
	@if [ ! -f .env ]; then echo ".env missing - created from .env.example (change the password!)"; cp .env.example .env; fi
	docker compose --profile core up -d --build

down:
	docker compose --profile core down

# ch.5's secrets habit: the same scan that pre-commit runs, on demand.
# Runs gitleaks if you have it, else the regex fallback in the script.
scan:
	@bash scripts/scan-secrets.sh

# ch.4: run the *image*, not the local source - the "does the artifact work
# anywhere?" check. Opposite of `make run` (dev loop, auto-reload, local
# notes.db): no reload, no local deps, data trapped inside the container
# (the exact problem ch.5's compose + volume solves).
run-docker: build
	docker run --rm -p 8000:8000 $(IMAGE)

.PHONY: help check run test lint lint-fix build run-docker up down scan

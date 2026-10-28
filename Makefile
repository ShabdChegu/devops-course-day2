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

# ch.4: run the *image*, not the local source - the "does the artifact work
# anywhere?" check. Opposite of `make run` (dev loop, auto-reload, local
# notes.db): no reload, no local deps, data trapped inside the container
# (the exact problem ch.5's compose + volume solves).
run-docker: build
	docker run --rm -p 8000:8000 $(IMAGE)

.PHONY: help check run test lint lint-fix build run-docker

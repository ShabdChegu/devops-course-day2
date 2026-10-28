# DevOps course command surface. Grows one target group per chapter:
#   ch.0 check+help | ch.1 run/test/lint | ch.4 build | ch.5 up/down
#   ch.6 logs | ch.7 pipeline | ch.8 deploy | ch.15 polish

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
	@echo "  make reset-db  wipe the postgres volume + re-init from .env (drops all notes)"
	@echo "  make scan    secret scan (the pre-commit hook + CI run this same script)"
	@echo "  make logs    tail the app's structured (JSON) logs from the stack"
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
	# `compose up -d` "succeeds" even when the app then crash-loops (compose
	# created the box; it doesn't watch it run). And the container's STATE
	# says "running" for a few seconds while the process is still booting,
	# so state alone races the crash: the real question is "is the app
	# answering?". Wait up to 30s for an HTTP 200, or a terminal state.
	# The #1 silent failure is a Postgres auth mismatch (docs/05 pitfall #1).
	@cid=$$(docker compose --profile core ps -q -a app | head -1); \
	ok=no; state=missing; \
	for i in $$(seq 1 30); do \
		state=$$(docker inspect --format '{{.State.Status}}' "$$cid" 2>/dev/null || echo missing); \
		case "$$state" in exited|dead) break;; esac; \
		if curl -sf -o /dev/null http://localhost:8000/notes 2>/dev/null; then ok=yes; break; fi; \
		sleep 1; \
	done; \
	if [ "$$ok" = "yes" ]; then \
		echo "core stack up: app + postgres running (verified via HTTP)"; \
	else \
		echo ""; \
		echo "!! app is not serving (container state: $$state)."; \
		echo "   Most likely cause (docs/05-compose.md, pitfall #1): your .env password does"; \
		echo "   not match the pgdata volume - Postgres sets it only when the volume is"; \
		echo "   FIRST created, so editing .env later makes the app fail authentication"; \
		echo "   and crash-loop at import time."; \
		echo "   Fix: make reset-db    (wipes the volume, drops the notes, re-inits from .env)"; \
		echo ""; \
		echo "app log tail:"; \
		docker logs --tail 5 "$$cid" 2>&1 | tail -5; \
		exit 1; \
	fi

down:
	docker compose --profile core down

# The Postgres gotcha (docs/05-compose.md, pitfall #1): the DB password is
# fixed the first time the pgdata volume is created. Changing .env LATER does
# not re-init an existing volume, so the app can no longer authenticate and
# `make up` leaves it crash-looping. Reset the database to re-init it from
# your current .env - this DROPS all notes (it's the course dev DB).
reset-db:
	docker compose --profile core down -v
	$(MAKE) up

# ch.5's secrets habit: the same scan that pre-commit runs, on demand.
# Runs gitleaks if you have it, else the regex fallback in the script.
scan:
	@bash scripts/scan-secrets.sh

# ch.6: follow the app's structured (JSON) logs - a container's logs live
# on stdout, and `docker compose logs` is how you read them. Ctrl-C stops.
logs:
	docker compose --profile core logs -f app

# ch.4: run the *image*, not the local source - the "does the artifact work
# anywhere?" check. Opposite of `make run` (dev loop, auto-reload, local
# notes.db): no reload, no local deps, data trapped inside the container
# (the exact problem ch.5's compose + volume solves).
run-docker: build
	docker run --rm -p 8000:8000 $(IMAGE)

.PHONY: help check run test lint lint-fix build run-docker up down reset-db scan logs

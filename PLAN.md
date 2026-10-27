# DevOps Course — Plan

An incremental, branch-per-concept course. A tiny **Notes app** (FastAPI + a Jinja2 UI) is
the running example. The app code stays small; each chapter adds one DevOps concept around it.

Every chapter is its own git branch, and each branch's end state is clean, working, and pushed to
`main` (or the next branch is cut from it).

## Principles
- One concept per branch. Nothing else changes.
- Free & self-contained: Docker, Jenkins (in Docker), SQLite→Postgres (in Docker), Prometheus/Grafana/Jaeger, and SigNoz (all in Docker).
- No cloud account, no Terraform (IaC covered conceptually only, in the README).
- Each branch ships a `docs/<NN>-<slug>.md` that teaches the concept *and* explains exactly what changed in this branch (diff of the idea, not just the files).
- **Tests & a `Makefile` from ch.1–2, not late:** the CI pipeline (ch.7) would be hollow with nothing to run; a minimal smoke test and a consistent command surface land early so later chapters build on them.
- **uv for Python:** `pyproject.toml` + `uv.lock` — no hand-rolled venvs, no `requirements.txt`; the `Makefile` wraps `uv run` so students don't memorize commands, and the Dockerfile builds from the lockfile for reproducible installs.
- **MVC-lite, small files:** `models.py` (data layer), `views.py` (routes/controllers), `templates/` (Jinja2 UI, one file per page). Each file has one job, so any chapter's diff stays readable.
- **Correlation & SLOs, not just dashboards:** tracing, logging, and metrics are tied together (ch.10 `trace_id` in logs, ch.11 SLO alert) and capped by an incident drill (ch.12) where students actually *find* a failure — that's the payoff the whole observability arc is building toward.
- **End with one tool, not three:** the arc (Grafana + Jaeger + log files) is deliberately assembled piece by piece so each concept lands alone; ch.13 then collapses it into **SigNoz** — one OTLP pipeline, one UI, one drill re-run — showing students what a unified observability platform actually replaces.

## The app
- **Controllers (`views.py`):** JSON CRUD (`GET/POST/DELETE /notes`) *and* Jinja-rendered pages — the same data, two faces. Nice teaching moment when ch.3 lands.
- **Model layer (`models.py`):** in-memory dict (ch.1) → SQLite (ch.2) → Postgres (ch.5). The controllers never notice the swap — that's the point of the layer.
- **UI:** Jinja2 templates in `templates/`, one file per page, plus a small `static/` for CSS/JS (ch.3+).
- **Health:** `/health` (process alive) and `/ready` (deps up), added in ch.9.

## Chapter / branch map

| # | Chapter | Branch | What's added | Key files |
|---|---------|--------|--------------|-----------|
| 0 | Course intro, repo layout, git basics | `main` | `README.md` (with the evolving mermaid diagram — **#9**), this `PLAN.md`, `docs/_template.md` (**#1**), `make check` prerequisites gate (**#5**), repo skeleton | `README.md`, `PLAN.md`, `docs/_template.md`, `Makefile` (check) |
| 1 | FastAPI backend, in-memory store | `01-fastapi` | uv setup (`pyproject.toml` + `uv.lock` — no hand-rolled venv/requirements); **ruff** as the single lint/format tool (**#2**); MVC skeleton in the `notes_app/` package: `main.py`, `models.py` (in-memory store), `views.py` (CRUD routes); `Makefile` (`make run` / `make test` / `make lint` from day one); one placeholder test so `make test` works | `pyproject.toml`, `notes_app/`, `Makefile`, `tests/` |
| 2 | SQLite + SQLAlchemy | `02-sqlite` | model layer swaps in-memory → SQLite (SQLAlchemy); `views.py` **unchanged** — that's the layering lesson; `.gitignore` for `*.db`; **first smoke test** (`tests/test_smoke.py`) so CI later has something real to run | `notes_app/models.py`, `tests/` |
| 3 | Jinja UI, MVC in place | `03-jinja` | Jinja2 mount; one template per page (`templates/index.html`, `templates/new.html`, `templates/show.html`); `static/style.css` + `app.js`; same controller data serves HTML pages and the JSON API | `templates/`, `static/`, `notes_app/views.py` |
| 4 | Dockerize the app | `04-docker` | uv-based `Dockerfile` (`uv sync` from `uv.lock` — fast, reproducible installs), `.dockerignore`; build + run; `docker run` vs local run | `Dockerfile`, `.dockerignore` |
| 5 | Docker Compose + Postgres | `05-compose` | `docker-compose.yml` (app + postgres) with **profiles (`core` etc.)** (**#3**); env vars; model layer SQLite→Postgres (DB URL from env — the secrets story starts here, **+ secret-scan pre-commit hook (#8)**) | `docker-compose.yml`, `notes_app/models.py`, `.pre-commit-config.yaml` |
| 6 | Structured logging | `06-logging` | `logging_config.py` (JSON logs), read via `docker logs`; log file + rotation concept | `notes_app/logging_config.py` |
| 7 | Jenkins — CI pipeline | `07-jenkins-ci` | `Jenkinsfile` (lint, test, build image); Jenkins in `docker/` via compose profile | `Jenkinsfile`, `docker/jenkins-compose.yml` |
| 8 | Jenkins — CD (deploy) | `08-jenkins-cd` | Deploy stage: tag/push image, a `scripts/deploy.sh` that pulls + restarts app container | `Jenkinsfile`, `scripts/deploy.sh` |
| 9 | Health & readiness | `09-health` | `/health`, `/ready`; `HEALTHCHECK` in Dockerfile; compose `healthcheck:`; CD verifies | `notes_app/main.py`, `Dockerfile`, `docker-compose.yml` |
| 10 | OpenTelemetry — Tracing | `10-otel-tracing` | `otel.py` instruments FastAPI; exporter starts as Console (so no new containers yet); **add `trace_id` to every log line** (one line, connects logging ↔ tracing) | `notes_app/otel.py`, `pyproject.toml`, `notes_app/logging_config.py` |
| 11 | OpenTelemetry — Metrics (Prometheus + Grafana) | `11-otel-metrics` | Prometheus exporter on the app; `prometheus` + `grafana` added to compose; starter dashboard JSON; **one SLO alert on error rate / p95 latency** | `docker-compose.yml`, `grafana/` |
| 12 | Jaeger for traces | `12-jaeger` | OTLP collector + Jaeger UI in compose; point the exporter at it; view a trace; **incident drill**: kill the DB container / inject latency, find the cause in Jaeger + Grafana, write it up | `docker-compose.yml`, `docs/12-incident-drill.md` |
| 13 | SigNoz — unified observability | `13-signoz` | SigNoz (free, ClickHouse-based, docker-compose: collector + ClickHouse + UI) replaces the three-tool setup: traces go to the SigNoz collector instead of Jaeger; app log file is collected into SigNoz (log receiver, so `trace_id` in ch.10 links logs↔traces in **one** UI); SLO alert from ch.11 now lives in SigNoz; **re-run the ch.12 incident drill** entirely inside SigNoz — the "three screens → one screen" moment | `docker-compose.yml`, `notes_app/otel.py`, `docs/13-signoz.md` |
| 14 | Tests in CI (formalize) | `14-testing` | Expand the ch.2 smoke test into a full `pytest` suite (API CRUD); wire properly into the Jenkins `test` stage | `tests/`, `Jenkinsfile` |
| 15 | Full pipeline recap | `15-recap` | Polished `README.md` walkthrough of the whole flow end-to-end; tidy `Makefile` targets (`up`, `down`, `build`, `test`, `deploy`, `pipeline`) | `Makefile`, `README.md` |

**Removed vs. initial draft:** Terraform (skipped per scope), Secrets (merged into ch.5's env-var teaching + a note in the README), and the "one optional cloud" idea.
**Swapped on request:** hand-rolled venv/`requirements.txt` → **uv** (`pyproject.toml` + `uv.lock`); static-SPA frontend → **Jinja2 templates** with a MVC-lite split (`models.py` / `views.py` / `templates/`).

## Conventions & scaffolding (added on request, items 1–10)

Each item below is a *standing convention* applied across chapters — not a new chapter. Where it first
lands is noted; it then persists in later chapters. Numbering matches the review list.

### 1. Standard chapter-doc template — lands ch.0, used ch.1–15
`docs/_template.md` fixes the shape of every chapter doc so pedagogy is consistent and each concept
self-verifies. Sections:
- **Goal** — one sentence: "After this chapter you can …"
- **Concept** — the *why* (what problem the tool solves, what it replaces), not just the how.
- **What changed in this branch** — a diff of the idea (which files, which behavior) so a reader can
  check out the branch and know exactly what to look for.
- **Try it yourself** — exact commands + expected output.
- **Common pitfalls** — the failure modes we hit, written down on purpose.
- **Stretch exercise** — one optional deeper task (see #7).
- **Self-check quiz** — 3–5 questions; answers in a collapsed `<details>` block at the end.
- **Classroom demo checklist** — what to show live vs. pre-record/screenshot (see #10).

### 2. ruff as the single lint/format tool — lands ch.1
`ruff` goes in `pyproject.toml` (dev group) alongside `pytest` — no flake8/black/isort split.
- `make lint` = `uv run ruff check . && uv run ruff format --check .`
- `make lint-fix` = `uv run ruff check --fix . && uv run ruff format .`
- Ch.7's CI "lint" stage runs exactly `make lint`, so the rule is enforced in the same place students
  run it locally. One tool, zero config sprawl.

### 3. Compose profiles to bound the memory footprint — lands ch.5, used ch.5–13
By ch.13 the stack is ~8 services; a 4GB laptop can't run all of it. From ch.5 every service in
`docker-compose.yml` is tagged with a profile:
- `core` — app + postgres. **`make up` starts only `core` by default.**
- `monitoring` — prometheus + grafana (ch.11)
- `jaeger` — collector + UI (ch.12)
- `signoz` — collector + clickhouse + UI + log collector (ch.13)
- `jenkins` — the Jenkins container (ch.7)
`make up` = core only; `make up-monitoring` / `make up-signoz` / `make up-all` add profiles. Low-memory
students never get stuck, and ch.13's "three tools → one" story becomes concrete: stop `monitoring` +
`jaeger`, start `signoz` — same OTLP target, one screen.

### 4. Image tag = git commit SHA — lands ch.8
The CD stage tags the built image with the short commit hash: `IMG=notes-app:$(git rev-parse --short
HEAD)`, pushes it, and the deploy script records the SHA it's running (a `/version` endpoint added
alongside ch.9's health, or metadata sidecar). Teaches the #1 real-ops question — "what code is actually
in prod right now?" — for one line of cost.

### 5. `make check` prerequisites gate — lands ch.0
Before anything else, `make check` verifies the environment and fails with an *actionable* message:
- tools present: `git`, `uv`, `docker`
- docker daemon reachable (`docker info` succeeds)
- required ports are free (8000 app, 5432 postgres, 9090 prometheus, 16686 jaeger, 8080/9095 signoz,
  13000 jenkins) — and it names the PID/process holding a clashing port.
Every chapter doc's "Try it yourself" starts with `make check && make up`. This pre-empts the #1
"doesn't work on my machine" cause in a Docker course: a dead daemon or a port clash.

### 6. The Jenkins-in-Docker gotcha, documented on purpose — lands ch.7
Building a Docker image *inside* a Jenkins container is where most first CI pipelines break. We pick
the **host-socket** approach — mount the host's Docker socket into the Jenkins container so it drives
the host daemon — and, deliberately, write the failure mode into `docs/07-…md`'s "Common pitfalls":
what it looks like when it's wrong, and why we rejected the DinD sidecar alternative. A planned
pitfall is a lesson; an unplanned one is a support ticket.

### 7. One stretch exercise per chapter
Each doc carries exactly one "beyond the demo" task so fast students keep moving without derailing the
main track. Examples: ch.2 — make the smoke test fail on a real DB connection error; ch.9 — make
`/ready` actually query the DB, not just return 200; ch.11 — add a CPU panel to the Grafana dashboard;
ch.13 — re-run the incident drill using *only* SigNoz logs (no trace view); ch.15 — add a second
"service" (a fake rate-limiter) and wire it into the same pipeline.

### 8. Secret-scan pre-commit hook — lands ch.5, CI-gated ch.7+
Tied to ch.5's "secrets start living in env" story: `.pre-commit-config.yaml` (plus a `make scan`
target) runs a lightweight scanner over the repo — `gitleaks` if available, else a regex for
`password=`, `sk-…`, and AWS `AKIA…` key patterns. It's also a CI check in ch.7, so a leaked secret is
caught before it's committed *or* shipped. Kept deliberately minimal — the point is the habit, not the tool.

### 9. A mermaid architecture diagram that evolves per chapter — lands ch.0, updated ch.4–13
The README carries one canonical mermaid diagram of the system. It starts in ch.0 as a single box
("one app, running locally"); each chapter doc from ch.4 onward shows that *same* diagram **as of that
chapter**, so students watch the architecture grow to "app + db + CI + observability." Ch.13 shows the
three-tool trio collapsed into SigNoz; ch.15 finalizes it. One diagram, many snapshots.

### 10. Per-chapter classroom demo checklist — part of the doc template (#1)
So this teaches a *room*, not just a solo learner, every doc's checklist splits "show live" (fast,
satisfying, low-risk) from "screenshot / pre-record" (slow or flaky). E.g. ch.12: *live* = kill the DB
container + watch the alert fire; *pre-record* = scrolling the full trace waterfall. Each checklist
doubles as the teacher's run-of-show.

## Branching model
```
main ── 01-fastapi ── 02-sqlite ── 03-jinja ── 04-docker
   ── 05-compose ── 06-logging ── 07-jenkins-ci ── 08-jenkins-cd
   ── 09-health ── 10-otel-tracing ── 11-otel-metrics ── 12-jaeger
   ── 13-signoz ── 14-testing ── 15-recap
```
Each branch: work → commit → (teach) → merge to `main` → cut next branch.
In practice for this repo we'll keep all branches alive side-by-side (no merges) so each student
can check out any single concept in isolation; `main` is just ch.0 + ch.15's final state.

## Repo layout (final)
```
devops_course/
├── PLAN.md                      # this file
├── README.md                    # ch.0 intro + ch.15 full walkthrough
├── notes_app/                   # the app, as a package (not loose root files)
│   ├── __init__.py              # package marker + layout note
│   ├── main.py                  # app instance: mounts routers + templates/static
│   ├── models.py                # data layer: in-memory → SQLite → Postgres
│   ├── views.py                 # controller layer: JSON API + HTML routes
│   ├── otel.py                  # instrumentation (ch.10+)
│   └── logging_config.py        # structured logging (ch.6)
├── templates/                   # Jinja2 UI, one file per page (ch.3+)
├── static/                      # CSS/JS (ch.3+)
├── tests/                       # placeholder test ch.1, smoke test ch.2, full suite ch.14
├── pyproject.toml + uv.lock    # uv-managed deps (ch.1)
├── Makefile                    # run/test/up/down targets, wraps uv + docker (ch.1, polished ch.15)
├── Dockerfile                   # uv-based build (ch.4)
├── .dockerignore
├── docker-compose.yml           # app + postgres (+ prometheus/grafana/jaeger in later chs)
├── Jenkinsfile
├── docker/jenkins-compose.yml   # Jenkins itself, run via a compose profile
├── grafana/dashboards/         # starter dashboard JSON + SLO alert (ch.11)
├── signoz/                     # SigNoz config (alert yaml, dashboard) (ch.13)
├── scripts/deploy.sh           # CD deploy (ch.8)
└── docs/                       # one .md per chapter, the teaching material
```

## What we build first
Start with **ch.0** (this repo + README) then **ch.1** (`01-fastapi` branch: the bare FastAPI app).
Confirm the plan, and I'll create the branch and the code for it.

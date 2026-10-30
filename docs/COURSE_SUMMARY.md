# DevOps Journey: 12-Chapter Architecture & Technology Blueprint

> **Executive Summary & Technical Reference**  
> *From a bare Python script on localhost to Cloud Infrastructure, GitOps, CI/CD, APM Observability, and Automated Fleet Configuration.*

---

<div style="page-break-after: always;"></div>

# 1. The Big Picture: Journey & Global Architecture

## 1.1 The 12-Chapter DevOps Maturity Curve

```mermaid
flowchart LR
    subgraph P1["Phase 1: Codebase & Architecture"]
        direction TB
        C1["01: FastAPI + uv + ruff<br/><i>Reproducible Dev Loop</i>"]
        C2["02: SQLite + SQLAlchemy<br/><i>Data Persistence & Layering</i>"]
        C3["03: Jinja2 UI + REST API<br/><i>Dual Consumer MVC</i>"]
        C1 --> C2 --> C3
    end

    subgraph P2["Phase 2: Packaging & 12-Factor"]
        direction TB
        C4["04: Docker Multistage<br/><i>OCI Containerization</i>"]
        C5["05: Compose + Postgres<br/><i>Multi-Service & Secrets</i>"]
        C6["06: Structured Logging<br/><i>JSON Streams on stdout</i>"]
        C4 --> C5 --> C6
    end

    subgraph P3["Phase 3: CI/CD Pipeline Automation"]
        direction TB
        C7["07: Jenkins CI (in Docker)<br/><i>Parallel Lint / Format / Test</i>"]
        C8["08: Jenkins CD to Server<br/><i>Artifact Promotion & Rollback</i>"]
        C7 --> C8
    end

    subgraph P4["Phase 4: SRE & Full-Stack APM"]
        direction TB
        C9["09: Health Probes + OTel<br/><i>Liveness, Readiness, W3C</i>"]
        C10["10: SigNoz APM Stack<br/><i>ClickHouse, Spans & DB Drill</i>"]
        C9 --> C10
    end

    subgraph P5["Phase 5: Cloud IaC & CaC Fleet"]
        direction TB
        C11["11: Terraform + Azure + Rover<br/><i>Declarative Cloud VM & Net</i>"]
        C12["12: Ansible + Semaphore UI<br/><i>Idempotent Host Provisioning</i>"]
        C11 --> C12
    end

    P1 ==> P2 ==> P3 ==> P4 ==> P5
```

### Phase-by-Phase Evolution Overview

| Phase | Chapters | Focus Domain | Key Technologies | Outcome |
|:---|:---:|:---|:---|:---|
| **1. Application Foundation** | 01 – 03 | Code Hygiene & Persistence | FastAPI, uv, Ruff, SQLite, Jinja2 | Clean MVC app, fast dev loops, dual SSR/API outputs |
| **2. Containerization** | 04 – 06 | Portability & 12-Factor | Docker, Compose, Postgres, JSON Logs | Zero-host-drift OCI images, multi-container networking |
| **3. Pipeline Automation** | 07 – 08 | Automated Quality & Delivery | Jenkins LTS, Docker-in-Docker, SSH/SCP | Automated verification gates & zero-downtime releases |
| **4. Enterprise Observability** | 09 – 10 | Reliability & Root Cause | OpenTelemetry, SigNoz, ClickHouse | Distributed tracing waterfalls, SLO alerts & outage drills |
| **5. Cloud & Configuration** | 11 – 12 | IaC & Fleet Configuration | Terraform, Azure Cloud, Ansible, Semaphore | 1-click cloud provisioning and automated Docker host setups |

---

<div style="page-break-after: always;"></div>

## 1.2 Master System Architecture (End-to-End)

```mermaid
flowchart TD
    subgraph DevStation["Developer Workstation / CI Agent"]
        Dev["Developer"]
        Make["GNU Makefile<br/><i>Unified Interface</i>"]
        Dev -->|"make check / test / up"| Make
    end

    subgraph VersionControl["Source Control & Registry"]
        GitRepo["Git Repository<br/>(GitHub / Local)"]
        DockerHub["Docker Hub / Registry<br/>notes-app:SHA"]
    end

    subgraph CI_Stack["CI/CD Automation (jenkins/docker-compose.yml)"]
        Jenkins["Jenkins Server :8080<br/>(Docker-in-Docker)"]
        JenkinsPipeline["Declarative Pipeline<br/>1. Lint (ruff)<br/>2. Test (pytest)<br/>3. Build Image<br/>4. Push Registry<br/>5. Trigger CD"]
        Jenkins --> JenkinsPipeline
    end

    subgraph LocalStack["App Runtime (docker-compose.yml)"]
        App["FastAPI Notes App :8000<br/>• Health & Readiness Probes<br/>• OTel Auto-Instrumentation<br/>• Structured JSON Logging"]
        DB[("PostgreSQL 16 :5432<br/>Named Volume: pgdata")]
        App -->|"SQLAlchemy ORM"| DB
    end

    subgraph ObservabilityStack["Full-Stack APM (signoz profile / compose)"]
        OTEL["SigNoz Ingester :4317/:4318<br/>(OTel Collector gRPC/HTTP)"]
        CH[("ClickHouse DB<br/>Spans, Metrics, Logs")]
        SigUI["SigNoz Web UI :8080<br/>Dashboards, Traces, SLOs"]
        
        App -->|"OTLP gRPC Spans"| OTEL
        OTEL --> CH
        SigUI --> CH
    end

    subgraph CloudInfra["Microsoft Azure Cloud (IaC via Terraform)"]
        subgraph Net["Virtual Network 10.0.0.0/16"]
            Subnet["Subnet 10.0.1.0/24"]
            NSG["NSG Rules: 22, 80, 443, 8000"]
            VM["server2 (Ubuntu 22.04 LTS)<br/>Public IP: 20.198.82.108"]
            Subnet --- NSG --- VM
        end
    end

    subgraph CaC["Configuration as Code (ansible/docker-compose.yml)"]
        Semaphore["Ansible Semaphore UI :3000"]
        AnsibleCLI["Ansible Core Runner<br/>setup-docker.yml"]
        Semaphore -->|"Executes"| AnsibleCLI
    end

    %% Connections
    Make --> LocalStack
    Make --> CI_Stack
    Make --> ObservabilityStack
    Make -->|"make tf-apply"| CloudInfra
    Make -->|"make ansible-setup"| CaC

    GitRepo -->|"Poll SCM / Webhook"| Jenkins
    JenkinsPipeline -->|"Push Artifact"| DockerHub
    JenkinsPipeline -->|"Deploy Artifact via SSH"| VM
    DockerHub -.->|"docker pull"| VM

    AnsibleCLI -->|"SSH + Keys (Idempotent Setup)"| VM
```

---

<div style="page-break-after: always;"></div>

## 1.3 Master Service & Port Directory

| Service | Environment / Chapter | Container Name | Published Port | Internal Role |
|:---|:---:|:---|:---:|:---|
| **Notes App** | Local / Ch. 1–6, 9 | `notes-app` | `8000:8000` | FastAPI Web UI & REST API |
| **PostgreSQL** | Local / Ch. 5–6, 9–10 | `postgres` | `5432:5432` | Relational application database |
| **Jenkins Master** | Local CI / Ch. 7–8 | `course-jenkins` | `8080:8080` | Continuous Integration / Deployment engine |
| **Jenkins Agent** | Local CI / Ch. 7–8 | Dynamic DinD | `50000:50000` | JNLP agent communication port |
| **SigNoz Ingester** | Observability / Ch. 10 | `signoz-ingester` | `4317:4317` / `4318:4318` | OTLP gRPC and HTTP telemetry intake |
| **SigNoz UI** | Observability / Ch. 10 | `signoz-frontend` | `8080:8080` / `3301` | APM dashboards, traces & alerting portal |
| **Rover Visualizer** | IaC / Ch. 11 | `rover` | `9000:9000` | Terraform interactive graph dashboard |
| **Semaphore Web UI** | CaC / Ch. 12 | `semaphore` | `3000:3000` | Ansible playbooks & project management |
| **Azure VM (`server2`)**| Cloud Target / Ch. 11–12 | Bare Metal VM | `22`, `8000` | Production Ubuntu 22.04 LTS host |

---

## 1.4 The "Zero Host Dependencies" Dockerized Toolchain

Every single piece of operations infrastructure in this course runs inside Docker containers:

```mermaid
flowchart LR
    Host["Host Machine<br/><i>Only needs Docker + Git + uv</i>"]
    
    subgraph ContainerizedTools["100% Docker-Encapsulated Toolchains"]
        T_Jenkins["Jenkins CI/CD<br/><code>jenkins/docker-compose.yml</code>"]
        T_SigNoz["SigNoz APM & ClickHouse<br/><code>signoz profile</code>"]
        T_Terraform["Terraform & AzureRM<br/><code>terraform/docker-compose.yml</code>"]
        T_Rover["Rover Graph Visualizer<br/><code>terraform/docker-compose.yml</code>"]
        T_Ansible["Ansible Core Runner<br/><code>ansible/docker-compose.yml</code>"]
        T_Semaphore["Semaphore Web UI<br/><code>ansible/docker-compose.yml</code>"]
    end
    
    Host ==> ContainerizedTools
```

---

<div style="page-break-after: always;"></div>

# 2. Chapter-by-Chapter Visual Dossiers

---

## Chapter 01: FastAPI Foundation & Developer Tooling

> **Milestone**: Establish standard developer ergonomics, sub-second linting, lockfile pinning, and a clean MVC skeleton.

### Problem vs. Solution

| Challenge / Anti-pattern | Solution Introduced | Real-World Impact |
|:---|:---|:---|
| Divergent Python versions and broken `pip install` environments | **Astral `uv`** (`pyproject.toml` + `uv.lock`) | Byte-for-byte reproducible virtual environment in < 100ms |
| Slow, conflicting linters (`flake8`, `black`, `isort`) | **Ruff** single-binary tool | Sub-millisecond formatting and linting in one pass |
| Tangled, unmaintainable single-file scripts | **MVC-Lite separation** (`main.py`, `models.py`, `views.py`) | Route controllers never know where or how data is stored |
| Tribal knowledge for local commands | **GNU `Makefile`** abstraction | Every engineer runs identical `make run`, `make test`, `make lint` |

### Architecture & Request Flow

```mermaid
flowchart LR
    Client["Client / Browser"]
    Make["Makefile (make run)"]
    Uv["uv run uvicorn"]
    
    subgraph AppArchitecture["notes_app/ Package (MVC-Lite)"]
        Main["main.py<br/><i>App factory & middleware</i>"]
        Views["views.py<br/><i>HTTP route controllers</i>"]
        Models["models.py<br/><i>In-memory Dict storage</i>"]
        
        Main --> Views
        Views --> Models
    end

    Client -->|"HTTP GET/POST /notes"| Main
    Make --> Uv --> Main
```

### Technical Specs & Use Case

* **Primary Tech**: Python 3.12, FastAPI, Uvicorn, Astral uv, Ruff, GNU Make.
* **Key Commands**: `make run` (dev server), `make test` (pytest), `make lint` (ruff check), `make lint-fix` (auto-format).
* **Industry Use Case**: Standardizing software engineering teams on a unified command surface so onboarding a new developer takes under 60 seconds without environment debugging.

---

<div style="page-break-after: always;"></div>

## Chapter 02: Durable Storage with SQLite & SQLAlchemy

> **Milestone**: Transition from volatile memory to durable ACID storage without altering a single line of HTTP routing logic.

### Problem vs. Solution

| Challenge / Anti-pattern | Solution Introduced | Real-World Impact |
|:---|:---|:---|
| Data vanishes every time application process restarts | **SQLite 3 file storage** (`notes.db`) | Data persists indefinitely across process restarts |
| Heavy database servers (Postgres/MySQL) required for local dev | **Embedded SQLite file** | Zero background daemons, zero network ports, zero setup |
| Fragile raw SQL queries with injection risks | **SQLAlchemy 2.0 ORM** (`NoteRow`) | Clean Python objects, schema modeling, migration readiness |
| No automated test to verify persistence | **Pytest smoke test suite** (`tests/test_smoke.py`) | CI now has a real integration test to execute |

### Decoupling Architecture

```mermaid
flowchart TD
    subgraph RoutingLayer["HTTP Layer (views.py) - UNTOUCHED"]
        V_Get["GET /notes"]
        V_Post["POST /notes"]
        V_Del["DELETE /notes/{id}"]
    end

    subgraph DataLayer["Storage Layer (models.py) - SWAPPED"]
        direction LR
        OldModel["Ch. 1: In-Memory Dict<br/>❌ Lost on restart"] -.->|"Swapped with zero routing changes"| NewModel["Ch. 2: SQLAlchemy 2.0 + SQLite<br/>✅ Durable notes.db"]
    end

    subgraph Storage["Disk Persistence"]
        DBFile[("notes.db (Local File)")]
    end

    RoutingLayer ==> DataLayer
    NewModel --> DBFile
```

### Technical Specs & Use Case

* **Primary Tech**: SQLite 3, SQLAlchemy 2.0, Pytest.
* **Key Files**: `notes_app/models.py`, `tests/test_smoke.py`, `.gitignore` (`*.db`).
* **Before vs. After**: Restarting `make run` previously wiped all user notes; now notes remain intact on disk.
* **Industry Use Case**: Demonstrating software layering principles—decoupling domain business logic from the persistence implementation so underlying database engines can be swapped freely.

---

<div style="page-break-after: always;"></div>

## Chapter 03: Dual-Consumer Web Interface (Jinja2 SSR & API)

> **Milestone**: Serve server-rendered interactive HTML pages and raw JSON REST endpoints from the exact same application models.

### Problem vs. Solution

| Challenge / Anti-pattern | Solution Introduced | Real-World Impact |
|:---|:---|:---|
| Backend only returns raw JSON blobs; requires Postman to view | **Jinja2 Server-Side Rendering (SSR)** | Full interactive browser UI with CSS and JavaScript |
| Building two separate applications for UI and API | **Dual-Consumer Controller** in `views.py` | Single codebase delivers HTML to humans and JSON to machines |
| Form resubmission duplicates data on page refresh | **Post-Redirect-Get (PRG) Pattern** | Form POST returns `HTTP 303 See Other` to cleanly redirect |
| Monolithic giant HTML files | **Template inheritance** (`templates/base.html`) | Modular, clean templates (`index.html`, `new.html`, `show.html`) |

### Dual Consumer Flowchart

```mermaid
sequenceDiagram
    autonumber
    actor User as Human Browser
    actor Machine as API Client / curl
    participant App as FastAPI App (views.py)
    participant Engine as Jinja2 Engine
    participant DB as SQLite / Postgres

    Note over User, Machine: Dual Consumers querying the same endpoint
    User->>App: GET / (Browser Accept: text/html)
    App->>DB: Query all notes
    DB-->>App: Return records
    App->>Engine: Render templates/index.html
    Engine-->>User: HTTP 200 (Styled HTML Page)

    Machine->>App: GET /notes (API Client Accept: application/json)
    App->>DB: Query all notes
    DB-->>App: Return records
    App-->>Machine: HTTP 200 [{"id": 1, "title": "Buy milk"}]

    User->>App: POST /notes (Create Form Submission)
    App->>DB: Insert new Note
    App-->>User: HTTP 303 See Other (Redirect to /)
```

### Technical Specs & Use Case

* **Primary Tech**: Jinja2 Templates, HTML5, CSS3 (`static/style.css`), Vanilla JS (`static/app.js`).
* **Key Files**: `templates/base.html`, `templates/index.html`, `static/style.css`, `notes_app/views.py`.
* **Industry Use Case**: Modern full-stack monoliths (e.g., GitHub, Linear, Basecamp) serving hyper-responsive web interfaces while natively offering public developer APIs from identical models.

---

<div style="page-break-after: always;"></div>

## Chapter 04: Dockerize the App & Reproducible Builds

> **Milestone**: Eliminate "it works on my machine" forever by packaging OS, Python runtime, lockfile dependencies, and code into an immutable OCI container image.

### Problem vs. Solution

| Challenge / Anti-pattern | Solution Introduced | Real-World Impact |
|:---|:---|:---|
| Environmental drift between developer laptops and production servers | **OCI Docker Container** | Identical execution environment across all operating systems |
| Bloated, slow image builds re-downloading packages repeatedly | **uv cache mounts in Dockerfile** | Layer caching makes rebuilds execute in under 2 seconds |
| Leaking local files (`.venv`, `notes.db`, `.git`) into images | Strict **`.dockerignore` rules** | Clean, minimal, secure images with zero secret leakage |
| Running root processes inside containers | **Non-root application user** | Adheres to container security best practices |

### Container Build & Layer Caching

```mermaid
flowchart TD
    subgraph Host["Host Workspace"]
        PyProject["pyproject.toml + uv.lock"]
        Src["notes_app/ + templates/ + static/"]
        Ign[".dockerignore (filters .git, .env, *.db)"]
    end

    subgraph DockerBuild["Dockerfile (uv-powered multi-stage)"]
        Base["Base Layer: python:3.12-slim"]
        UVInstall["Install Astral uv binary"]
        DepLayer["Cache Mount: --mount=type=cache,target=/root/.cache/uv<br/>RUN uv sync --frozen (Locked Packages)"]
        CodeLayer["COPY Source Code & Templates"]
        UserLayer["USER appuser (Security Hardening)"]
        
        Base --> UVInstall --> DepLayer --> CodeLayer --> UserLayer
    end

    subgraph Artifact["OCI Image Output"]
        Img["notes-app:latest<br/><i>Immutable, portable, deterministic</i>"]
    end

    Host --> DockerBuild --> Artifact
```

### Technical Specs & Use Case

* **Primary Tech**: Docker Engine, BuildKit, Multi-stage caching, `.dockerignore`.
* **Key Commands**: `make build` (builds `notes-app`), `make run-docker` (starts container on `8000:8000`).
* **Industry Use Case**: Producing standardized, portable deployment units ready to run identically on local laptops, staging clusters, Kubernetes pods, or cloud VMs.

---

<div style="page-break-after: always;"></div>

## Chapter 05: Multi-Container Orchestration & Secrets

> **Milestone**: Move to a production-grade PostgreSQL database, isolate secrets via environment files, and orchestrate multi-container networks using Docker Compose.

### Problem vs. Solution

| Challenge / Anti-pattern | Solution Introduced | Real-World Impact |
|:---|:---|:---|
| SQLite file locked inside container cannot handle enterprise scale | **PostgreSQL 16 Alpine container** | High-concurrency relational DB with ACID guarantees |
| Database data erased when container is recreated | **Docker named volume** (`postgres_data`) | Data survives container restarts and upgrades |
| Hardcoded database credentials in source code | **`.env` and `.env.example`** configuration | 12-Factor compliance; zero credentials committed to Git |
| App crashes on startup because database is still booting | **Healthchecks + `condition: service_healthy`** | Deterministic startup ordering with zero race conditions |
| Single compose file starting everything whether needed or not | **Compose Profiles** (`core`, `db-only`) | Start only what you need: `make up` vs `make up-db` |

### Multi-Service Topology

```mermaid
flowchart TD
    subgraph HostEnv["Host Environment"]
        EnvFile[".env (DATABASE_URL, POSTGRES_PASSWORD)"]
        Makefile["Makefile (make up / make down / make reset-db)"]
    end

    subgraph ComposeNetwork["Docker Bridge Network: devops_course_default"]
        subgraph AppService["Service: app (Profile: core)"]
            AppCont["notes-app Container :8000<br/>• Healthcheck: curl -f /ready<br/>• Reads env from .env"]
        end

        subgraph DBService["Service: postgres (Profile: core)"]
            PGCont["postgres:16-alpine Container :5432<br/>• Healthcheck: pg_isready<br/>• Persistent Storage"]
        end

        AppCont -->|"DNS: postgres:5432"| PGCont
    end

    subgraph Storage["Persistent Host Storage"]
        PGVol[("Docker Volume: postgres_data<br/>/var/lib/postgresql/data")]
    end

    PGCont --- PGVol
    EnvFile -.-> AppService
    EnvFile -.-> DBService
    Makefile --> ComposeNetwork
```

### Technical Specs & Use Case

* **Primary Tech**: Docker Compose v2, PostgreSQL 16 Alpine, Docker Volumes, Healthchecks.
* **Key Commands**: `make up` (starts app + db), `make down` (stops containers), `make reset-db` (wipes volume & re-initializes).
* **Industry Use Case**: Standardizing microservice stacks so all dependent services (databases, caches, queues) spin up with a single command with proper dependencies and persistent storage.

---

<div style="page-break-after: always;"></div>

## Chapter 06: Centralized Structured JSON Logging

> **Milestone**: Replace chaotic human-readable print statements with machine-parseable JSON streams on standard output adhering to 12-Factor principles.

### Problem vs. Solution

| Challenge / Anti-pattern | Solution Introduced | Real-World Impact |
|:---|:---|:---|
| Multi-line console logs cannot be filtered or parsed by SIEM tools | **Structured JSON logging** on `stdout` | Instantly indexable by Datadog, ELK, Fluentbit, and SigNoz |
| Missing contextual metadata (HTTP status, duration, client IP) | **Injected JSON fields** on every request | Full request lifecycle visible in a single log object |
| Writing logs to local files inside containers that fill up disk | **12-Factor App Factor XI** (Streams) | Containers write to stdout/stderr; log collectors ship events |
| No way to trace requests across microservice boundaries | **`request_id` correlation** in log payload | Track single user transactions across all log records |

### Log Ingestion Pipeline

```mermaid
flowchart LR
    subgraph RequestCycle["FastAPI Request Middleware"]
        Req["HTTP Request In"] --> StartTimer["Record Start Time"]
        StartTimer --> Handler["Process Route"]
        Handler --> LogGen["Structured Log Generator"]
    end

    subgraph LogStream["Standard Output Stream (stdout)"]
        JSONStr["{<br/>  'timestamp': '2026-10-30T14:32:01Z',<br/>  'level': 'INFO',<br/>  'event': 'http_request',<br/>  'method': 'POST',<br/>  'path': '/notes',<br/>  'status_code': 201,<br/>  'duration_ms': 12.4,<br/>  'request_id': 'req_98a7f1'<br/>  'trace_id': '4bf92f3577b34da6a3ce929d0e0e4736'<br/>}"]
    end

    subgraph LogCollector["Log Collector / Aggregator (SigNoz / ELK)"]
        DockerLogDriver["Docker JSON-File Driver"]
        Aggregator["Log Indexer & Filter Engine"]
        Dashboards["Log Query UI & Anomaly Alerts"]
    end

    LogGen --> JSONStr
    JSONStr --> DockerLogDriver --> Aggregator --> Dashboards
```

### Technical Specs & Use Case

* **Primary Tech**: Python `logging`, JSON formatter, Docker logging driver, 12-Factor Factor XI.
* **Key Commands**: `make logs` (tails live formatted JSON logs from the running app container).
* **Industry Use Case**: Enterprise observability readiness—ensuring thousands of microservice instances stream uniform, queryable logs for automated alerting, auditing, and debugging.

---

<div style="page-break-after: always;"></div>

## Chapter 07: Containerized Jenkins CI Pipeline

> **Milestone**: Implement a fully automated Continuous Integration pipeline executing linting, formatting, and unit tests in parallel on an isolated Jenkins server.

### Problem vs. Solution

| Challenge / Anti-pattern | Solution Introduced | Real-World Impact |
|:---|:---|:---|
| Developers forget to run tests before committing code | **Automated Jenkins CI Pipeline** | Every commit automatically tested on an independent CI runner |
| "It works on CI but fails locally" due to different CI agents | **Docker-in-Docker CI execution** | CI runs the exact same `Makefile` and Docker commands as developers |
| Sequential CI builds take too long to provide feedback | **Parallel pipeline stages** | Lint, format, and unit tests run concurrently |
| Installing Jenkins directly on host pollutes local environment | **Containerized Jenkins LTS** (`jenkins/`) | Zero host installation; spins up and tears down cleanly |

### Jenkins CI Parallel Pipeline Flow

```mermaid
flowchart TD
    Commit["Git Commit / Push"] --> Trigger["Jenkins Pipeline Trigger<br/>(Poll SCM or Webhook)"]
    
    subgraph Pipeline["Jenkinsfile Declarative Pipeline (Docker Agent)"]
        Checkout["Stage: Checkout SCM"]
        
        subgraph ParallelChecks["Parallel Verification Gate"]
            Lint["Stage: Lint<br/><code>ruff check</code>"]
            Format["Stage: Format Check<br/><code>ruff format --check</code>"]
            Test["Stage: Unit & Smoke Tests<br/><code>pytest tests/</code>"]
        end
        
        SecretScan["Stage: Secret Scan<br/><code>scripts/scan-secrets.sh</code>"]
        ArtifactBuild["Stage: Build OCI Image<br/><code>docker build -t notes-app:${BUILD_TAG}</code>"]
        
        Checkout --> ParallelChecks
        ParallelChecks --> SecretScan
        SecretScan --> ArtifactBuild
    end
    
    ArtifactBuild --> Pass["✅ Build Passed: Artifact Ready for Delivery"]
    ParallelChecks -.->|"Any Failure"| Fail["❌ Build Failed: Merge Blocked"]
```

### Technical Specs & Use Case

* **Primary Tech**: Jenkins LTS, Docker-in-Docker (`/var/run/docker.sock`), Jenkins Declarative Pipeline, Blue Ocean.
* **Key Commands**: `make pipeline` (boots Jenkins on `:8080`), `make down-pipeline`, `make reset-pipeline`.
* **Industry Use Case**: Automated quality gates preventing regressions, syntax errors, and broken dependencies from ever reaching mainline branches.

---

<div style="page-break-after: always;"></div>

## Chapter 08: Continuous Delivery & Automated Rollbacks

> **Milestone**: Bridge CI to CD by automating the delivery of immutable container artifacts to a remote production VPS with automated health validation and instant rollbacks.

### Problem vs. Solution

| Challenge / Anti-pattern | Solution Introduced | Real-World Impact |
|:---|:---|:---|
| Building images directly on production servers | **Immutable Artifact Promotion** | Production pulls tested, tagged Docker images from registry |
| Manual SSH deployments with human error | **Automated CD Script** (`server/deploy.sh`) | Single scripted deployment triggered by Jenkins or Makefile |
| Bad deployments cause prolonged production outages | **Automated `/ready` gate & rollback** | If probe fails, the previous working container is restored immediately |
| Exposing unconfigured staging servers | **Environment-driven deployment** | Server configuration cleanly separated from application artifact |

### Deployment & Rollback Sequence

```mermaid
sequenceDiagram
    autonumber
    participant CD as Jenkins CD / deploy.sh
    participant Reg as Docker Registry / Hub
    participant Host as Remote Production Server
    participant OldApp as Running Container (v1.0)
    participant NewApp as New Container (v1.1)

    CD->>Reg: Verify image notes-app:v1.1 exists
    CD->>Host: SSH execute deployment script
    Host->>Reg: docker pull notes-app:v1.1
    Host->>OldApp: docker stop notes-app (Keep standby)
    Host->>NewApp: docker run --name notes-app-new -p 8000:8000 notes-app:v1.1
    
    loop Health Verification (5 Retries)
        Host->>NewApp: curl -f http://127.0.0.1:8000/ready
    end

    alt NewApp answers HTTP 200 OK
        Host->>OldApp: docker rm notes-app (Decommission old version)
        Host->>NewApp: Rename notes-app-new -> notes-app
        Host-->>CD: ✅ Deployment Succeeded (Zero Downtime)
    else Healthcheck Fails / Times out
        Host->>NewApp: docker rm -f notes-app-new
        Host->>OldApp: docker start notes-app (Instant Rollback)
        Host-->>CD: ❌ Health Check Failed -> Rolled back to v1.0
    end
```

### Technical Specs & Use Case

* **Primary Tech**: SSH/SCP automation, Docker Registry, Bash defensive scripting, Health-gated rollbacks.
* **Key Commands**: `make deploy TAG=notes-app:sha-1234`, `make ssh-server`.
* **Industry Use Case**: Zero-touch production deployments allowing engineering teams to ship updates dozens of times per day with automatic safety nets.

---

<div style="page-break-after: always;"></div>

## Chapter 09: Health Probes & OpenTelemetry Foundation

> **Milestone**: Establish Kubernetes-ready liveness vs. readiness separation and instrument the application with OpenTelemetry distributed trace context.

### Problem vs. Solution

| Challenge / Anti-pattern | Solution Introduced | Real-World Impact |
|:---|:---|:---|
| A single `/health` check that cannot distinguish app crash from DB downtime | **Separate `/health` & `/ready` probes** | Orchestrator knows whether to restart container or stop routing traffic |
| No visibility into latency bottlenecks across database queries | **OpenTelemetry SDK auto-instrumentation** | Every HTTP route and SQL query creates a timed distributed span |
| Disconnected logs and traces during incident investigations | **W3C `traceparent` context injection** | `trace_id` automatically stamped onto application logs |
| Vendor lock-in to proprietary monitoring agents (Datadog/NewRelic) | **OpenTelemetry standard (OTel)** | Open industry standard telemetry streamable to any backend |

### Liveness vs. Readiness Probe Logic

```mermaid
flowchart TD
    subgraph Probes["Orchestrator Probes"]
        LivenessProbe["Liveness Probe: GET /health<br/><i>'Is the Python process running?'</i>"]
        ReadinessProbe["Readiness Probe: GET /ready<br/><i>'Can the app serve user traffic?'</i>"]
    end

    subgraph Evaluation["Endpoint Logic (main.py)"]
        EvalLiveness{"Process responding?"}
        EvalReadiness{"Test DB Connection:<br/>SELECT 1"}
    end

    subgraph Actions["Orchestrator Decision"]
        ActionRestart["❌ Restart / Kill Container"]
        ActionKeepAlive["✅ Keep Container Running"]
        ActionRoute["✅ Route User Traffic to Pod"]
        ActionDeregister["❌ Stop Routing Traffic (Wait for DB)"]
    end

    LivenessProbe --> EvalLiveness
    EvalLiveness -->|Yes| ActionKeepAlive
    EvalLiveness -->|No / Crash| ActionRestart

    ReadinessProbe --> EvalReadiness
    EvalReadiness -->|DB Connected| ActionRoute
    EvalReadiness -->|DB Down / Starting| ActionDeregister
```

### Technical Specs & Use Case

* **Primary Tech**: OpenTelemetry Python SDK, W3C Trace Context, FastAPI Middleware, SQLAlchemy Instrumentation.
* **Key Endpoints**: `http://127.0.0.1:8000/health`, `http://127.0.0.1:8000/ready`.
* **Industry Use Case**: Production readiness for Kubernetes, AWS ECS, or Azure Container Apps where traffic routing and automated self-healing require distinct probe signals.

---

<div style="page-break-after: always;"></div>

## Chapter 10: Full-Stack Observability with SigNoz & OpenTelemetry

> **Milestone**: Deploy a self-hosted full-stack APM cluster in Docker and prove root-cause identification within seconds via a live database-outage drill.

### Problem vs. Solution

| Challenge / Anti-pattern | Solution Introduced | Real-World Impact |
|:---|:---|:---|
| Traces dumped as text to stdout cannot be visualized or aggregated | **SigNoz APM Stack** (Collector + ClickHouse + UI) | Visual trace waterfalls, latency percentiles (p50/p95/p99) |
| Running separate siloed tools for logs, metrics, and traces | **Unified 3-in-1 APM platform** | Correlate a slow database query directly with its trace and log line |
| Observability is only theoretical; never tested under failure | **Live Incident Drill** (`docker compose stop postgres`) | Watch `/ready` flip to 503, error rate spike to 100%, and SLO alarm fire |
| Expensive SaaS bills for cloud monitoring platforms | **Self-hosted Open-Source APM** | Full telemetry stack running on-premise or inside private cloud |

---

### 10.1 Complete SigNoz Docker Compose Microservice Architecture

The SigNoz stack running via `signoz/compose.yaml` is composed of 7 specialized containers coordinated across a dedicated bridge network (`signoz-network`):

```mermaid
flowchart TD
    subgraph ClientLayer["Application Layer (notes-app)"]
        App["notes-app (:8000)<br/>• FastAPIInstrumentor<br/>• SQLAlchemyInstrumentor<br/>• OTLP gRPC Exporter"]
    end

    subgraph OTelIngestion["Telemetry Intake & Processing"]
        Ingester["ingester (:4317 / :4318)<br/><i>signoz-otel-collector</i><br/>Receives OTLP, parses, batches"]
        Migrator["signoz-telemetrystore-migrator<br/><i>(One-shot migration container)</i><br/>Creates ClickHouse tables & schema"]
    end

    subgraph StorageCluster["Telemetry Storage Engine (ClickHouse OLAP)"]
        Keeper["signoz-telemetrykeeper-clickhousekeeper-0 (:9181)<br/><i>Raft consensus & coordination</i>"]
        Scripts["signoz-telemetrystore-clickhouse-user-scripts<br/><i>(One-shot installer)</i><br/>Installs histogramQuantile binary"]
        CH[("signoz-telemetrystore-clickhouse-0-0 (:9000 / :8123)<br/><i>Columnar OLAP Storage</i><br/>• signoz_traces<br/>• signoz_logs<br/>• signoz_metrics")]
    end

    subgraph AppStateStore["SigNoz Metadata Storage (PostgreSQL ACID)"]
        PGMeta[("signoz-metastore-postgres-0 (:5432)<br/><i>PostgreSQL 16 Relational Store</i><br/>• Users & Orgs<br/>• Dashboards & Panels<br/>• Alert Rules & Notifications")]
    end

    subgraph UserInterface["Query Engine & Visualization Portal"]
        SigUI["signoz-signoz-0 (:8080)<br/><i>Frontend UI + Query Engine</i><br/>• Trace waterfall graphs<br/>• Flamegraphs & APM views<br/>• Query aggregation"]
    end

    %% Network links & dependencies
    App -->|"OTLP gRPC :4317"| Ingester
    Migrator -.->|"Bootstraps Schema"| CH
    Keeper ---|"Raft Sync :9181"| CH
    Scripts -.->|"Mounts Binary"| CH
    Ingester -->|"TCP :9000 Bulk Write"| CH

    SigUI -->|"TCP :9000 Query Telemetry"| CH
    SigUI -->|"TCP :5432 Read/Write Metadata"| PGMeta
```

---

<div style="page-break-after: always;"></div>

### 10.2 OpenTelemetry Collector (`ingester`) Internal Pipeline

The `ingester` container runs the SigNoz OpenTelemetry Collector distribution with a multi-stage pipeline defined in `signoz/ingester/ingester.yaml`:

```mermaid
flowchart LR
    subgraph Receivers["1. Receivers (Entrypoint)"]
        direction TB
        R_gRPC["OTLP gRPC (:4317)<br/>Traces, Metrics, Logs"]
        R_HTTP["OTLP HTTP (:4318)<br/>JSON & Protobuf"]
    end

    subgraph Processors["2. Processors (Transform & Aggregate)"]
        direction TB
        P_SpanMetrics["signozspanmetrics/delta<br/><i>Calculates latency buckets & rates</i>"]
        P_SpanMapper["signozspanmapper<br/><i>Maps tags & exceptions</i>"]
        P_Pricing["signozllmpricing<br/><i>Token cost tracker</i>"]
        P_Batch["batch processor<br/><i>Max 50,000 items / 5s timeout</i>"]
        
        P_SpanMetrics --> P_SpanMapper --> P_Pricing --> P_Batch
    end

    subgraph Exporters["3. Exporters (ClickHouse Writers)"]
        direction TB
        E_Traces["clickhousetraces<br/>-> signoz_traces"]
        E_Logs["clickhouselogsexporter<br/>-> signoz_logs"]
        E_Metrics["signozclickhousemetrics<br/>-> signoz_metrics"]
        E_Meta["metadataexporter<br/>-> signoz_metadata"]
    end

    subgraph Destination["4. ClickHouse OLAP DB"]
        CH_DB[("ClickHouse TCP :9000")]
    end

    R_gRPC --> P_SpanMetrics
    R_HTTP --> P_SpanMetrics
    P_Batch --> E_Traces
    P_Batch --> E_Logs
    P_Batch --> E_Metrics
    P_Batch --> E_Meta
    E_Traces --> CH_DB
    E_Logs --> CH_DB
    E_Metrics --> CH_DB
    E_Meta --> CH_DB
```

---

### 10.3 Application-Side OpenTelemetry Instrumentation Architecture

Inside `notes_app/otel.py`, the Python runtime is instrumented with zero changes to business routes:

```mermaid
flowchart TD
    subgraph Inbound["Incoming HTTP Traffic"]
        Req["HTTP GET/POST /notes"]
    end

    subgraph AppInstrumentation["notes_app Runtime (FastAPI + OTel)"]
        direction TB
        MW["FastAPIInstrumentor Middleware<br/><i>Generates Server Span + W3C traceparent</i>"]
        Controller["views.py Handler"]
        SQLMW["SQLAlchemyInstrumentor<br/><i>Generates Child DB Client Span</i>"]
        Meters["MeterProvider Middleware<br/><i>http_requests_total & http_request_duration_seconds</i>"]
        Logger["LoggingHandler (Python logging)<br/><i>Injects trace_id into JSON log lines</i>"]
        
        MW --> Controller
        Controller --> SQLMW
        Controller --> Meters
        Controller --> Logger
    end

    subgraph Exporters["OpenTelemetry SDK Batch Processors"]
        SpanBatch["BatchSpanProcessor<br/>(OTLPSpanExporter)"]
        MetricReader["PeriodicExportingMetricReader<br/>(2000ms flush interval)"]
        LogBatch["BatchLogRecordProcessor<br/>(OTLPLogExporter)"]
        
        MW -.-> SpanBatch
        SQLMW -.-> SpanBatch
        Meters -.-> MetricReader
        Logger -.-> LogBatch
    end

    subgraph Transport["OTLP Transport Layer"]
        gRPC["gRPC Channel :4317<br/><code>http://signoz:4317</code>"]
    end

    Req --> MW
    SpanBatch --> gRPC
    MetricReader --> gRPC
    LogBatch --> gRPC
```

---

<div style="page-break-after: always;"></div>

### 10.4 SigNoz Service & Container Catalog

| Service / Container | Base Docker Image | Network & Ports | Lifecycle | Data Role & Responsibilities |
|:---|:---|:---:|:---:|:---|
| **`ingester`** | `signoz/signoz-otel-collector:latest` | `signoz-network`<br/>`4317` (gRPC), `4318` (HTTP) | Daemon | High-throughput OTel telemetry intake. Processes spans, generates span-metrics, batches writes to ClickHouse. |
| **`signoz-telemetrystore-migrator`** | `signoz/signoz-otel-collector:latest` | `signoz-network` | One-shot Job | Executes ClickHouse DDL migrations (`migrate bootstrap && sync up`). Creates databases, tables, and materialized views. |
| **`signoz-telemetrystore-clickhouse-user-scripts`** | `clickhouse/clickhouse-server:25.12.5` | `signoz-network` | One-shot Job | Downloads and installs the custom `histogram-quantile` binary into the shared volume for p50/p90/p99 calculations. |
| **`signoz-telemetrykeeper-clickhousekeeper-0`** | `clickhouse/clickhouse-keeper:25.12.5` | `signoz-network`<br/>`9181` (Raft client) | Daemon | Raft consensus keeper (ZooKeeper replacement). Coordinates metadata, distributed locks, and mutations for ClickHouse. |
| **`signoz-telemetrystore-clickhouse-0-0`** | `clickhouse/clickhouse-server:25.12.5` | `signoz-network`<br/>`9000` (Native TCP), `8123` (HTTP) | Daemon | Columnar OLAP database. Stores compressed traces, spans, logs, and metrics for analytical querying at scale. |
| **`signoz-metastore-postgres-0`** | `postgres:16` | `signoz-network`<br/>`5432` (Internal) | Daemon | Relational PostgreSQL metadata store for user accounts, organizations, dashboard configurations, and alert rules. |
| **`signoz-signoz-0`** | `signoz/signoz:latest` | `signoz-network`<br/>`8080:8080` (Host Web UI) | Daemon | Unified UI and query engine. Queries ClickHouse for telemetry waterfalls and PostgreSQL for dashboard layouts. |

---

### 10.5 The Incident Drill: Proving Root-Cause Identification

```mermaid
sequenceDiagram
    autonumber
    actor Engineer as SRE / Engineer
    participant App as FastAPI notes-app
    participant DB as PostgreSQL (5432)
    participant Ingest as OTel Ingester (4317)
    participant CH as ClickHouse
    participant SigUI as SigNoz UI (8080)

    Engineer->>DB: Kill DB: docker compose stop postgres
    Engineer->>App: Send traffic: curl http://localhost:8000/notes
    
    Note over App, DB: Application attempts SQL query
    App-xDB: Connection Refused (PostgreSQL down)
    App->>App: Mark span status: ERROR (500)<br/>Record exception: psycopg.OperationalError
    
    App->>Ingest: Export error span via OTLP gRPC
    Ingest->>CH: Batch insert error trace
    
    Engineer->>SigUI: Open http://127.0.0.1:8080
    SigUI->>CH: Query error rate & traces
    CH-->>SigUI: Return trace with red exclamation mark
    
    SigUI-->>Engineer: Flamegraph shows root cause:<br/>• Parent span: GET /notes (500 Internal Server Error)<br/>• Child span: db.query SELECT notes (Failed: Connection Refused)
```

### Technical Specs & Use Case

* **Primary Tech**: SigNoz, OpenTelemetry Collector, ClickHouse Columnar DB, ClickHouse Keeper, PostgreSQL, OTLP gRPC/HTTP.
* **Key Commands**: `make up-signoz` (launches APM on `:8080`), `make down-signoz`, `make reset-signoz`.
* **Industry Use Case**: SRE and production support—diagnosing microsecond latency regressions and cascading downstream outages in seconds without digging through gigabytes of flat log files.

---

<div style="page-break-after: always;"></div>

## Chapter 11: Infrastructure as Code (IaC) with Terraform & Azure

> **Milestone**: Provision production cloud infrastructure (VNet, Subnet, NSG, Public IP, and Ubuntu VM `server2`) in Microsoft Azure using containerized Terraform and the Rover visualizer.

### Problem vs. Solution

| Challenge / Anti-pattern | Solution Introduced | Real-World Impact |
|:---|:---|:---|
| "ClickOps": Manually clicking in Azure/AWS portal causes configuration drift | **HashiCorp Terraform 1.9** declarative code | Infrastructure versioned in Git, auditable, and 100% reproducible |
| Engineers need local Terraform & Azure CLI tools installed on laptops | **Dockerized Terraform runner** | Zero local installs; identical toolchain version pinned for team |
| Accidental cloud bill shocks from forgotten test resources | `make tf-destroy` single-command teardown | Completely wipes all provisioned resources in reverse order |
| Terraform dependency graphs are abstract and hard to understand | **IM Cloud Rover visualizer** (`:9000`) | Interactive 3D web diagram of cloud resources and dependencies |

### Azure Cloud Topology & Rover Architecture

```mermaid
flowchart TD
    subgraph Host["Local Workstation"]
        TFDir["terraform/ Folder<br/>main.tf, variables.tf, outputs.tf"]
        DockerTF["Dockerized Terraform Runner<br/>(hashicorp/terraform:1.9.8)"]
        Rover["Rover Interactive Visualizer :9000<br/>(im2nguyen/rover)"]
        
        TFDir --> DockerTF
        DockerTF --> Rover
    end

    subgraph Azure["Microsoft Azure Cloud (Subscription)"]
        subgraph RG["Resource Group: rg-notes-devops (East US)"]
            VNet["Virtual Network: vnet-notes-devops<br/>10.0.0.0/16"]
            Subnet["Subnet: snet-notes-devops<br/>10.0.1.0/24"]
            NSG["Network Security Group: nsg-notes-devops<br/>Allow: 22, 80, 443, 8000"]
            PIP["Public IP: pip-notes-devops<br/>Dynamic Allocation"]
            NIC["NIC: nic-notes-devops<br/>Private IP: 10.0.1.4"]
            VM["Virtual Machine: server2<br/>Standard_B1s (1 vCPU, 1GB RAM)<br/>Ubuntu 22.04 LTS"]
            SSHKey["Automated RSA Keypair<br/>server_key.pem (Local file)"]
            
            VNet --- Subnet
            Subnet --- NIC
            NSG --- NIC
            PIP --- NIC
            NIC --- VM
            SSHKey -.->|"Public Key Injected"| VM
        end
    end

    DockerTF -->|"azurerm Provider API"| RG
```

### Technical Specs & Use Case

* **Primary Tech**: HashiCorp Terraform 1.9, AzureRM Provider, Azure Cloud (VM, VNet, NSG, PIP), IM Rover.
* **Key Commands**: `make tf-init`, `make tf-plan`, `make tf-apply`, `make up-rover`, `make tf-destroy`.
* **Industry Use Case**: Enterprise cloud engineering—treating infrastructure as software code, enabling peer-reviewed pull requests for cloud architecture changes, and creating disposable staging environments on demand.

---

<div style="page-break-after: always;"></div>

## Chapter 12: Configuration as Code (CaC) with Ansible & Semaphore

> **Milestone**: Transform a bare Linux cloud VM into a production Docker host using idempotent Ansible playbooks and the self-hosted Semaphore web management UI.

### Problem vs. Solution

| Challenge / Anti-pattern | Solution Introduced | Real-World Impact |
|:---|:---|:---|
| Imperative bash scripts that break or duplicate packages when re-run | **Declarative, idempotent Ansible playbooks** | Running playbook 10 times results in identical state (`changed=0`) |
| Manually SSHing into multiple servers to run apt updates and configs | **Ansible fleet inventory orchestration** | Apply security baselines across 1 or 1,000 servers simultaneously |
| Ansible CLI requires complex terminal flags and local Python packages | **Ansible Semaphore Web UI** (`:3000`) | Clean web portal for project management, keys, and execution logs |
| Losing track of who ran what configuration changes across servers | **Audit log & execution history** in Semaphore | Complete history of runs, parameters, diffs, and results |

### Ansible Fleet Orchestration Architecture

```mermaid
flowchart TD
    subgraph ControlPlane["Ansible Control Plane (Dockerized on :3000)"]
        SemUI["Ansible Semaphore Web UI<br/>(http://127.0.0.1:3000)"]
        
        subgraph SemStore["Semaphore Persistent SQLite Store"]
            KeyStore["Key Store<br/>/keys/server_key.pem"]
            Inventory["Inventory: production<br/>server2 (20.198.82.108)"]
            Repo["Git Repo / Local Sync<br/>playbook: ansible/playbooks/setup-docker.yml"]
        end
        
        AnsibleCLI["Ansible Core Runner (Dockerized CLI)<br/><code>make ansible-setup</code>"]
        
        SemUI --> SemStore
        SemUI -->|"Traces Task Run"| AnsibleCLI
    end

    subgraph ManagedNode["Managed Cloud Node (Azure VM server2)"]
        direction TB
        Task1["1. Install Prerequisites (ca-certificates, curl, gnupg)"]
        Task2["2. Add Official Docker GPG Key & APT Repo"]
        Task3["3. Install Docker CE, CLI & Docker Compose Plugin"]
        Task4["4. Ensure Docker Daemon is Started & Enabled"]
        Task5["5. Add non-root azureuser to 'docker' Group"]
        
        Task1 --> Task2 --> Task3 --> Task4 --> Task5
    end

    AnsibleCLI -->|"SSH + Private Key (Idempotent Execution)"| ManagedNode
```

### Technical Specs & Use Case

* **Primary Tech**: Ansible Core 2.17, Ansible Semaphore UI, SQLite/Postgres persistence, Docker CE APT repo.
* **Key Commands**: `make ansible-ping`, `make ansible-check` (dry run), `make ansible-setup` (live run), `make up-ansible-ui`.
* **Industry Use Case**: Automated configuration management, OS security baseline enforcement, and Day-2 operations management across heterogeneous server fleets.

---

<div style="page-break-after: always;"></div>

# 3. Master Synthesis & Capability Matrices

## 3.1 The 12-Chapter Master Comparison Matrix

| # | Chapter Title | Core Technology | Primary Challenge Solved | Key Deliverable | Enterprise Value |
|:---:|:---|:---|:---|:---|:---|
| **01** | FastAPI & Tooling | FastAPI, uv, Ruff, Make | Fragmented dev environments | MVC Skeleton & Makefile | Reproducible dev onboarding |
| **02** | SQLite & SQLAlchemy | SQLite3, SQLAlchemy 2.0 | Volatile in-memory data loss | `notes.db` & Smoke Tests | Layered decoupling & persistence |
| **03** | Jinja2 UI & API | Jinja2, HTML5/CSS3, PRG | Siloed UI and API apps | Dual-consumer `views.py` | Full-stack unified monolith |
| **04** | Docker Containerization | Docker, BuildKit, uv cache | "Works on my machine" drift | Multistage `Dockerfile` | Portable, immutable runtime |
| **05** | Compose & Postgres | Docker Compose, Postgres 16 | Ephemeral single container | Multi-service orchestration | Enterprise DB & secrets management |
| **06** | Structured Logging | Python logging, JSON streams | Unstructured console logs | JSON stdout event logs | 12-Factor log streaming & SIEM |
| **07** | Jenkins CI Pipeline | Jenkins LTS, Docker-in-Docker | Manual, forgotten tests | Parallel CI `Jenkinsfile` | Automated quality & build gates |
| **08** | Continuous Delivery | SSH/SCP, Docker Hub, Bash | Risky manual deployments | `server/deploy.sh` script | Zero-downtime release & rollback |
| **09** | Health Probes & OTel | OpenTelemetry SDK, W3C | Blind orchestrator routing | `/health`, `/ready`, trace_id | Self-healing Kubernetes readiness |
| **10** | SigNoz APM Stack | SigNoz, ClickHouse, OTLP | Reactive outage firefighting | Distributed trace waterfalls | Rapid root-cause analysis & SLOs |
| **11** | Terraform Cloud IaC | Terraform 1.9, Azure, Rover | Error-prone "ClickOps" drift | Azure VM & Rover Visualizer | Declarative cloud infrastructure |
| **12** | Ansible CaC & UI | Ansible, Semaphore UI | Flakey imperative bash setup | Idempotent Docker playbook | Fleet configuration compliance |

---

<div style="page-break-after: always;"></div>

## 3.2 The 12-Factor App Compliance Matrix

| Factor | Factor Name | Implementation in Course | Relevant Chapters |
|:---|:---|:---|:---:|
| **I. Codebase** | One codebase tracked in revision control | Single Git repository across 12 incremental branches | All |
| **II. Dependencies** | Explicitly declare and isolate dependencies | `pyproject.toml` + `uv.lock` + multi-stage Docker build | Ch. 1, 4 |
| **III. Config** | Store config in the environment | `.env` file, environment variables, no hardcoded secrets | Ch. 5, 8, 11 |
| **IV. Backing Services** | Treat backing services as attached resources | Swappable database URLs (`sqlite:///` vs `postgresql://`) | Ch. 2, 5 |
| **V. Build, Release, Run** | Strictly separate build and run stages | Jenkins CI builds image; CD deploys immutable image tag | Ch. 4, 7, 8 |
| **VI. Processes** | Execute the app as one or more stateless processes | App container holds zero local state; state lives in Postgres | Ch. 4, 5 |
| **VII. Port Binding** | Export services via port binding | App binds directly to `:8000` via Uvicorn ASGI server | Ch. 1, 4, 5 |
| **VIII. Concurrency** | Scale out via the process model | Docker Compose multi-container replica readiness | Ch. 5 |
| **IX. Disposability** | Maximize robustness with fast startup & graceful shutdown | Fast boot (< 1s), SIGTERM handling, health checks | Ch. 5, 9 |
| **X. Dev/Prod Parity** | Keep development, staging, and production as similar as possible | Docker Compose locally mirrors remote cloud VM environment | Ch. 4, 5, 8, 12 |
| **XI. Logs** | Treat logs as event streams | Structured JSON logs written directly to `stdout` | Ch. 6, 10 |
| **XII. Admin Processes** | Run admin/management tasks as one-off processes | `make db-shell`, `make reset-db`, Ansible setup tasks | Ch. 5, 12 |

---

<div style="page-break-after: always;"></div>

## 3.3 Complete Operations Command Catalog

### Local Developer Loop
```bash
make check         # Verify local prerequisites (docker daemon, ports, tools)
make run           # Start local FastAPI dev server with auto-reload (:8000)
make test          # Execute pytest test suite
make lint          # Run ruff lint & format checks
make lint-fix      # Automatically fix formatting and lint issues
```

### Application & Database Stack (Docker Compose)
```bash
make build         # Build the immutable notes-app Docker image
make run-docker    # Run the standalone Docker container
make up            # Spin up multi-container stack (App + PostgreSQL)
make down          # Stop and tear down multi-container stack
make logs          # Tail real-time structured JSON logs from stdout
make reset-db      # Wipe PostgreSQL volume and re-initialize
make reset-app     # Wipe app and database state completely
```

### CI/CD Automation (Jenkins)
```bash
make pipeline      # Launch Jenkins CI server in Docker (:8080)
make down-pipeline # Stop Jenkins CI server (preserves volume)
make reset-pipeline# Wipe Jenkins data volume completely
make deploy        # Execute automated CD deployment to target host
```

### Full-Stack APM & Observability (SigNoz)
```bash
make up-signoz     # Launch SigNoz APM cluster (ClickHouse + UI on :8080)
make down-signoz   # Stop SigNoz APM cluster (preserves telemetry)
make reset-signoz  # Wipe all telemetry data in ClickHouse
```

### Cloud Infrastructure as Code (Terraform & Azure)
```bash
make tf-init       # Initialize Terraform & download AzureRM provider in Docker
make tf-plan       # Preview declarative cloud infrastructure plan
make tf-apply      # Provision Azure VM, VNet, Subnet, NSG, and Public IP
make tf-output     # Display Azure VM Public IP and SSH access command
make up-rover      # Launch Rover interactive visualizer on http://127.0.0.1:9000
make down-rover    # Stop Rover visualizer
make tf-destroy    # Tear down and destroy all cloud resources in Azure
```

### Configuration as Code (Ansible & Semaphore UI)
```bash
make ansible-ping  # Test SSH connectivity to cloud host server2
make ansible-check # Dry-run Docker setup playbook (--check --diff)
make ansible-setup # Provision Docker CE, Compose & user groups on server2
make up-ansible-ui # Start Ansible Semaphore Web UI on http://127.0.0.1:3000
make down-ansible-ui # Stop Ansible Semaphore Web UI
```

---

### Master Reset
```bash
make reset-all     # Clean wipe of all volumes: app, postgres, jenkins, and signoz
```

---
*End of DevOps Course Blueprint — Generated for Executive Presentation & PDF Export.*

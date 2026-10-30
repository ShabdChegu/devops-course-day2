# DevOps course command surface. Grows one target group per chapter:
#   ch.0 check+help | ch.1 run/test/lint | ch.4 build | ch.5 up/down
#   ch.6 logs | ch.7 pipeline | ch.8 deploy | ch.10 up-signoz | ch.12 polish

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
	@echo "  make reset-app wipe the app + db stack and data volume (drops all notes)"
	@echo "  make reset-db  wipe the postgres volume + re-init from .env (drops all notes)"
	@echo "  make scan    secret scan (the pre-commit hook + CI run this same script)"
	@echo "  make logs    tail the app's structured (JSON) logs from the stack"
	@echo "  make deploy    ch.8: run server/deploy.sh (the target-aware deploy; TAG=<img:tag>)"
	@echo "  make pipeline  ch.7: start the CI server (Jenkins, its own compose project)"
	@echo "  make down-pipeline ch.7: stop the CI server (keeps its data volume)"
	@echo "  make reset-pipeline ch.7: wipe the CI server data volume (jenkins_home)"
	@echo "  make up-signoz ch.10: start the standalone SigNoz stack (traces+metrics+logs)"
	@echo "  make down-signoz ch.10: stop the SigNoz stack (keeps its data volumes)"
	@echo "  make reset-signoz ch.10: wipe the SigNoz data volumes (drops all telemetry)"
	@echo "  make tf-init   ch.11: initialize Terraform in Docker"
	@echo "  make tf-plan   ch.11: preview Azure infrastructure changes"
	@echo "  make tf-apply  ch.11: provision server2 VM and network in Azure"
	@echo "  make tf-output ch.11: view VM public IP and SSH command"
	@echo "  make tf-destroy ch.11: tear down all Azure resources"
	@echo "  make up-rover  ch.11: start Rover visual architecture UI on http://127.0.0.1:9000"
	@echo "  make down-rover ch.11: stop Rover UI"
	@echo "  make ansible-ping ch.12: test SSH connectivity to server2"
	@echo "  make ansible-check ch.12: dry-run Docker setup playbook (--check --diff)"
	@echo "  make ansible-setup ch.12: provision Docker & Compose on server2"
	@echo "  make up-ansible-ui ch.12: start Ansible Semaphore UI on http://127.0.0.1:3000"
	@echo "  make down-ansible-ui ch.12: stop Ansible Semaphore UI"
	@echo "  make reset-all wipe everything: app, db, signoz, and jenkins volumes"
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
# image first, then runs the core profile detached. Only core - the CI
# server is a SEPARATE project (jenkins/docker-compose.yml, ch.7: one file
# = one machine), and signoz (ch.10) stays OFF until its chapter adds the
# profile.
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
	# ch.9's /ready could answer here too, but /notes is deliberate: it
	# proves the DB seam works end-to-end, not just that the server boots
	# - the #1 silent failure is a Postgres auth mismatch (docs/05 #1).
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

# Wipe the core stack (app + postgres) and its data volume (pgdata).
# Leaves SigNoz completely untouched. Restart with `make up`.
reset-app:
	docker compose --profile core down -v
	@echo "app and db stack wiped (pgdata dropped). SigNoz untouched. Restart: make up"

reset-core: reset-app
reset: reset-app

# ch.10: bring up the standalone SigNoz observability stack (signoz/compose.yaml).
# The app ships telemetry to it over the shared signoz-network.
#
# First boot = image pulls + one-time schema migration: up to ~3 min.
# The verify loop does NOT say "all 7 signoz containers are up" - two of
# them are one-shot jobs (user-scripts, migrator) that correctly sit in
# "exited (0)" after a green boot; the real question is "the SigNoz UI
# answers", i.e. the collector finished gating on the migration (docs/10
# pitfall #1 - data can lag a fresh boot).
up-signoz:
	@if [ ! -f .env ]; then echo ".env missing - created from .env.example (change the password!)"; cp .env.example .env; fi
	docker compose -f signoz/compose.yaml up -d
	@echo "waiting for SigNoz to finish booting (pulls + schema migration, ~90s first time)..."
	@ok=no; \
	for i in $$(seq 1 90); do \
		ui=$$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/ 2>/dev/null || true); \
		[ "$$ui" = "200" ] && ok=yes && break; \
		sleep 2; \
	done; \
	if [ "$$ok" = "yes" ]; then \
		echo "signoz up: UI http://127.0.0.1:8080 - first visit is the 'create admin account' step (docs/10 step 2)"; \
		echo "OTLP ingestion: http://127.0.0.1:4317 (gRPC, what OTEL_OTLP_ENDPOINT points at) + 4318 (HTTP)"; \
		echo ""; \
		echo "the ch.10 flip is ONE LINE in .env: OTEL_EXPORTER=otlp, then"; \
		echo "  docker compose --profile core up -d --force-recreate app   (docs/10 step 3)"; \
	else \
		echo "!! signoz did not come up (90s). State:"; \
		docker compose -f signoz/compose.yaml ps; \
		echo ""; \
		echo "   usual suspects (docs/10 pitfalls):"; \
		echo "   - user-scripts job 'exited (1)' repeatedly: no internet for the one-time"; \
		echo "     ClickHouse UDF download (signoz/README.md 'the one outbound call')"; \
		echo "   - clickhouse stuck 'starting': it waits for keeper + user-scripts (bring-up order)"; \
		echo "   - collector log tail:"; docker compose -f signoz/compose.yaml logs --tail 10 ingester 2>&1; \
		exit 1; \
	fi

# ch.10: stop the SigNoz stack - `stop`, not `down`: signoz-network is
# shared with the running app, and `down` would trip over it. SigNoz's 4
# data volumes are kept - the next up-signoz resumes.
down-signoz:
	docker compose -f signoz/compose.yaml stop
	@echo "signoz stopped (data kept). Restart: make up-signoz"

# ch.10: wipe ONLY SigNoz's telemetry data (its 4 named volumes) via its standalone
# compose project - leaves notes (pgdata) untouched.
reset-signoz:
	docker compose -f signoz/compose.yaml down -v
	@echo "signoz volumes wiped (a fresh boot re-runs the one-time migration). Notes (pgdata) untouched."

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

# ch.7: the CI controller, in Docker - its OWN compose project
# (jenkins/docker-compose.yml: one file = one machine = "the CI
# server"). `--build` also builds the course-jenkins image (stock
# Jenkins + uv + docker CLI + trivy, jenkins/Dockerfile), so this one
# target converges a fresh machine: nothing pre-cached needed.
#
# First run is the one-time setup (docs/07-jenkins-ci.md "Try it yourself"):
# http://127.0.0.1:13000 -> wizard's suggested plugins (git,
# workflow-aggregator, Pipeline: Declarative - the pipeline is declarative,
# so the plugins for options/post/triggers MUST be there) -> the
# docker-hub credential -> the notes-pipeline job (Pipeline from SCM,
# this repo + branch). Everything you set up then lives in the
# jenkins_home volume, so re-runs of this target just work.
# ch.8: --env-file .env - compose's auto-load looks in the PROJECT directory
# (jenkins/), not where you invoke it, so the root .env's SERVER_* would
# silently fall back to the ${VAR:-default} values. Conditional: a machine
# that has not run `make up` yet has no .env, and a missing --env-file is
# a hard error (the defaults then just apply, which is the ch.8 dry-run).
ifneq ($(wildcard .env),)
JENKINS_ENV_FLAGS := --env-file .env
endif

pipeline:
	docker compose $(JENKINS_ENV_FLAGS) -f jenkins/docker-compose.yml up -d --build
	@echo "waiting for Jenkins to finish booting (first boot of a fresh volume ~60-120s)..."
	@cid=$$(docker compose -f jenkins/docker-compose.yml ps -q jenkins | head -1); \
	ok=no; \
	for i in $$(seq 1 45); do \
		if docker logs "$$cid" 2>&1 | grep -q "Jenkins is fully up and running"; then ok=yes; break; fi; \
		case "$$(docker inspect --format '{{.State.Status}}' "$$cid" 2>/dev/null)" in exited|dead) break;; esac; \
		sleep 4; \
	done; \
	if [ "$$ok" = "yes" ]; then \
		echo "jenkins up: http://127.0.0.1:13000"; \
		echo ""; \
		echo "first run? do the one-time setup (docs/07-jenkins-ci.md, 'Try it yourself'):"; \
		echo "  1. wizard plugins: accept the suggested list, and make sure 'Pipeline: Declarative' is installed"; \
		echo "     (if not: Plugins -> Available -> 'Pipeline: Declarative' -> Install -> restart when asked)"; \
		echo "  2. Credentials > System > Global > docker-hub (Username/Password, your free Docker Hub account)"; \
		echo "  3. new item -> notes-pipeline -> Pipeline"; \
		echo "  4. Define pipeline: Pipeline script from SCM, repo + branch 07-jenkins-ci; Build now -> green"; \
		echo "   -> the Jenkinsfile's triggers block installs Poll SCM H/5 on that first green build, so a"; \
		echo "      pushed commit fires the next build within ~5 min. Re-run 'make pipeline' later: it just works."; \
	else \
		echo "!! jenkins did not come up (container state: $$(docker inspect --format '{{.State.Status}}' "$$cid" 2>/dev/null))."; \
		echo "   log tail:"; docker logs --tail 10 "$$cid" 2>&1; exit 1; \
	fi

# ch.7: stop the CI server (keeps jenkins_home data volume).
down-pipeline:
	docker compose $(JENKINS_ENV_FLAGS) -f jenkins/docker-compose.yml down
	@echo "jenkins stopped (data kept). Restart: make pipeline"

down-jenkins: down-pipeline

# ch.7: wipe the CI server data volume (jenkins_home).
# Leaves app, db, and SigNoz untouched.
reset-pipeline:
	docker compose $(JENKINS_ENV_FLAGS) -f jenkins/docker-compose.yml down -v
	@echo "jenkins stack wiped (jenkins_home dropped). App, db, and SigNoz untouched. Restart: make pipeline"

reset-jenkins: reset-pipeline

# Wipe everything across all compose stacks: app, postgres db, standalone SigNoz, and Jenkins CI server.
reset-all:
	@echo "==> wiping core stack (app + db)..."
	-docker compose --profile core down -v
	@echo "==> wiping SigNoz stack..."
	-docker compose -f signoz/compose.yaml down -v
	@echo "==> wiping Jenkins CI stack..."
	-docker compose $(JENKINS_ENV_FLAGS) -f jenkins/docker-compose.yml down -v
	@echo "==> wiping Ansible Semaphore stack..."
	-docker compose -f ansible/docker-compose.yml down -v
	@echo ""
	@echo "all stacks wiped (app, db, signoz, jenkins). Everything clean."

# ch.8: the HUMAN deploy path - the machine's is the pipeline's Deploy stage
# (the SAME server/deploy.sh, different key + tag). Here a student runs the
# target-aware script directly, with THEIR OWN key (.env's SERVER_SSH_KEY),
# so no VPS is ever required: SERVER_HOST=127.0.0.1 (the default) deploys to
# this machine; SERVER_HOST=<ip> is the identical command over ssh.
#
# No argument -> the .env's APP_IMAGE (notes-app:latest, ch.4's local image).
# TAG=<img:tag> -> deploy a specific pushed tag (ch.7's registry ref). deploy.sh
# is target-aware (local vs remote) and idempotent - re-running the same tag
# changes nothing (the lesson, docs/08). It verifies by curl, not exit code.
deploy:
	@if [ ! -f .env ]; then echo ".env missing - created from .env.example (change the password!)"; cp .env.example .env; fi
	@if [ -n "$(TAG)" ]; then bash server/deploy.sh "$(TAG)"; else bash server/deploy.sh; fi

# ch.11: Terraform & Rover in Docker - its OWN compose project
# (terraform/docker-compose.yml). Runs hashicorp/terraform and
# im2nguyen/rover in Docker containers, passing credentials from root .env.
TF_ENV_FLAGS := $(if $(wildcard .env),--env-file .env,)
TF_COMPOSE := docker compose $(TF_ENV_FLAGS) -f terraform/docker-compose.yml

tf-init:
	$(TF_COMPOSE) run --rm terraform init

tf-plan:
	$(TF_COMPOSE) run --rm terraform plan -out=plan.tfplan
	@$(TF_COMPOSE) run --rm --entrypoint /bin/sh terraform -c "terraform show -json plan.tfplan > plan.json" 2>/dev/null || true

tf-apply:
	$(TF_COMPOSE) run --rm terraform apply -auto-approve
	@$(TF_COMPOSE) run --rm --entrypoint /bin/sh terraform -c "terraform show -json > plan.json" 2>/dev/null || true

tf-destroy:
	$(TF_COMPOSE) run --rm terraform destroy -auto-approve
	@rm -f terraform/plan.tfplan terraform/plan.json terraform/*_key.pem

tf-output:
	$(TF_COMPOSE) run --rm terraform output

up-rover:
	@if [ ! -f terraform/plan.json ]; then \
		echo "Generating plan JSON for Rover..."; \
		$(MAKE) tf-plan; \
	fi
	$(TF_COMPOSE) up -d rover
	@echo "rover up: http://127.0.0.1:9000"

tf-ui: up-rover

down-rover:
	$(TF_COMPOSE) stop rover
	@echo "rover stopped. Restart: make up-rover"

down-tf: down-rover

# ch.12: Ansible in Docker & Semaphore UI - its OWN compose project
# (ansible/docker-compose.yml). Runs ansible and semaphore in Docker.
ANSIBLE_COMPOSE := docker compose -f ansible/docker-compose.yml

ansible-inventory-check:
	@if [ ! -f ansible/inventory.ini ]; then \
		echo "ansible/inventory.ini missing - copying from template..."; \
		cp ansible/inventory.ini.example ansible/inventory.ini; \
	fi
	@if grep -q "127.0.0.1" ansible/inventory.ini; then \
		echo "[NOTE] ansible/inventory.ini contains 127.0.0.1."; \
		echo "Run 'make tf-output' and update ansible/inventory.ini with server2's public IP."; \
	fi

ansible-ping: ansible-inventory-check
	$(ANSIBLE_COMPOSE) run --rm ansible ansible webservers -m ping

ansible-check: ansible-inventory-check
	$(ANSIBLE_COMPOSE) run --rm ansible ansible-playbook playbooks/setup-docker.yml --check --diff

ansible-setup: ansible-inventory-check
	$(ANSIBLE_COMPOSE) run --rm ansible ansible-playbook playbooks/setup-docker.yml

up-ansible-ui:
	$(ANSIBLE_COMPOSE) up -d semaphore
	@echo "Ensuring admin user exists..."
	@sleep 2
	@$(ANSIBLE_COMPOSE) exec -T semaphore sh -c '\
		if ! semaphore users list --config /etc/semaphore/config.json 2>/dev/null | grep -q "^admin$$"; then \
			semaphore users add --admin --login admin --name Admin --email admin@devops.local --password admin --config /etc/semaphore/config.json >/dev/null 2>&1 || true; \
		fi'
	@echo "Ansible Semaphore UI up: http://127.0.0.1:3000"
	@echo "Credentials: admin / admin"

ansible-ui: up-ansible-ui

down-ansible-ui:
	$(ANSIBLE_COMPOSE) stop semaphore
	@echo "Semaphore UI stopped. Restart: make up-ansible-ui"

down-ansible:
	$(ANSIBLE_COMPOSE) down
	@echo "Ansible stack stopped."

reset-ansible:
	$(ANSIBLE_COMPOSE) down -v
	@echo "Ansible stack and Semaphore database wiped."

.PHONY: help check run test lint lint-fix build run-docker up down reset-app reset-core reset reset-db scan logs pipeline down-pipeline down-jenkins reset-pipeline reset-jenkins reset-all deploy up-signoz down-signoz reset-signoz tf-init tf-plan tf-apply tf-destroy tf-output up-rover tf-ui down-rover down-tf ansible-inventory-check ansible-ping ansible-check ansible-setup up-ansible-ui ansible-ui down-ansible-ui down-ansible reset-ansible

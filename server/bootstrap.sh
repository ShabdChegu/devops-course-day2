#!/usr/bin/env bash
# ch.8 - ONE-TIME setup that converges a bare server (a VPS) into a deploy
# target: it converges the MACHINE, not an app (that's deploy.sh's job).
# Idempotent - run it twice, nothing breaks; run it after a VPS reset, the
# box comes back. Every step is a check, not a blind install:
#
#   1. Docker + compose plugin  (idempotent: get.docker.com's installer is a
#                                no-op when Docker is already there)
#   2. the repo's SERVER manifest (server/docker-compose.yml) - clone or pull
#   3. .env with the POSTGRES_* vars - created ONCE from .env.example
#   4. docker login to Docker Hub - the ONE-TIME registry auth so `--pull
#      always` can pull YOUR images (ch.8's "secrets live where they're
#      used": typed on the box, never in the repo)
#   5. seed the box's known_hosts for the pipeline's first ssh - otherwise
#      the pipeline's Deploy stage dies with "Host key verification failed"
#
# The one HUMAN step the script cannot do: your PUBLIC key in the box's
# ~/.ssh/authorized_keys (append it yourself: the private half lives in
# Jenkins' server-ssh credential, never in this repo).

set -euo pipefail

BOX_DIR="${1:-$HOME/devops-course-server}"
REPO="${2:-https://github.com/amanupadhyay32/devops-course}"
BRANCH="${3:-08-jenkins-cd}"

echo "bootstrap: box target: $BOX_DIR"

# --- 1. Docker + compose plugin --------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  echo "bootstrap: installing Docker (get.docker.com - idempotent)..."
  curl -fsSL https://get.docker.com | sh
  docker --version
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "bootstrap: compose plugin missing - installing (v2 is a PLUGIN of the docker CLI)..."
  INSTALL_DIR=/usr/local/lib/docker/cli-plugins; mkdir -p "$INSTALL_DIR"
  curl -fsSL "https://github.com/docker/compose/releases/download/v5.6.1/docker-compose-linux-$(uname -m)" -o "$INSTALL_DIR/docker-compose"
  chmod +x "$INSTALL_DIR/docker-compose"
fi
docker compose version

# --- 2. the repo's server manifest (clone once, pull after) ----------------
if [ -d "$BOX_DIR/.git" ]; then
  git -C "$BOX_DIR" checkout "$BRANCH" && git -C "$BOX_DIR" pull
else
  git clone --depth 1 -b "$BRANCH" "$REPO" "$BOX_DIR"
fi

# --- 3. .env, ONCE (ch.5's pitfall lives here, on the box) ---------------
# Postgres sets its password only when its volume is FIRST created. So this
# file is copied once and never re-shipped: changing the password LATER
# does not re-init an existing volume, and the app starts failing
# authentication. (docs/08 pitfall #4 - the ch.5 gotcha, new location.)
if [ ! -f "$BOX_DIR/.env" ]; then
  echo "bootstrap: creating $BOX_DIR/.env (change the password BEFORE first boot; the volume bakes it in)"
  ex="$BOX_DIR/.env.example"
  u=$(grep '^POSTGRES_USER=' "$ex" 2>/dev/null | sed 's/^POSTGRES_USER=//' || true); u="${u:-notes}"
  p=$(grep '^POSTGRES_PASSWORD=' "$ex" 2>/dev/null | sed 's/^POSTGRES_PASSWORD=//' || true); p="${p:-change-me-please}"
  d=$(grep '^POSTGRES_DB=' "$ex" 2>/dev/null | sed 's/^POSTGRES_DB=//' || true); d="${d:-notes}"
  printf 'POSTGRES_USER=%s\nPOSTGRES_PASSWORD=%s\nPOSTGRES_DB=%s\n' "$u" "$p" "$d" > "$BOX_DIR/.env"
fi

# --- 4. docker login, the one-time registry auth ---------------------------
# The box's DAEMON authenticates (a different auth store from Jenkins'
# host daemon - two daemons, two logins). `--password-stdin` keeps it off
# ps/the history; this is a manual, human step on the box.
if ! docker info 2>/dev/null | grep -q "Docker Hub"; then
  echo "bootstrap: not logged in to Docker Hub on this box yet. One-time step, on the box (refresh token preferred - same account as ch.7's docker-hub credential):"
  echo "    read -s -p 'docker hub login: ' U; read -s -p 'password/token: ' P; echo \"\$P\" | docker login -u \"\$U\" --password-stdin"
fi

# --- 5. seed known_hosts so the pipeline's first ssh succeeds -------------
# The pipeline runs StrictHostKeyChecking=yes against its own key file;
# seeding here means the first contact is ALREADY known - no prompt, no
# accept-new shortcut, and a changed host key still fails (the secure form).
if command -v ssh-keyscan >/dev/null 2>&1 && [ -n "${PIPELINE_HOST:-}" ]; then
  ssh-keyscan -H "$PIPELINE_HOST" 2>/dev/null >> "$BOX_DIR/.deploy_known_hosts" || true
  [ -s "$BOX_DIR/.deploy_known_hosts" ] && echo "bootstrap: seeded $BOX_DIR/.deploy_known_hosts for host-key checking"
fi

echo "bootstrap: done - $BOX_DIR is deployable: server/deploy.sh (or the pipeline's Deploy stage) can now push a tag to it."
echo "bootstrap: remaining HUMAN step: your public key -> the box's ~/.ssh/authorized_keys."

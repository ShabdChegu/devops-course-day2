#!/usr/bin/env bash
# ch.8 - THE deploy, target-aware: ONE script, two machines.
#
#   SERVER_HOST=127.0.0.1 (the default) -> the SAME machine as CI: the app
#   server project runs right here (in Jenkins, through the socket mount).
#   That's the local dry-run - the whole chapter is completable with no VPS.
#   SERVER_HOST=<vps-ip> -> the identical commands over SSH: the box was
#   converged by server/bootstrap.sh; the private key is where
#   DEPLOY_SSH_KEY_FILE points (Jenkins' server-ssh credential, or your
#   own key for a local `make deploy`).
#
# The target's whole job is one command:
#
#   APP_IMAGE=<image:tag> docker compose -f <manifest> up -d [--pull always]
#
# A REGISTRY reference (contains "/") gets `--pull always`: re-pull even
# though a container already exists - it is the NEW tag that makes compose
# recreate it. Same tag = no-op (idempotent by contract; deploy the same
# build twice, the second run changes nothing - that's the lesson, docs/08).
# A local reference (no "/") is plain `up -d`: the image was built here in
# ch.4, there is nothing to pull.
#
# "Deployed" is NOT "the container started": `up -d` exits 0 while the app
# crash-loops (the same lesson the root Makefile's `up` target teaches). The
# deploy is done when the app ANSWERS - curl in a retry loop, docs/08
# pitfall #2.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$HERE")"
if [ -f "$REPO_DIR/.env" ]; then set -a; . "$REPO_DIR/.env"; set +a; fi
SERVER_HOST="${SERVER_HOST:-127.0.0.1}"
SERVER_PORT="${SERVER_PORT:-8000}"
BOX_DIR="${BOX_DIR:-$HOME/devops-course-server}"

# $1 = the image reference to run: ch.7's pushed tag
# (user/notes-app:<sha7> - the pipeline passes THIS build's SHA), or no
# argument -> notes-app:latest, ch.4's local image (local dev).
IMAGE="${1:-notes-app:latest}"

is_local=no
case "$SERVER_HOST" in 127.*|localhost) is_local=yes ;; esac
[ "$SERVER_HOST" = "$(hostname 2>/dev/null || true)" ] && is_local=yes

case "$IMAGE" in
  */*) UPSPEC="up -d --no-build --pull always" ;;
  *)   UPSPEC="up -d" ;;
esac

if [ "$is_local" = "yes" ]; then
  # The root project - ch.5's `make up` stack. The seam is its one line:
  # `image: ${APP_IMAGE:-notes-app}` (root docker-compose.yml); the deploy
  # just points APP_IMAGE at the new reference.
  deploy_cmd="env APP_IMAGE=$IMAGE docker compose --profile core -f $REPO_DIR/docker-compose.yml $UPSPEC"
  verify_cmd="curl -sf -o /dev/null http://127.0.0.1:$SERVER_PORT/notes"
else
  SSH_TARGET="$SERVER_HOST"
  [ -n "${SERVER_USER:-}" ] && SSH_TARGET="$SERVER_USER@$SERVER_HOST"

  if [ -n "${WORKSPACE:-}" ]; then
    # THE PIPELINE: never prompts (a hung pipeline is the failure mode),
    # host keys from a SEEDED file (WORKSPACE persists on the jenkins_home
    # volume, so seeding happens once, docs/08 pitfall #3) - first contact
    # succeeds AND a changed host key still fails (the secure form).
    KHF="$WORKSPACE/deploy_known_hosts"
    ssh-keyscan -H "$SERVER_HOST" 2>/dev/null >> "$KHF" || \
      echo "deploy: ssh-keyscan could not reach $SERVER_HOST (firewall? box down? non-standard port?)"
    SSH_OPTS="-T -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$KHF -o ConnectTimeout=10"
  else
    # A HUMAN on their machine: normal ssh ergonomics - first-contact
    # host-key prompt is fine - but key-only (BatchMode: no password
    # prompt, ever).
    SSH_OPTS="-T -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"
  fi
  [ -n "${DEPLOY_SSH_KEY_FILE:-}" ] && SSH_OPTS="$SSH_OPTS -i $DEPLOY_SSH_KEY_FILE"

  remote_cmd="cd '$BOX_DIR' && env APP_IMAGE=$IMAGE docker compose -f server/docker-compose.yml $UPSPEC"
  deploy_cmd="ssh $SSH_OPTS $SSH_TARGET \"$remote_cmd\""
  verify_cmd="ssh $SSH_OPTS $SSH_TARGET \"curl -sf -o /dev/null http://127.0.0.1:$SERVER_PORT/notes\""
fi

transport="local (dry-run target: same machine as CI)"
[ "$is_local" = "no" ] && transport="remote, via ssh -> ${SSH_TARGET}"
echo "deploy: $IMAGE -> $SERVER_HOST:$SERVER_PORT ($transport)"
[ -n "${DEPLOY_SSH_KEY_FILE:-}" ] && [ "$is_local" = "no" ] && \
  echo "deploy: ssh key: $DEPLOY_SSH_KEY_FILE (injected - never in this repo)"

# --- deploy -----------------------------------------------------------------
sh -c "$deploy_cmd"

# --- verify: the app ANSWERS (up to ~30s: recreate + boot) -------------------
echo "deploy: waiting for http://$SERVER_HOST:$SERVER_PORT/notes to answer..."
ok=no
for _ in $(seq 1 30); do
  if sh -c "$verify_cmd" 2>/dev/null; then ok=yes; break; fi
  sleep 1
done
if [ "$ok" = "yes" ]; then
  echo "deploy: OK - $IMAGE is live on $SERVER_HOST:$SERVER_PORT"
else
  echo "deploy: FAILED - the container started but the app is not answering"
  echo "       (docs/08 pitfall #2): logs: on the box run"
  [ "$is_local" = "yes" ] && echo "       docker logs \$(docker compose -f $REPO_DIR/docker-compose.yml ps -q app)"
  [ "$is_local" = "no" ] && echo "       ssh $SSH_TARGET 'cd $BOX_DIR && docker compose -f server/docker-compose.yml logs --tail 20 app'"
  exit 1
fi

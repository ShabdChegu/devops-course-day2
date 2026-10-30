#!/usr/bin/env bash
# Prerequisites gate (make check).
# Verifies, with actionable messages:
#   - tools present: git, uv, docker
#   - docker daemon reachable
#   - course ports free: 8000 (app) 5432 (postgres) 8080/9095 (signoz) 13000 (jenkins)
set -u
fail=0

for t in git uv docker; do
  if command -v "$t" >/dev/null 2>&1; then
    echo "  ok    $t -> $(command -v "$t")"
  else
    case $t in
      git)    hint="git https://git-scm.com" ;;
      uv)     hint="uv https://docs.astral.sh/uv/getting-started/installation/" ;;
      docker) hint="docker https://docs.docker.com/get-docker/" ;;
    esac
    echo "  miss  $t - install: $hint"
    fail=1
  fi
done

if docker info >/dev/null 2>&1; then
  echo "  ok    docker daemon reachable"
else
  echo "  err   docker daemon not reachable"
  echo "        macOS/Windows: start Docker Desktop"
  echo "        Linux:         sudo systemctl start docker"
  fail=1
fi

# Port check needs a system python3; if absent, warn and skip (don't fail hard).
PY=""
for c in python3 python; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 7) else 1)' >/dev/null 2>&1; then
    PY=$c
    break
  fi
done

if [ -n "$PY" ]; then
  busy=$("$PY" - <<'PYEOF'
import socket
ports = [8000, 5432, 8080, 9095, 13000]
busy = []
for p in ports:
    s = socket.socket()
    s.settimeout(0.25)
    try:
        s.connect(("127.0.0.1", p))
        busy.append(p)
    except OSError:
        pass
    finally:
        s.close()
print(" ".join(map(str, busy)))
PYEOF
  )
  if [ -n "$busy" ]; then
    echo "  err   busy port(s): $busy"
    # Name the process holding each port, so the fix is one command, not a hunt.
    for p in $busy; do
      name=""
      pid=""
      if command -v ss >/dev/null 2>&1; then
        line=$(ss -ltnp 2>/dev/null | grep ":$p " | head -1)
        name=$(printf '%s' "$line" | sed -n 's/.*users:((\([^",]*\).*/\1/p')
        pid=$(printf '%s' "$line" | sed -n 's/.*pid=\([0-9]*\).*/\1/p')
      fi
      if [ -z "$name" ] && command -v lsof >/dev/null 2>&1; then
        name=$(lsof -iTCP:"$p" -P -sTCP:LISTEN 2>/dev/null | awk 'NR>1 {print $1; exit}')
        pid=$(lsof -iTCP:"$p" -P -sTCP:LISTEN 2>/dev/null | awk 'NR>1 {print $2; exit}')
      fi
      if [ -n "$name" ]; then
        echo "        port $p held by: $name (pid $pid)"
        echo "        stop it -> kill $pid"
      else
        echo "        port $p held by: unknown process (check: lsof -iTCP:$p -P -sTCP:LISTEN | ss -ltnp | grep :$p)"
      fi
    done
    fail=1
  else
    echo "  ok    ports free: 8000 5432 8080 9095 13000"
  fi
else
  echo "  warn  no system python 3.7+ found - skipping port check"
fi

if [ "$fail" -eq 0 ]; then
  echo "check: environment is ready"
else
  echo "check: fix the problems above, then re-run 'make check'"
  exit 1
fi

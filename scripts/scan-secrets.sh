#!/usr/bin/env bash
# ch.5's secrets habit: catch credentials in the repo *before* they're
# committed. Runs as a pre-commit hook AND in ch.7's CI (belt + suspenders).
#
# Two tiers, no external install:
#   1. gitleaks, if present on the machine - the real tool
#   2. a regex fallback for the classic patterns: passwords in URLs,
#      OpenAI "sk-" keys, AWS AKIA keys
#
# Exit 0 = clean, exit 1 = found something.

set -u

if command -v gitleaks >/dev/null 2>&1; then
  echo "scan: using gitleaks"
  gitleaks detect --no-banner -f . -r . 2>/dev/null
  status=$?
  # gitleaks exits 1 on findings; anything else is a config/tool error -
  # treat as "pass with a warning" so a broken tool never blocks students.
  [ $status -eq 1 ] && { echo "scan: gitleaks reported findings above"; exit 1; }
  [ $status -eq 0 ] && { echo "scan: clean (gitleaks)"; exit 0; }
  echo "scan: gitleaks error (exit $status) - falling back to regex"
fi

echo "scan: using regex fallback"
# Patterns that flag *likely* secrets in tracked files. .env.example is
# whitelisted - its values are placeholders, and the file IS the template.
#
# NOTE the credential pattern excludes `$`/`{` from its user & password
# parts: that way a compose interpolation like `${POSTGRES_USER}:${POSTGRES_PASSWORD}`
# (NOT a secret - filled from .env at runtime) is ignored, while a
# *hardcoded* user:pass before the @ (e.g. a pasted connection string) is
# caught. A secret scanner that flags its own compose files teaches
# students to distrust it - false positives kill a tool's credibility.
# (This comment deliberately avoids a literal credential so the scanner
# does not flag the very file that owns it.)
hits=$(grep -rniE \
  --exclude-dir=.git \
  --exclude-dir=.venv \
  --exclude=.env.example \
  --exclude=uv.lock \
  --exclude-dir=node_modules \
  -e '(postgres(ql)?|mysql|mongodb)(\+[^:]+)?://[^:/ "${}]+:[^@ "${}]+@' \
  -e 'sk-[a-zA-Z0-9_-]{20,}' \
  -e 'AKIA[0-9A-Z]{16}' \
  . 2>/dev/null || true)

if [ -n "$hits" ]; then
  echo "scan: potential secrets found:"
  echo "$hits"
  echo ""
  echo "If this is a false positive (a doc example, a test fixture), wrap the"
  echo "value so it does not look like a credential, or extend the whitelist"
  echo "above - never gitignore a file that holds real credentials."
  exit 1
fi

echo "scan: clean (regex fallback)"

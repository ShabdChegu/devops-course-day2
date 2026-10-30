# signoz/ — the "observability box" kit (ch.10)

One folder = one machine, same rule as `jenkins/` and `server/`. This is
SigNoz — the backend that answers ch.9's open question: *where do traces go
once the console printer is no longer the endpoint?* From here on, your
requests show up in a UI: one trace waterfall, one metrics dashboard, one
log view, all joined by the same `trace_id` ch.9 stamped on the logs.

The files here are the **official Foundry layout**, vendored into the repo
so nothing in the course depends on an external tool at run time:

| File | What it is |
|------|-----------|
| `compose.yaml` | Option B: run SigNoz as its own compose project (`docker compose -f signoz/compose.yaml up -d`). Same containers as Option A, independent project (`name: signoz`). |
| `casting.yaml` + `casting.yaml.lock` | Provenance: the SigNoz Foundry specification that *generated* `compose.yaml` (docs: https://signoz.io/docs/install/docker/). `casting.yaml.lock` is the rendered config Foundry pins — keep both so a re-`forge` is reproducible. |
| `ingester/ingester.yaml` | The OTel collector's full config: receivers (OTLP 4317/4318), the `signozclickhouse*` exporters, and the span-metrics processor. |
| `ingester/opamp.yaml` | The collector's management link back to the SigNoz UI (its log noise is cosmetic — see docs/10 pitfall #3). |
| `telemetrykeeper/clickhousekeeper/keeper-0.yaml` | ClickHouse Keeper (coordination) config. |
| `telemetrystore/clickhouse/config-0-0.yaml` | ClickHouse server config (incl. TTLs: traces live 1 day by default — a real retention knob, not magic). |
| `telemetrystore/clickhouse/functions.yaml` | The histogram-quantile UDF declaration. |

## Option A (the course default): the root compose's `signoz` profile

The root `docker-compose.yml` carries the same 7 services, `profiles:
["signoz"]`, mounting the config files from this folder
(`./signoz/ingester/...` etc.). That is how **Option A** works: one project,
two footprints.

- `make up-signoz` → core + signoz, app reaches the collector at
  `http://signoz:4317` (the ingester's alias on the shared `signoz-network`).
- `make down-signoz` / `make reset-signoz` → stop / wipe telemetry.
- **The ch.10 flip** is one line in `.env` — `OTEL_EXPORTER=otlp` — then
  `docker compose --profile core up -d --force-recreate app`. (Recreate,
  not just `up`: the env var is read at boot. And if your app image is
  older than the fix in `notes_app/otel.py`, rebuild first — docs/10
  pitfall #2.)

## Option B (the "separate box" variant, ch.8's VPS story)

`docker compose -f signoz/compose.yaml up -d` — its own project named
`signoz`, its own `devops...` prefixed volumes; publish nothing extra (4317
is already in the file). Point the app's `OTEL_OTLP_ENDPOINT` at the box's
IP (`http://<box>:4317`). This is how "the observability server" lands on
a VPS in ch.8's closed loop.

## The bring-up order (do not tidy the names)

keeper → **user-scripts job** (one-shot: downloads the ClickHouse UDF —
the stack's only outbound call, needs internet once per fresh volume) →
clickhouse → **migrator job** (one-shot: runs the schema migrations) →
ingester (its command gates on `migrate sync check`) → UI + everything.
The two one-shot jobs sit in `exited (0)` after a green boot — that is
**correct**, not a failure (`make up-signoz` verifies the UI answers, not
"7/7 containers up").

## First visit

UI: `http://127.0.0.1:8080` → **create the admin account** (the docs ship
no baked credentials — that is deliberate). Then:
1. *Services* page: `notes-app` appears (that is your OTLP proof).
2. *Traces*: one span per request — ch.9's `trace_id` is the join key to
   the *Logs* page.
3. *Metrics*: the app's counters/histograms (ch.10's `otel.py` ships
   `http_requests_total` + `http_request_duration_seconds`).
4. *Alerts* (the SLO, docs/10 step 5): **error rate** — 5xx span ratio
   over 5 min > 10%, or **latency** — p95 `http_request_duration_seconds`
   > 0.5s sustained. Alerts live in SigNoz's metadata DB, so they are a
   *UI object*, not a yaml in this folder (the stretch exercise in docs/10
   recreates one via the API so it is scriptable).

## The incident drill (docs/10 step 6)

`docker compose stop db` (or `tc qdisc` latency in a stretch) → the
alert fires → open the trace waterfall → find the failing span at the
SQL layer (ch.10's SQLAlchemy instrumentor names it) → write up the
"story": one trace_id that joins the error log line to the span.

"""ch.9 - liveness and readiness: two questions, two endpoints.

/health  "is the process alive?"      -> the LIVENESS probe
/ready   "can it take traffic now?"   -> the READINESS probe

Why two, not one?
- A container can be ALIVE (the process is up, /health answers) while NOT
  READY (its database is still booting, a migration is mid-flight, a reload
  is in progress). The two states are genuinely different.
- The things that ask them ask at DIFFERENT moments:
    * liveness  -> "should the orchestrator RESTART this box?" (it is wedged)
    * readiness -> "should the load balancer ROUTE traffic here?" (not yet / not anymore)
  Restarting a merely-not-ready box is wrong (its dependency will catch up);
  restarting an un-HEALTHY box is the recovery. One endpoint cannot answer
  both questions, so we ship both.

ch.9's main track: /ready returns 200 - the app is imported and its server
is up, so it is serving. The docs/09 stretch exercise makes /ready actually
ping the database - that is what "ready" really means, and it is the diff
that makes the endpoint earn its name.
"""

from fastapi import APIRouter

router = APIRouter(tags=["health"])


@router.get("/health")
def health() -> dict:
    """Liveness: the process is up and the HTTP server is answering.

    Deliberately checks NOTHING else: a liveness probe that depends on a
    flapping dependency will restart the box in a loop the moment that
    dependency blips. "Alive" is the only question it is allowed to ask.
    """
    return {"status": "ok"}


@router.get("/ready")
def ready() -> dict:
    """Readiness: can this instance accept traffic right now?

    Main track: the app is up and its server is running, so it is ready.
    (docs/09 stretch: ping the database here - that is the real definition.)
    """
    return {"status": "ready"}

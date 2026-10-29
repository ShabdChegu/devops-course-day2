# jenkins/ — the CI server, as one folder

This folder **is** the CI server: a compose file, its controller image, and (in
the repo root) the pipeline it runs. One file = one machine — the root
`docker-compose.yml` is the *app server*; this project is the *CI server*.
ch.8's "move Jenkins to a VPS" is *copy this folder, boot it there*.

| File | Role |
|---|---|
| `docker-compose.yml` | the CI server project: `jenkins` service + `jenkins_home` volume + host-socket mount |
| `Dockerfile` | the `course-jenkins` image: stock Jenkins LTS + `uv` + docker CLI + `trivy` |
| `../Jenkinsfile` | the pipeline itself: Sync → Checks (lint · scan · test, parallel) → Build → Trivy gate → Push |
| `../docs/07-jenkins-ci.md` | *why* it's shaped this way: the gotchas, the pitfalls, the quiz |

## 1. How to run

Prereqs: the Docker daemon is running and port 13000 is free
(`make check` verifies both and names whoever holds a clashing port).

From the repo root:

```bash
make pipeline        # = docker compose -f jenkins/docker-compose.yml up -d --build
```

…or by hand: `docker compose -f jenkins/docker-compose.yml up -d --build`.
Then open `http://localhost:13000`.

- **First boot** takes ~60–120 s (the setup wizard). After that it's
  instant: everything you set up lives on the named `jenkins_home` volume.
- **Daily** there's nothing to do: `make pipeline` just boots a working
  Jenkins. Stop it with `docker compose -f jenkins/docker-compose.yml down`.
- **Where the state lives:** `devops_course_jenkins_home` (plugins, the
  `docker-hub` credential, the job, workspaces, Trivy's vuln DB). The
  top-level `name: devops_course` in this compose file pins that name —
  without it, compose would derive the project name from this directory
  and silently create a *different*, empty volume.
- **Controller image changed** (e.g. a new trivy version in
  [Dockerfile](Dockerfile))? `make pipeline` rebuilds it — that's what the
  `--build` is for.

## 2. Configure the Docker Hub credential (one-time, ~2 min)

The Push stage looks up a credential by **ID** — `docker-hub` is a string
contract between the UI and the `withCredentials` block in the
[Jenkinsfile](../Jenkinsfile) (docs/07 pitfall #4: a blank ID field stores
the entry under a random UUID and the pipeline fails one clean line deep in
a green-looking build).

1. **Manage Jenkins → Credentials → System → Global credentials** →
   *Add credentials*.
2. Kind: **Username with password** (a *secret* — Jenkins encrypts it at
   rest in the volume).
3. **ID: `docker-hub`** ← fill this in, do not skip it.
4. Username: your Docker Hub account. Password: a **refresh token**
   (Docker Hub → account Settings → Security → *Generate refresh token*)
   rather than the account password — it can be revoked without rotating
   your password (docs/07 pitfall #5).

Hygiene, one line: the secret lives **only** in the Jenkins credentials
store — never in the repo, never in the image, never in the log
(`withCredentials` masks it; `--password-stdin` keeps it off the command
line where `ps` could see it).

## 3. Add the pipeline job (one-time, ~2 min)

The pipeline *is* the Jenkinsfile in the repo — the job just points at it.
After the one-time setup above, this is the whole "add a pipeline":

1. **New Item** → name it `notes-pipeline` → type **Pipeline** (not
   Freestyle).
2. Under *Pipeline*, Definition: **Pipeline script from SCM** → SCM:
   **Git** → Repository URL: your fork of the course repo → Branches to
   build: `origin/07-jenkins-ci` (this chapter's branch).
3. **Save**, then **Build now**.

What the first green build does (beyond the stages — Sync, Checks
(parallel lint · scan · test), Build image, Trivy gate, Push to Docker Hub):

- the declarative **`triggers` block** installs `Poll SCM H/5 * * * *` into
  the job — the trigger is *owned by the repo*, so from now on a push to the
  branch fires the next build within ~5 minutes, no button.
- the **`options` block** applies `disableConcurrentBuilds()` (a poll
  landing mid-build queues instead of racing two `docker build`s on the
  host daemon) and a 20-minute `timeout` (a cold first build downloads
  Trivy's vuln DB).
- the **`post` block** is wired up: `success` prints the shipping receipt,
  `always` prunes the dangling image every build orphans, `failure` says
  the honest thing — a red build pushes nothing, so `latest` on Docker Hub
  still points at the last green build.

The first Trivy run is slow (one-time vuln-DB download, minutes; the
volume caches it). After that the loop is just:

```
edit code -> git push -> poll fires a build -> green -> Docker Hub gains
<build number> + <sha> + latest
```

**Extending the pipeline** follows the same loop: edit the `Jenkinsfile`
(it's code, not UI config), commit, push — and the pipeline's own
lint/secret-scan/test/gate stages vet the change before the new stage ever
runs.

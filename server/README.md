# ch.8 — the app server: setup, deploy, credentials

The **app server** side of the chapter. ch.7 ended with an image on Docker
Hub; this folder is where a *machine* picks it up and runs it. One rule
holds the folder together: **the box is converged once, and never touched
again by a deploy.**

| File | Job |
|------|-----|
| `bootstrap.sh` | One-time: turn a bare box into a deploy target (Docker + compose plugin, clone this repo, create `.env`, `docker login`, seed `known_hosts`) |
| `deploy.sh` | Per-deploy: pull the tagged image + recreate the container + **verify the app answers** — the same script for the local dry-run target and the VPS |
| `docker-compose.yml` | The box's manifest: app + postgres, **no `build:` section** — the box pulls, it never builds (it cannot run code that failed ch.7's gate) |
| `.env` (created by bootstrap, on the box) | `POSTGRES_*` only — copied **once**; the volume bakes the password in at first init (ch.5's pitfall, new location) |

Configuration lives in two vars-only places; secrets live in one:

- **Where the box is** (`SERVER_HOST` / `SERVER_PORT` / `SERVER_USER`) —
  your root `.env` + `jenkins/docker-compose.yml`'s `environment:` (ch.5's
  vars-only rule: an IP is configuration, not a secret).
- **The registry account** — Docker Hub credentials as the ch.7
  `docker-hub` credential; the box authenticates once, itself
  (`docker login` in bootstrap step 4 — secrets live *where they're used*).
- **The SSH key** — Jenkins credential **`server-ssh`** (below). Never in
  this repo, never in `.env`, never on a command line.

> `SERVER_HOST=127.0.0.1` (the default) is the **local dry-run target**: the
> whole chapter runs on your own machine, no VPS needed. A VPS is
> `SERVER_HOST=<ip>` + running `bootstrap.sh` there + your public key in its
> `authorized_keys`. Same script, one variable.

---

## 1. Bring up the box (once)

```bash
# on the box (a VPS, or a second machine):
./server/bootstrap.sh            # defaults: ~/devops-course-server, this repo, branch 08-jenkins-cd
```

Bootstrap does, in order: Docker (idempotent) → compose plugin → `git
clone --depth 1 -b 08-jenkins-cd` → create `.env` **once** → `docker login`
prompt (your Docker Hub account, refresh token preferred) → seed
`.deploy_known_hosts` for host-key checking.

Then the **one human step no script can do**: your public key into the
box's `authorized_keys` — one of two keys the box will accept:

| Key | Where it lives | Who uses it |
|-----|---------------|-------------|
| yours (`~/.ssh/id_ed25519.pub`) | the box's `authorized_keys` | `make deploy` (human path, `ssh -i` your own key) |
| Jenkins' (the `server-ssh` credential) | Jenkins' `jenkins_home` volume, encrypted | the pipeline's Deploy stage (`sshUserPrivateKey` → temp file → `ssh -i`) |

Both log in as `SERVER_USER` — that's why the account name is config, not
part of either key.

## 2. Deploy

```bash
# human, from your machine (your key, .env's vars):
make deploy                 # runs server/deploy.sh: local target pulls notes-app:latest
make deploy amanupadhyay32/notes-app:7690713   # or a specific pushed tag

# machine, no human at all:
# push a commit -> Poll SCM H/5 fires ch.7's pipeline -> its new Deploy
# stage runs the SAME deploy.sh over ssh (the server-ssh key, seeded
# known_hosts) with this build's SHA tag -> the box recreates its app
# container and deploy.sh curls /notes until it answers.
```

`deploy.sh` is target-aware: `SERVER_HOST=127.*` runs the root compose
project locally (through the socket mount, when called from Jenkins);
anything else is the identical command over `ssh -T`. "Deployed" means
*the app answered HTTP* — `up -d` exiting 0 while it crash-loops is the
chapter's planted pitfall (#2 in docs/08).

## 3. Create the `server-ssh` credential in Jenkins

Ch.7 taught you the credential *pattern* (`docker-hub`); this is the same
move for SSH. In the Jenkins UI:

1. **Manage Jenkins → Credentials → System → Global credentials** →
   *Add Credentials*.
2. Kind: **SSH Username with private key**.
3. **Username:** your box's login — match `SERVER_USER` (e.g. `aman`).
   (Our deploy runs plain `ssh`, so this field is decorative for the
   pipeline; keeping them equal is the hygiene that stops it reading as a
   bug later.)
4. **Private key:** *Enter directly* — paste the **private** half of a key
   pair the box trusts. The public half goes into the box's
   `authorized_keys` (step 1 above); this credential holds the private half
   only.
5. **ID:** exactly **`server-ssh`** — no spaces. This is a *contract*, like
   `docker-hub` in ch.7: `Jenkinsfile:220` hardcodes it. Rename it in the
   UI and every build dies with "credential not found" — an ID is code,
   not config.

That's the whole Jenkins-side setup for ch.8: one credential. Everything
else the pipeline needs (`SERVER_HOST`, `SERVER_PORT`, `DEPLOY_USER`)
arrives via `jenkins/docker-compose.yml`'s `environment:` — read from your
root `.env`, so a box change is a one-var edit, versioned, no UI.

---

*Pitfalls (`--pull always`, box-side 401s, `known_hosts`, `.env` drift on
the box's volume) are written into `docs/08-jenkins-cd.md` — planted, not
surprise.*

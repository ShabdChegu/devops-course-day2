// ch.7 - the course's first CI pipeline: lint -> scan -> test -> build the
// image. Runs ON the Jenkins container itself - no Docker-in-Docker: the
// host-socket mount (docker-compose.yml, jenkins service) gives this
// container the tools it can't carry in its own image (the docker CLI, a
// Python toolchain, the uv cache).
//
// The one thing that can't ride in here: the app's .env (Postgres password,
// ch.5's secrets story). It stays on the host; the test stage points the
// suite at the *core* Postgres from .env and injects it at runtime.

// -- 1. Lint ----------------------------------------------------------------
// Exactly `make lint` locally: ruff check + ruff format check. CI enforces
// the same rule the dev loop runs - one tool, no divergence.
// uv creates a scratch venv on first run, then caches wheels under
// /var/jenkins_home/.cache (a named volume, so the next build is fast).
stage("Lint") {
    agent {
        docker {
            image 'jenkins/jenkins:2.580.2-lts'
            // The ch.7 gotcha, made explicit (docs/07, pitfall #1):
            // /var/run/docker.sock -> the host daemon; $HOME -> the volume
            // where uv caches; /opt/course -> the checked-out repo.
            args  "--user root --network host -v /var/run/docker.sock:/var/run/docker.sock -v jenkins_home:/var/jenkins_home -v /opt/course:/opt/course"
            workdir "/opt/course"
        }
    }
    steps {
        // ch.7's teaching shape: the dev-command trio, in order -
        //  uv sync      create the venv from the lockfile (+ the project itself)
        //  uv sync --all-groups    pull the dev group in place (pytest, ruff, ...)
        //  uv run --no-sync        run against it, WITHOUT re-syncing
        sh 'uv sync && uv sync --all-groups && uv run --no-sync ruff check . && uv run --no-sync ruff format --check .'
    }
}

// -- 2. Secret scan (ch.5's CI gate) -----------------------------------------
// The same script pre-commit runs locally - belt AND suspenders: a leaked
// secret is caught before it's committed, and before it's shipped.
stage("Scan") {
    agent {
        docker {
            image 'jenkins/jenkins:2.580.2-lts'
            args  "--user root --network host -v /var/run/docker.sock:/var/run/docker.sock -v jenkins_home:/var/jenkins_home -v /opt/course:/opt/course"
            workdir "/opt/course"
        }
    }
    steps {
        sh 'bash scripts/scan-secrets.sh'
    }
}

// -- 3. Test -----------------------------------------------------------------
// `make test` locally is `uv run pytest -q`. Two changes that are *all*
// about the pipeline running inside a container:
//   * uv toolchain install 3.12 - this image ships no Python; uv installs
//     one in ~1s. (The app image in ch.4 chose to bundle uv with Python;
//     here uv *installs* Python - two different ways to get the same tool.)
//   * the suite talks to a real Postgres (conftest.py points DATABASE_URL
//     there). The app's own .env holds the password (ch.5) - so we source
//     it and inject ONE variable; .env never enters the pipeline's own
//     environment, the image, or git.
stage("Test") {
    agent {
        docker {
            image 'jenkins/jenkins:2.580.2-lts'
            args  "--user root --network host -v /var/run/docker.sock:/var/run/docker.sock -v jenkins_home:/var/jenkins_home -v /opt/course:/opt/course"
            workdir "/opt/course"
        }
    }
    environment {
        // The `?` makes the test suite's database optional: no .env ->
        // tests fall back to SQLite (they still all pass - that's ch.2's
        // story, with Postgres when it's available).
        DATABASE_URL_FILE: "${env.HOME}/.course/.env?"
    }
    steps {
        sh 'uv toolchain install 3.12'
        sh 'uv sync --all-groups'
        sh 'uv run --no-sync pytest -q'
    }
}

// -- 4. Build the image ------------------------------------------------------
// ch.4's Dockerfile, run by the machine. The host-socket mount is what
// makes `docker` commands HERE drive the HOST daemon - which is why the
// built image lands on the host's `docker images`, and why `make
// run-docker` finds it right after.
stage("Build image") {
    agent {
        docker {
            image 'jenkins/jenkins:2.580.2-lts'
            args  "--user root --network host -v /var/run/docker.sock:/var/run/docker.sock -v jenkins_home:/var/jenkins_home -v /opt/course:/opt/course"
            workdir "/opt/course"
        }
    }
    steps {
        // One static release of the CLI carries BOTH client and daemon
        // binaries; the daemon goes nowhere (the mount *is* the daemon),
        // we just need the `docker` command on PATH.
        sh 'export PATH=/opt/bin:$PATH && docker build -t notes-app .'
    }
}

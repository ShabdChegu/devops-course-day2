// ch.7 - the course's CI pipeline: lint -> scan -> test -> build the image.
//
// WHERE does this run? `node` = the CONTROLLER itself - the jenkins service
// in docker-compose.yml (course-jenkins = stock Jenkins + uv + the docker
// CLI). No agent, no DinD: the controller's docker CLI reaches the HOST
// daemon through the socket mount (docs/07-jenkins-ci.md pitfall #1).
// One bridge, one line to explain.
//
// The poll trigger lives in the JOB's config (the one-time UI setup,
// docs/07 "Try it yourself"): Poll SCM, H/5. Push a commit to the watched
// branch and a build fires within ~5 min - no Build button. Local edits
// do NOT fire it; the poller compares the branch tip on the remote.

node {
    stage('Checkout') {
        // `scm` = the git source configured on the job (the repo URL +
        // branch, set up in the UI). The git plugin does the fetch; the
        // workspace lives under JENKINS_HOME (the jenkins_home volume),
        // so it (and the .venv Lint creates) survives between builds.
        checkout scm
        sh 'git log --oneline -1'
    }

    stage('Lint') {
        // Exactly `make lint`, in the controller. Two pinning habits
        // instead of "whatever uv picks":
        //   uv python install 3.12   -> the same interpreter as the app
        //       image (ch.4) and the lockfile - otherwise uv's "latest"
        //       (today 3.15, tomorrow 3.16?) would drift the class.
        //   --python 3.12            -> the venv is built on THAT
        // uv sync --all-groups creates the .venv + pulls the dev group
        // (ruff); it caches under $HOME, so build #2 onward skips most of
        // this. --no-sync keeps each `uv run` from re-resolving.
        sh '''
            uv python install 3.12
            uv sync --all-groups --python 3.12
            uv run --no-sync ruff check .
            uv run --no-sync ruff format --check .
        '''
    }

    stage('Scan') {
        // ch.5's belt + suspenders: the SAME script your pre-commit hook
        // runs. A secret that slips past pre-commit is caught here, before
        // it ships.
        sh 'bash scripts/scan-secrets.sh'
    }

    stage('Test') {
        // `make test`, in the controller. Self-contained on purpose:
        // conftest.py pins a temp SQLite DB, so no Postgres service and
        // no .env (the app's Postgres password, ch.5's secrets story)
        // ever touches the pipeline.
        sh 'uv run --no-sync pytest -q'
    }

    stage('Build image') {
        // ch.4's Dockerfile, driven by the machine. This `docker` is the
        // HOST's - through the socket mount - so the image lands on the
        // host's `docker images`; the next `make up` / `make run-docker`
        // finds it.
        sh 'docker build -t notes-app .'
    }

    echo "CI green - notes-app:latest rebuilt on the host. ch.8 adds a Deploy stage that ships it."
}

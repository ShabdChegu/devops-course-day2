// ch.7 - the course's CI pipeline: lint -> scan -> test -> build -> image gate -> push.
//
// WHERE does this run? `node` = the CONTROLLER itself - the jenkins service
// in docker-compose.yml (course-jenkins = stock Jenkins + uv + the docker
// CLI + trivy). No agent, no DinD: the controller's docker CLI reaches the
// HOST daemon through the socket mount (docs/07-jenkins-ci.md pitfall #1).
// One bridge, one line to explain.
//
// The poll trigger is OWNED BY THIS FILE, not the UI: on the first
// successful build the `properties` step writes Poll SCM (H/5) into the
// job. After that, a push to the watched branch fires a build within
// ~5 min - no Build button, no UI. (Local edits don't fire it: the
// poller compares the branch tip on the remote, not your disk.)
properties([
    pipelineTriggers([pollSCM('H/5 * * * *')])
])
options {
    // A poll can fire while a build is already running - and two `docker
    // build`s racing on the same host daemon through the socket is a mess.
    // Queue instead of overlap.
    disableConcurrentBuilds()
    // A hung build would sit holding the poller; cap the whole run.
    // 20 min, not 10: a COLD first build downloads Trivy's vuln DB
    // (~GB, one-time) on top of everything else.
    timeout(time: 20, unit: 'MINUTES')
}

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

    stage('Scan image (Trivy)') {
        // The repo was scanned for secrets; nobody had checked the image
        // we just built. Trivy gates the built image before it ships.
        //
        // Same socket gotcha as the Build stage, with a twist: the socket
        // mount gives the CLI the daemon - but Trivy is NOT the CLI, it
        // runs its OWN scanner, which has its OWN (empty) image store.
        // `trivy image notes-app` looks for the image in THAT store and
        // simply does not find it. The bridge is one line: export the
        // image (via the host CLI) to a tarball and hand Trivy the tar -
        // it reads layer metadata on its own, no second daemon, no DinD.
        //
        // The gate is scoped to the libs WE ship (--pkg-types library),
        // not the whole OS: the uv base image carries ~2000 unfixed OS
        // CVEs of its own, and a full-image HIGH/CRITICAL gate would be
        // red on every single build - a gate that never goes green
        // teaches "turn it off". What a commit IS responsible for: the
        // dependencies it ships.
        //
        // --exit-code 1 is the whole reason the flag exists: without it
        // (or with 0) Trivy always exits 0 even when findings match -
        // the scan would report and the gate would not.
        //
        // First run: Trivy auto-downloads its vuln DB (~GB) before
        // scanning - a few extra minutes ONCE; it then lives in
        // TRIVY_HOME on the jenkins_home volume, so later builds are
        // seconds.
        sh '''
            docker save notes-app -o /tmp/notes-app.tar
            trivy image --input /tmp/notes-app.tar --pkg-types library --severity CRITICAL --exit-code 1
            rm -f /tmp/notes-app.tar
        '''
    }

    stage('Push to Docker Hub') {
        // ch.5's secrets story, continued: the registry password lives in
        // neither the repo, the image, nor the log.
        //   - One-time UI step (like the plugins): Credentials > System >
        //     Global credentials > docker-hub, Username/Password, your
        //     free Docker Hub account.
        //   - withCredentials injects it as env vars ONLY inside this
        //     block and masks the value in the console.
        //   - --password-stdin keeps the password off the command line
        //     (visible in `ps` otherwise).
        // Tags: one image per build - "notes-app:14" is build #14's
        // commit, forever - plus a moving `latest` for ch.8's deploy,
        // plus the git SHA itself (env.GIT_COMMIT, set by `checkout scm`):
        // "which commit is running in production?" becomes a lookup, not a
        // forensics session.
        withCredentials([usernamePassword(credentialsId: 'docker-hub',
                      usernameVariable: 'HUB_USER', passwordVariable: 'HUB_PASS')]) {
            sh '''
                echo "$HUB_PASS" | docker login -u "$HUB_USER" --password-stdin
                # The `sh` step runs in /bin/sh - dash in the Jenkins image,
                # not bash: ${GIT_COMMIT:0:7} would die "Bad substitution".
                # printf %.7s is the POSIX form of the same 7-char tag.
                SHA7="$(printf "%.7s" "$GIT_COMMIT")"
                docker tag  notes-app:latest "$HUB_USER/notes-app:$BUILD_NUMBER"
                docker tag  notes-app:latest "$HUB_USER/notes-app:$SHA7"
                docker tag  notes-app:latest "$HUB_USER/notes-app:latest"
                docker push "$HUB_USER/notes-app:$BUILD_NUMBER"
                docker push "$HUB_USER/notes-app:$SHA7"
                docker push "$HUB_USER/notes-app:latest"
            '''
        }
    }

    // `post` = lifecycle hooks that run after the body, whatever its
    // outcome. Three hooks, three honest jobs:
    //   success - the one-line receipt (what's now on Docker Hub, where).
    //   always  - sweep dangling images. Every `docker build` re-tags
    //             notes-app:latest, orphaning the previous one; without
    //             this the host store fills up a 1.7GB image per build.
    //             (Only dangling - it can never touch a tagged image.)
    //   failed  - the honest note: a red build pushes NOTHING, so
    //             Docker Hub's `latest` still points at the last green
    //             build. That's a feature, not a bug - ch.8's deploy
    //             only ever pulls a passing artifact.
    post {
        success {
            // `env.GIT_COMMIT` = the SHA `checkout scm` just ran (the git
            // plugin puts it in the build's environment). substring is the
            // Groovy 7-char tag - no shell involved, so no dash-port
            // ${VAR:0:7} to trip over here. (The Push stage still uses the
            // printf form, because there the SHA only exists as a *sh* var.)
            echo "shipped: notes-app:${env.BUILD_NUMBER} + ${env.GIT_COMMIT?.substring(0, 7)} + latest on Docker Hub."
        }
        always {
            sh 'docker image prune -f'
        }
        failed {
            echo "CI red - nothing was pushed. Docker Hub's latest still points at the last green build."
        }
    }

    echo "CI green - notes-app:latest rebuilt on the host and pushed to Docker Hub. ch.8's Deploy stage pulls it on the server."
}

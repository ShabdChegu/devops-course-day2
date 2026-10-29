# ch.7 - the course's Jenkins CONTROLLER image.
#
# Base: stock jenkins/jenkins LTS (the real Jenkins, unchanged). We add the
# two things the pipeline's stages need that the stock image does not ship:
#   * uv            -> the lint + test stages run `uv sync` / `uv run`
#   * docker CLI    -> the build stage drives the HOST's docker daemon
#                      through the socket mount (the ch.7 gotcha, docs/07 #1)
#
# The plugin families (git, pipeline) are NOT in here: on your FIRST run
# you install them through the UI - that one manual step is where you learn
# what a plugin, a job, and a poll trigger actually are (docs/07 "Try it
# yourself"). The named jenkins_home volume is what makes that first run
# the ONLY manual run: everything you set up then persists in the volume,
# so every later `make pipeline` boots a Jenkins that already works.

# Pin the LTS release a fresh machine will pull: the whole class builds the
# same controller. (Re-check the tag against https://www.jenkins.io/ when
# the course is re-audited - not per session.)
FROM jenkins/jenkins:2.580.2-lts

# The stock image's default user is the unprivileged `jenkins` account, and
# buildkit runs our layers as whatever USER the image declares - so the
# root-only steps below would fail "Permission denied" without this switch.
# compose runs the container as root anyway (the host's docker socket
# requires it; docs/07 pitfall #5 says so out loud).
USER root

# Pinned, not `latest` - a course the class runs in lockstep must not
# drift its toolchain under its own feet.
ARG UV_VERSION=0.13.6
ARG DOCKER_VERSION=28.5.0

# No apt layer: the image already ships curl + the CA bundle + git.
# (The first draft of this file apt-installed ca-certificates and failed -
# worth remembering: image defaults beat install scripts.)
#
# uv: the same tool the app's venv uses (ch.1) - one toolchain for the
# whole course. The versioned install.sh pins the release, not "latest".
RUN curl -fsSL "https://astral.sh/uv/${UV_VERSION}/install.sh" | sh && \
    ln -sf "/root/.local/bin/uv" /usr/local/bin/uv && \
    uv --version

# docker CLI: one static release carries BOTH client and daemon binaries.
# Only the client matters here - the "daemon" is the host's, reached
# through /var/run/docker.sock (DinD would embed a *second* daemon; docs/07
# pitfall #1 covers the difference). Build-time per-arch pick so M-series
# Macs and x86 Linux both get a working binary.
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        amd64) target=x86_64 ;; \
        arm64) target=aarch64 ;; \
        *) echo "unsupported arch: $arch"; exit 1 ;; \
    esac; \
    # the static tarball holds a docker/ DIR (client + daemon binaries). Only
    # the client is wanted: the daemon is the host's, reached through the
    # socket mount. Symlink the client onto PATH and stop there.
    curl -fsSL "https://download.docker.com/linux/static/stable/${target}/docker-${DOCKER_VERSION}.tgz" -o /tmp/docker.tgz; \
    tar -xzf /tmp/docker.tgz -C /opt/; \
    ln -sf /opt/docker/docker /usr/local/bin/docker; \
    rm /tmp/docker.tgz; \
    /usr/local/bin/docker --version

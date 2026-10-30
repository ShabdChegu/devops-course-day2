# ch.7 - the course's Jenkins CONTROLLER image.
#
# Base: stock jenkins/jenkins LTS (the real Jenkins, unchanged). We add the
# three things the pipeline's stages need that the stock image does not ship:
#   * uv            -> the lint + test stages run `uv sync` / `uv run`
#   * docker CLI    -> the build stage drives the HOST's docker daemon
#                      through the socket mount (the ch.7 gotcha, docs/07 #1)
#   * trivy         -> the image-scan stage gates the built image: `docker
#                      save` exports it to a tar, trivy reads the tar
#                      (it has its own empty store, not the host's)
#   * docker compose-> the v2 CLI *plugin* (separate binary the CLI discovers
#                      in a cli-plugins dir). ch.8's CD dry-run target
#                      (SERVER_HOST=127.0.0.1) runs `docker compose` INSIDE
#                      the controller to point the app stack at the pushed
#                      tag - so the plugin must ship in this image
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
ARG TRIVY_VERSION=0.76.1
ARG COMPOSE_VERSION=5.6.1

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

# docker compose (v2 plugin): ch.8's local dry-run runs `docker compose` in
# the CONTROLLER (SERVER_HOST=127.0.0.1 - deploy.sh points the app stack at
# the pushed tag, the box pulls nothing), so the v2 binary must be in this
# image: `docker compose` is just the docker CLI + a discovered plugin
# binary - one file, no daemon, no service.
#
# The asset is a PER-ARCH STATIC BINARY (docker-compose-linux-<arch>),
# NOT the per-distro .deb - a .deb would pin this image to one distro,
# and a static binary next to the docker CLI is how Docker ships the
# plugin itself. Same per-arch pick as the docker CLI block: amd64
# (x86_64) for the class's Linux boxes, aarch64 for M-series Macs
# running Docker's buildkit linux/arm64.
#
# Where it goes: /usr/local/lib/docker/cli-plugins/ - the docker CLI
# searches that dir (and /usr/lib/docker/cli-plugins) for plugins by
# NAME ("docker" + plugin-name = "docker compose"). chmod 755, because
# an unexecutable plugin binary is the #1 "docker: unknown command
# 'compose'" cause.
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        amd64) target=x86_64 ;; \
        arm64) target=aarch64 ;; \
        *) echo "unsupported arch: $arch"; exit 1 ;; \
    esac; \
    # The compose asset URL: docker/compose releases (the compose v2
    # repo), asset name "docker-compose-linux-${target}" - note the
    # release tag is VERSION-PREFICED in the path (v${VER}) but the
    # FILENAME is not, exactly like trivy's (docs/07 pitfall).
    curl -fsSL "https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-${target}" -o /usr/local/bin/docker-compose; \
    chmod +x /usr/local/bin/docker-compose; \
    mkdir -p /usr/local/lib/docker/cli-plugins; \
    ln -sf /usr/local/bin/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose; \
    /usr/local/bin/docker --version; \
    /usr/local/bin/docker compose version

# trivy: the image-scan stage (docs/07) gates the built image on
# CRITICAL CVEs in the libs we ship. One static binary, same per-arch
# pick as the docker CLI. Two gotchas live in that URL:
#   * arch names are trivy's own (64bit / ARM64), not docker's x86_64/aarch64
#   * the download path uses the release TAG, which is `v`-prefixed
#     (download/v${VER}/...) even though the asset FILENAME is not
#     (trivy_${VER}_...). Get the prefix wrong and you 404 mid-build.
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        amd64) target=64bit ;; \
        arm64) target=ARM64 ;; \
        *) echo "unsupported arch: $arch"; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${target}.tar.gz" -o /tmp/trivy.tar.gz; \
    tar -xzf /tmp/trivy.tar.gz -C /tmp/; \
    install -m 0755 /tmp/trivy /usr/local/bin/trivy; \
    rm /tmp/trivy.tar.gz; \
    /usr/local/bin/trivy --version

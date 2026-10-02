# debian-ai — OCI image for AI coding agents, based on Debian 13 (trixie) slim
FROM docker.io/debian:13-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=Etc/UTC

# --- Core tools (what the agent asked for) ---
#   python3, node (LTS, siehe unten), git, gh, wget, curl, dnsutils (dig),
#   iputils-ping (ping),
#   iproute2 (ss), gawk, findutils (find), mtr-tiny, time, coreutils (timeout), expect
# --- Agent essentials ---
#   ripgrep, jq, yq, less, file, tree, unzip, openssh-client, procps,
#   moreutils, make, strace, netcat-openbsd, socat, rsync.
#   Keine Editoren (Agents editieren nicht interaktiv).
# --- Compiler ---
#   build-essential (gcc, g++, libc-Header): Linker für Rust, cgo für Go,
#   native Erweiterungen bei pip und node-gyp, wenn es kein fertiges
#   Binary gibt. python3-dev dazu: ohne Python.h baut pip eine native
#   Erweiterung nicht, und viele Pakete fallen dann STILL auf ihre reine
#   Python-Variante zurück.
# --- Interaktives Terminal ---
#   ttyd + tmux, damit ein Mensch über den Browser in die Sandbox kann
#   (FeCode-Previews: Port-Forward auf ttyd).
#   tmux ist hier NICHT redundant — anders als beim Hintergrund-Exec, wo
#   nohup/& reicht: ttyd startet sein Kommando pro Verbindung neu, und die
#   WebSocket stirbt bei Pause/Resume. Ohne `tmux new -A` bekommt jeder
#   Reconnect eine frische Shell statt der Sitzung, die man verlassen hat.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      python3 python3-pip python3-venv python3-dev \
      git gh \
      curl wget \
      dnsutils iputils-ping iproute2 mtr-tiny traceroute \
      gawk findutils coreutils time expect \
      ripgrep jq less file tree unzip zip xz-utils \
      openssh-client rsync \
      procps moreutils \
      make strace \
      build-essential \
      netcat-openbsd socat \
      tmux \
    && rm -rf /var/lib/apt/lists/*

# NOTE: bewusst KEINE Container-Runtime (docker/podman) im Image —
# gemountete Sockets/Daemon-State beißen sich mit Sandbox-Pause/Resume
# (Firecracker-Snapshots).

# yq (mikefarah) — das "echte" yq, nicht der Debian-Wrapper
ARG TARGETARCH=amd64
RUN case "$TARGETARCH" in \
      amd64) YQ_ARCH=amd64 ;; \
      arm64) YQ_ARCH=arm64 ;; \
      *) echo "unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${YQ_ARCH}" \
       -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

# ttyd — in Debian nicht gepackt, daher das statische Upstream-Binary.
# Version gepinnt und Checksumme geprüft: das Ding bekommt später eine
# beschreibbare Shell zu sehen.
ARG TTYD_VERSION=1.7.7
RUN case "$TARGETARCH" in \
      amd64) TTYD_ARCH=x86_64; TTYD_SHA=8a217c968aba172e0dbf3f34447218dc015bc4d5e59bf51db2f2cd12b7be4f55 ;; \
      arm64) TTYD_ARCH=aarch64; TTYD_SHA=b38acadd89d1d396a0f5649aa52c539edbad07f4bc7348b27b4f4b7219dd4165 ;; \
      *) echo "unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${TTYD_ARCH}" \
       -o /usr/local/bin/ttyd \
    && echo "${TTYD_SHA}  /usr/local/bin/ttyd" | sha256sum -c - \
    && chmod +x /usr/local/bin/ttyd \
    && ttyd --version

# Node.js — offizielles Upstream-Tarball (Debian trixie hat kein nodejs im
# slim-Set, und wir wollen die LTS, nicht was die Distribution mitbringt).
# Version gepinnt, Checksumme geprüft. Braucht es, damit ein Agent einen
# Dev-Server (Vite & Co.) in der Sandbox starten kann.
ARG NODE_VERSION=24.21.0
RUN case "$TARGETARCH" in \
      amd64) NODE_ARCH=x64;   NODE_SHA=fd8e59d5a511510f6a298afb548f18c7d2b1be404d8b4a27d94fbe49f56cb2d6 ;; \
      arm64) NODE_ARCH=arm64; NODE_SHA=6ad1325edbdb5649c379b75a237147a666c95d4f9ae8d340fef2d1575d289ad2 ;; \
      *) echo "unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" \
       -o /tmp/node.tar.xz \
    && echo "${NODE_SHA}  /tmp/node.tar.xz" | sha256sum -c - \
    && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
         --exclude=CHANGELOG.md --exclude=LICENSE --exclude=README.md \
    && rm /tmp/node.tar.xz \
    && corepack enable \
    && node --version && npm --version

# Go — offizielles Tarball, Version gepinnt, Checksumme geprüft (Debian
# trixie hat 1.24, wir wollen das aktuelle Release). GOPATH bleibt der
# Default /root/go; dessen bin/ steht im PATH, damit `go install`-Tools
# direkt aufrufbar sind.
ARG GO_VERSION=1.27.1
RUN case "$TARGETARCH" in \
      amd64) GO_SHA=63d339f0da5ab53635a56f2490a7984dfe12dfcff22ad749f63edaf590168445 ;; \
      arm64) GO_SHA=3450b45a3f9ee8568792736a5c5e70a1f2e9b36c35a8f74958c03e51d7d92bec ;; \
      *) echo "unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz" -o /tmp/go.tar.gz \
    && echo "${GO_SHA}  /tmp/go.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/go.tar.gz -C /usr/local \
    && rm /tmp/go.tar.gz
ENV PATH=/usr/local/go/bin:/root/go/bin:$PATH
RUN go version

# Rust — über rustup, nicht das Debian-Paket: trixie hat rustc 1.85, viele
# aktuelle Crates verlangen mehr, und nur rustup respektiert die
# rust-toolchain.toml eines Projekts (holt die Version beim ersten cargo
# selbst). Aufbau wie im offiziellen rust-Image: rustup-init gepinnt +
# Checksumme, eine feste stabile Toolchain im Profil minimal plus clippy
# und rustfmt, RUSTUP_HOME/CARGO_HOME unter /usr/local.
# RUSTUP_UNPACK_RAM: rustup puffert beim Entpacken einer Toolchain bis zu
# 500 MiB — in einer Sandbox mit 512 MiB hat der OOM-Killer das Nachladen
# aus einer rust-toolchain.toml mittendrin beendet und eine halbe
# Toolchain hinterlassen. Mit 100 MB: 1.98.0 in ~16 s, maxrss ~210 MB.
ARG RUSTUP_VERSION=1.29.1
ARG RUST_VERSION=1.99.0
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    RUSTUP_UNPACK_RAM=100000000 \
    PATH=/usr/local/cargo/bin:$PATH
RUN case "$TARGETARCH" in \
      amd64) RUST_ARCH=x86_64-unknown-linux-gnu;  RUSTUP_SHA=dda7234360b7f578ca8b0ddcb80145646fa61a67c1720a5abc7051b35c9fcb71 ;; \
      arm64) RUST_ARCH=aarch64-unknown-linux-gnu; RUSTUP_SHA=15f6e4ce9f583b929c996c91562bad6d4454f3281de858b02cdfdef615fac433 ;; \
      *) echo "unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "https://static.rust-lang.org/rustup/archive/${RUSTUP_VERSION}/${RUST_ARCH}/rustup-init" \
       -o /tmp/rustup-init \
    && echo "${RUSTUP_SHA}  /tmp/rustup-init" | sha256sum -c - \
    && chmod +x /tmp/rustup-init \
    && /tmp/rustup-init -y --no-modify-path --profile minimal \
         --default-toolchain "${RUST_VERSION}" --component clippy,rustfmt \
    && rm /tmp/rustup-init \
    && rustup --version && cargo --version && rustc --version

# Headless-Browser: Playwright (Node) mit genau dem Chromium, auf das diese
# Playwright-Version gepinnt ist — nur die Headless-Shell, kein volles
# Chromium, kein Firefox/WebKit. Version gepinnt: Bibliothek und Browser
# gehören zusammen; ein Projekt mit einer anderen Playwright-Version muss
# sich seinen Browser selbst holen (`npx playwright install chromium`).
# --with-deps zieht die System-Libraries und Schriften (ohne Schriften:
# Kästchen statt Text auf Screenshots).
# /node_modules → globale Module: Node löst require() UND import vom
# Dateisystem-Root aus auf, damit findet jedes Skript irgendwo in der
# Sandbox `playwright`, ohne npm install und ohne NODE_PATH (das ESM
# ignoriert). Ein Projekt mit eigenem node_modules gewinnt, weil näher.
ARG PLAYWRIGHT_VERSION=1.63.0
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
RUN npm install -g "playwright@${PLAYWRIGHT_VERSION}" \
    && playwright install --with-deps --only-shell chromium \
    && ln -s /usr/local/lib/node_modules /node_modules \
    && rm -rf /var/lib/apt/lists/* /root/.npm /tmp/* \
    && playwright --version

LABEL org.opencontainers.image.source="https://github.com/MalteJ/debian-ai" \
      org.opencontainers.image.description="Debian 13 slim based OCI image with tooling for AI agents" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /workspace
CMD ["/bin/bash"]

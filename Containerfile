# debian-ai — OCI image for AI coding agents, based on Debian 13 (trixie) slim
FROM docker.io/debian:13-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=Etc/UTC

# --- Core tools (what the agent asked for) ---
#   python3, git, gh, wget, curl, dnsutils (dig), iputils-ping (ping),
#   iproute2 (ss), gawk, findutils (find), mtr-tiny, time, coreutils (timeout), expect
# --- Agent essentials ---
#   ripgrep, jq, yq, less, file, tree, unzip, openssh-client, procps,
#   moreutils, tmux, nano, vim-tiny, make, strace, netcat-openbsd, socat, rsync
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      python3 python3-pip python3-venv \
      git gh \
      curl wget \
      dnsutils iputils-ping iproute2 mtr-tiny traceroute \
      gawk findutils coreutils time expect \
      ripgrep jq less file tree unzip zip \
      openssh-client rsync \
      procps moreutils \
      tmux nano vim-tiny \
      make strace \
      netcat-openbsd socat \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/bin/vim.tiny /usr/local/bin/vim

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

LABEL org.opencontainers.image.source="https://github.com/MalteJ/debian-ai" \
      org.opencontainers.image.description="Debian 13 slim based OCI image with tooling for AI agents" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /workspace
CMD ["/bin/bash"]

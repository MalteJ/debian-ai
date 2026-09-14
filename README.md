# debian-ai

OCI-Image für AI-Coding-Agents, basierend auf `debian:13-slim`.

Gebaut via GitHub Actions (public runner, multi-arch amd64+arm64) und
gepublished als `ghcr.io/maltej/debian-ai`.

## Enthaltene Tools

- **Sprachen/Runtime:** python3 (+pip/venv)
- **VCS:** git, gh (GitHub CLI)
- **HTTP/Download:** curl, wget
- **Netz:** dig (dnsutils), ping (iputils), ss (iproute2), mtr-tiny,
  traceroute, netcat-openbsd, socat
- **Text/Data:** gawk, ripgrep, jq, yq (mikefarah), less, file, tree,
  moreutils
- **Dateien/Transfer:** unzip, zip, rsync, openssh-client
- **Prozess/Terminal:** procps, time, timeout (coreutils), expect, tmux,
  strace
- **Build:** make
- (keine Editoren — Agents editieren nicht interaktiv)

**Bewusst NICHT enthalten:** Container-Runtimes (docker/podman) — gemountete
Sockets und Daemon-State beißen sich mit Sandbox-Pause/Resume
(Firecracker-Snapshots).

## Verwendung

```bash
docker run --rm -it -v "$PWD":/workspace ghcr.io/maltej/debian-ai
```

(Standard-Workingdir im Image ist `/workspace`.)

### Mit SSH-Keys für git+ssh

```bash
docker run --rm -it \
  -v "$HOME/.ssh":/root/.ssh:ro \
  -v "$PWD":/workspace \
  ghcr.io/maltej/debian-ai
```

## Lokal bauen

```bash
make build   # docker buildx build --load
make run     # interaktive Shell im Image
```

## CI

`.github/workflows/build.yaml` — baut auf public runnern (`ubuntu-latest`)
bei jedem Push auf `main`, bei Tags `v*` (semver-Tag wird Image-Tag) und
wöchentlich (Base-Image-Updates), pushed nach ghcr.io.

Nach dem ersten Push das Package auf GitHub in den Package-Settings mit dem
Repo verknüpfen und ggf. auf **public** stellen.

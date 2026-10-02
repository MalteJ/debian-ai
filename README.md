# debian-ai

OCI-Image für AI-Coding-Agents, basierend auf `debian:13-slim`.

Gebaut via GitHub Actions (public runner, nur linux/amd64 — die
Sandboxes laufen auf x86_64-Nodes) und gepublished als
`ghcr.io/maltej/debian-ai`.

## Enthaltene Tools

- **Sprachen/Runtime:** python3 (+pip/venv), Node.js 24 LTS (offizielles
  Tarball, gepinnt + Checksumme; npm und corepack aktiviert) — damit ein
  Agent einen Dev-Server in der Sandbox starten kann
- **VCS:** git, gh (GitHub CLI)
- **HTTP/Download:** curl, wget
- **Netz:** dig (dnsutils), ping (iputils), ss (iproute2), mtr-tiny,
  traceroute, netcat-openbsd, socat
- **Text/Data:** gawk, ripgrep, jq, yq (mikefarah), less, file, tree,
  moreutils
- **Dateien/Transfer:** unzip, zip, xz-utils, rsync, openssh-client
- **Prozess/Terminal:** procps, time, timeout (coreutils), expect, strace
- **Interaktives Terminal:** ttyd (statisches Upstream-Binary, gepinnt +
  Checksumme) und tmux — ein Mensch kann über einen Port-Forward im Browser
  in die Sandbox. Start:
  `ttyd -W -O -p 7681 tmux new -A -s main`
- **Build:** make
- **Headless-Browser:** Playwright für Node (gepinnt, `PLAYWRIGHT_VERSION`)
  mit genau seinem Chromium, nur die Headless-Shell, unter
  `PLAYWRIGHT_BROWSERS_PATH=/ms-playwright`; System-Libraries und
  Schriften (inkl. CJK und Emoji) über `playwright install --with-deps`.
  `playwright screenshot --viewport-size=1280,720 <url> shot.png` geht
  direkt, und Skripte finden `playwright` von überall per `require` und
  `import` (`/node_modules` zeigt auf die globalen Module). Ein Projekt
  mit einer anderen Playwright-Version holt sich seinen Browser selbst
  (`npx playwright install chromium`). Kostet ~630 MB Image-Größe, gut
  200 davon Mesa/LLVM, die `libgbm` unter Debian mitbringt.
- (keine Editoren — Agents editieren nicht interaktiv. Hintergrund-Prozesse
  weiterhin via `nohup … &` + Logfile, TTY-Automation via `expect`; tmux ist
  nur für das interaktive Terminal da, weil ttyd sein Kommando pro Verbindung
  neu startet und die WebSocket bei Pause/Resume stirbt)

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

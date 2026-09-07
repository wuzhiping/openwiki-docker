```
  openwiki:
    image: shawoo/openwiki
    user: root
    ports:
      - "4321:4321"
    volumes:
      #- ./server.js:/opt/openwiki/dist/visualize/server.js
      - ./workspace:/workspace
    environment:
      HOME: "/workspace/home"
    command: visualize home  --port 4321 --no-open
```


# openwiki-docker

Docker packaging for [OpenWiki](https://github.com/langchain-ai/openwiki) - the LangChain team's CLI that generates and maintains agent-facing wikis for codebases using a DeepAgents documentation agent.

**All credit for OpenWiki itself goes to [langchain-ai](https://github.com/langchain-ai/openwiki).** This repo just wraps it in a container: the upstream source is vendored as a git submodule (`openwiki-src/`) pinned to a release tag, built in a multi-stage image, and published to Docker Hub as [`deathnerd/openwiki`](https://hub.docker.com/r/deathnerd/openwiki). No patches, no forks - what you run is upstream OpenWiki.

## Quick start

Generate docs for the repo you're standing in:

```sh
docker run -it --rm \
  -v "$PWD":/workspace \
  -v openwiki-config:/home/openwiki/.openwiki \
  deathnerd/openwiki
```

- `-it` - OpenWiki is an interactive TUI (built with ink); it needs a TTY. First run walks you through provider/model/API-key onboarding.
- `-v "$PWD":/workspace` - the container works on whatever is mounted at `/workspace`. Generated docs land in `openwiki/` inside your repo.
- `-v openwiki-config:/home/openwiki/.openwiki` - persists your provider config and API keys (stored by OpenWiki in `~/.openwiki/.env`) across runs. Without it you'll re-onboard every run.

## Non-interactive use

One-shot runs work without onboarding if you provide provider config via environment variables. Pass keys through from your host environment rather than typing them into the command line:

```sh
export ANTHROPIC_API_KEY=...   # or use --env-file
docker run --rm \
  -v "$PWD":/workspace \
  -e OPENWIKI_PROVIDER=anthropic \
  -e ANTHROPIC_API_KEY \
  deathnerd/openwiki --update --print
```

Any provider OpenWiki supports (OpenAI, Anthropic, OpenRouter, OpenAI-compatible gateways, ...) configures the same way - see the [upstream README](https://github.com/langchain-ai/openwiki#customizing) for the full list of providers and environment variables.

All CLI arguments pass straight through to `openwiki`:

```sh
docker run -it --rm -v "$PWD":/workspace -v openwiki-config:/home/openwiki/.openwiki \
  deathnerd/openwiki -p "Summarize what you can do"
```

## Image details

| | |
|---|---|
| Base | `node:22-bookworm-slim` |
| User | `openwiki` (non-root, UID 1000) |
| Workdir | `/workspace` (mount your repo here) |
| Config | `/home/openwiki/.openwiki` (mount to persist) |
| Extras | `git` and `ripgrep` (OpenWiki's agent uses both) |
| Entrypoint | the `openwiki` CLI |
| Platforms | `linux/amd64`, `linux/arm64` |

Tags: version tags (e.g. `0.1.1`) are built from the upstream release tag of the same version - the submodule is pinned to that exact commit. `latest` points at the newest version tag.

### Notes and limitations

- **File ownership**: the container runs as UID 1000, which matches the default first user on most Linux hosts, so bind-mounted files stay yours. If your host UID differs, run with your own UID and a host-owned config directory instead of the named volume:

  ```sh
  mkdir -p ~/.openwiki
  docker run -it --rm \
    --user "$(id -u):$(id -g)" \
    -e HOME=/home/openwiki \
    -v ~/.openwiki:/home/openwiki/.openwiki \
    -v "$PWD":/workspace \
    deathnerd/openwiki
  ```

- **Personal mode / connectors**: OpenWiki's personal-brain mode with OAuth connectors (Gmail, Slack, Notion, X) expects a local browser and loopback callbacks. That's awkward inside a container; this image targets **code mode** (repository documentation). Use a native install for personal mode.
- **Scheduling**: upstream's macOS LaunchAgent schedules don't apply in a container. Schedule with cron/CI instead - upstream ships [CI examples](https://github.com/langchain-ai/openwiki/tree/main/examples) for exactly this.

## Shell wrapper

The installer sets up an `openwiki` shell function (fish, bash, or zsh) plus completions, so the container feels like a native install:

```sh
curl -fsSL https://raw.githubusercontent.com/InfiniteRoomLabs/langchain-ai-openwiki-docker/main/scripts/install.sh | sh
```

The wrapper mounts the current directory, persists config and the wiki at `~/.openwiki` on the host (plain files - open the wiki in Obsidian or grep it), forwards provider env vars (`OPENWIKI_*`, `ANTHROPIC_*`, `OPENAI_*`, `OPENROUTER_*`, `LANGSMITH_*`, `TAVILY_*`, `BASETEN_*`, `FIREWORKS_*`), allocates a TTY only when you're at one, and pins the image by digest resolved at install time. After a new release, `openwiki-setup update` re-resolves the pin; `openwiki-setup uninstall` removes everything (`~/.openwiki` is kept). It assumes host UID 1000; for other UIDs use the explicit `--user` invocation from the notes above.

Extra container args (e.g. read-only source mounts for personal mode) go in `OPENWIKI_DOCKER_ARGS`:

```sh
export OPENWIKI_DOCKER_ARGS="-v $HOME/notes:/sources/notes:ro"
```

For scheduled wiki refreshes on Linux (upstream's scheduler is macOS-only), `openwiki-setup schedule [--time HH:MM]` installs a systemd user timer that runs `personal --update --print` daily with your source mounts and digest pin baked in; `openwiki-setup unschedule` removes it. Re-run `schedule` after `update` or after changing mounts.

## Building locally

```sh
git clone --recurse-submodules https://github.com/InfiniteRoomLabs/langchain-ai-openwiki-docker.git
cd langchain-ai-openwiki-docker
docker build -t openwiki:local .
```

Releases are cut by tagging: a `vX.Y.Z` tag matching the upstream version pinned in the submodule triggers the publish workflow (multi-arch, Docker Hub + ghcr.io). Pushing `main` only runs a build check. Maintainers: see [CLAUDE.md](https://github.com/InfiniteRoomLabs/langchain-ai-openwiki-docker/blob/main/CLAUDE.md) for the release process.

## License

OpenWiki is [MIT-licensed](https://github.com/langchain-ai/openwiki/blob/main/LICENSE) by its authors; the upstream license also ships inside the image at `/opt/openwiki/LICENSE`. The packaging files in this repo (Dockerfile, workflow, this README) are MIT as well - see [LICENSE](https://github.com/InfiniteRoomLabs/langchain-ai-openwiki-docker/blob/main/LICENSE).

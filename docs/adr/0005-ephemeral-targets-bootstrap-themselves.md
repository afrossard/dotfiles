# Ephemeral targets bootstrap themselves at start, never at build

A devcontainer gets this repo's config by cloning it and applying it when the container starts, never by having it baked into an image layer.
Where the platform offers to do the cloning, we let it.
Where no platform is involved, the image declares an entrypoint that does the same thing.

## Considered options

Baking the config into the image with `RUN chezmoi init --apply` was chosen first and then abandoned on evidence.
A `RUN` layer's cache key is its command string and its parent layer, and a new commit in this repo changes neither, so Docker serves the cached layer forever.
This was measured: a rebuild of an image whose `RUN` line recorded a timestamp reported `CACHED` and returned the original timestamp, while the container's start time advanced.
`docker compose --build` does not help; only `--no-cache` does, and nobody types that.
An image that bakes config would therefore freeze it on the day the layer was first built, which is the exact failure this redesign exists to end.
Baking also puts configuration inside tool installation, the smearing that ADR-0001 set out to stop.

Bind-mounting the Mac's source directory into the container was rejected because the compose file is invoked from inside the devcontainer under docker-outside-of-docker, where container paths and host paths do not agree.

## Consequences

- For anything VS Code or Codespaces launches, the whole mechanism is one **user** setting, `dotfiles.repository`. The platform clones this repo to `~/dotfiles` and runs its install script. No sibling repo needs to change.
- The install script is generated, not written: `chezmoi generate install.sh`. It is non-interactive, and it derives the source directory from its own location rather than from configuration, which is ADR-0002's rule applied to the installer. It is committed, and listed in `.chezmoiignore` so it is never applied into `$HOME`.
- For containers no platform launches, such as `actual-budget-transformer`'s `claude` compose service, the image installs the chezmoi binary at build time (a tool, so the image's job) and declares an entrypoint that runs `chezmoi init --apply` at start (config, so this repo's job) before `exec`ing the real command.
- **This repo must remain public.** The container bootstrap clones over HTTPS with no credentials. Combined with the finding that the repo holds no secrets, this is now an invariant rather than a convenience: anything committed here is world-readable forever.
- Every container start makes a network fetch. If GitHub is unreachable the container starts without config, which under ADR-0002 presents as missing features rather than an error.
- An ephemeral target may nonetheless mount a durable volume. The `claude` service mounts one at `~/.claude`. Applying on every start keeps such a directory from accumulating stale config.

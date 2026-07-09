# This repo holds config only

Four sibling repos (`homelab-kube`, `homelab-etl`, `homelab-fun`, `actual-budget-transformer`) each hand-copy a near-identical devcontainer setup, and they have drifted: four different pinned `uv` versions, two shells, Starship in only two of them.
The obvious fix is to hoist the shared Containerfile here, but a repo's scope is bounded by its name, so this repo owns home-directory user configuration and nothing else.
A shared devcontainer base image is real and needed, and it gets its own repo.

## Consequences

- Tool installation (`brew`, `apt`, `uv`) is out of scope here. A config file cannot install `kubectl`.
- Editor GUI state is out of scope. This is also why `private_Library/Application Support/Code/User/settings.json` drifted so far from reality: it never belonged here, and applications that rewrite their own settings atomically would destroy a symlink anyway.
- Sharing VS Code extension lists across repos is deferred, not rejected.

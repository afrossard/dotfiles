# This repo holds config only

Four sibling repos (`homelab-kube`, `homelab-etl`, `homelab-fun`, `actual-budget-transformer`) each hand-copy a near-identical devcontainer setup, and they have drifted: four different pinned `uv` versions, two shells, Starship in only two of them.
The obvious fix is to hoist the shared Containerfile here, but a repo's scope is bounded by its name, so this repo owns home-directory user configuration and nothing else.
A shared devcontainer base image is real and needed, and it gets its own repo.

## Consequences

- Tool installation (`brew`, `apt`, `uv`) is out of scope here. A config file cannot install `kubectl`.
- Machine provisioning is out of scope for the same reason, and by the same rule that sent the base image elsewhere. `chromebook/etc/gtk-3.0/settings.ini` is system configuration, not home-directory user configuration, so it was never a dotfile. The two `sommelier` systemd drop-ins genuinely are dotfiles, but they are inert data that Crostini alone reads, and ADR-0002's run-time detection cannot help a file that never executes. Both leave this repo. They belong to a machine-provisioning repo, which does not yet exist and need not exist until the Chromebook is next rebuilt. `homelab-fun` is not that repo, whatever its `machine_provisioning/` directory suggests, because a Chromebook is not a homelab node. The files and the open question they carry are archived in issue #11.
- Editor GUI state is out of scope. This is also why `private_Library/private_Application Support/private_Code/User/settings.json` drifted so far from reality: it never belonged here, and applications that rewrite their own settings atomically would destroy a symlink anyway.
- Sharing VS Code extension lists across repos is deferred, not rejected.
- Managing application-rewritten settings is likewise deferred, not rejected. It covers at least `~/.claude/settings.json` and VS Code's `settings.json`. Managing them naively is worse than not managing them: under ADR-0003's file mode, every `/model` or `/config` would register as an uncaptured edit, leaving the prompt's drift indicator permanently lit until it was ignored. The mechanism when we come to it is a chezmoi `modify_` script, which receives the current target on stdin and writes the new contents to stdout, so chezmoi can own a few keys and leave the application's own writes alone. Archived, with the deleted VS Code settings inline, in issue #12.

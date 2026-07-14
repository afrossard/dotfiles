# zsh on every target, and this repo ships no bash

Two sibling repos ran zsh and two ran bash, which is why `alias ll='ls -al'` exists in seven separate files across the estate and why parallel `.bash_aliases` and `.zsh_aliases` had to be maintained.
We standardise on zsh on every target and ship a single `dot_zshrc`.

## Considered options

Factoring the portable parts into a POSIX `sh` fragment sourced by both `.zshrc` and `.bashrc` was the alternative, and it was rejected as solving a problem that turned out not to exist.
The only apparent bash target left in the estate was `homelab-fun/machine_provisioning/usb_provisioning/raspi-custom-img/.bash_aliases`, and it is dead code: the sole reference to a file of that name anywhere in that repo points at a different copy under `.devcontainer/`.
With no bash target surviving, a two-shell abstraction would have had one implementation.

## Consequences

- The base-image repo must install zsh, `chsh -s /bin/zsh`, and append `brew shellenv` to `/etc/zsh/zshenv`. That last is not optional. `~/.zshrc` is read only by interactive shells, and `docker exec -it claude-code zsh -lc claude` is a non-interactive login shell, so without it Homebrew leaves `PATH` for every tool an agent spawns. `actual-budget-transformer` discovered this; `homelab-kube` runs zsh without the fix and still carries the bug.
- This repo is now dictating a shell, which ADR-0001 says belongs to the base image. Accepted deliberately, because the alternative was an abstraction with a single implementation.
- A container built from an image that has no zsh receives no shell configuration. This is consistent with ADR-0002: detection no-ops, a missing feature rather than an error.
- The Chromebook must have zsh installed before it is a useful target.

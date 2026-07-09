# Run-time detection over render-time templating

Config must behave differently on macOS and inside Linux devcontainers, chiefly because Homebrew lives at `/opt/homebrew` on one and `/home/linuxbrew/.linuxbrew` on the other, and because the 1Password SSH agent socket exists only on the Mac.
We ship one byte-identical file to every target and let it probe its environment as it executes, rather than rendering a per-target file beforehand.

## Considered options

Render-time templating (chezmoi `.tmpl` files driven by `.chezmoi.toml`) was the incumbent, in name at least.
It produces a concrete rendered file that is easy to inspect, but it requires a binary and a per-machine state file to exist on every target *before that target has a working shell*, plus a render step the user must remember to re-run.

## Consequences

- The repo has no concept of "which machine am I", and neither does the user. There is no machine registry, no per-host branch, no template language.
- chezmoi's headline feature now buys nothing. Its remaining value is secret injection alone, which has not yet been shown to be needed. See the open questions in `docs/dotfiles-redesign.md`.
- Detection silently no-ops when a tool is absent, so a broken install presents as a missing feature rather than an error. Accepted deliberately: on an ephemeral target, a missing prompt is not worth failing a container build over.
- Divergent *values* (as opposed to divergent paths) cannot be expressed as a conditional. An untracked local override file such as `~/.zshrc.local` is the escape hatch.

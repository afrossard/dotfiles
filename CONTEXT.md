# Context

Glossary for this repo.
Terms are defined here only when their everyday meaning is ambiguous or misleading in this domain.

## Dotfile

A unit of home-directory user configuration that this repo owns and delivers.

A dotfile need not begin with a `.`, and need not sit directly in `$HOME`.
`~/AGENTS.md` and `~/.config/starship.toml` are both dotfiles.

Explicitly **not** dotfiles:

- **Binaries and packages.** A file cannot install `kubectl`. Tool installation is the concern of the base image, not this repo.
- **Editor GUI state.** Application-managed settings that the application rewrites at will.

## Target

Any place config is delivered to.
Targets are not tracked, named, or configured anywhere; the repo does not know how many exist.

Two kinds, differing only in lifetime:

- **Durable target.** The Mac, the Chromebook. Long-lived, edited in place, occasionally the origin of a change.
- **Ephemeral target.** A devcontainer. Created constantly, never edited, never the origin of a change.

Config flows outward to ephemeral targets and never flows back.

## Run-time detection

The rule that a config file is byte-identical on every target and discovers its
environment as it executes, rather than being generated per-target beforehand.

There is no per-machine state, no template, and no render step.
The repo therefore has no concept of "which machine am I", and neither does the user.

## Local override

An untracked, machine-unique file that a tracked config file sources if it exists
(for example `~/.zshrc.local`).

The escape hatch for divergent *values*, which run-time detection cannot express.
Never committed. Absence is always valid.

## Drift

A tracked config file whose content in the repo no longer matches the content in use on a durable target.

Drift is the failure mode this repo exists to prevent.

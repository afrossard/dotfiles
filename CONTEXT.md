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

An ephemeral target may still mount a durable volume, so a directory inside it can outlive it.
Such a directory is not thereby a durable target.
It never originates a change; it merely fails to forget one, which is why config is applied afresh on every start.

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

The state in which a tracked config file's content in the repo does not match the content in use on a durable target.

Drift is always one of two kinds, and they are not symmetric.
They call for opposite remedies, so a tool or a human that mistakes one for the other destroys work.

Drift is the failure mode this repo exists to prevent.

### Uncaptured edit

A change made directly to a durable target that the repo does not yet have.

This is the dangerous kind, because the change exists in exactly one place and nothing else knows about it.
An uncaptured edit is the mechanism by which this repo became a stale snapshot of 2023.
Applying the repo over the target does not reconcile an uncaptured edit; it deletes it.

### Unapplied change

A change present in the repo that a target has not yet received.

This is the benign kind.
The repo is still the source of truth and the change is merely late.
Nothing is lost by waiting, and the remedy is to apply the repo over the target.

## Publication

Drift concerns one target and its own copy of the repo.
Publication concerns the copies of the repo held by different targets.
A change can be free of drift on the machine where it was made and still be unreachable everywhere else.

### Unpublished change

A change that has been captured into a durable target's copy of the repo but has not reached the shared origin.

No other target can receive it, and it exists on exactly one machine.
Whether it is merely uncommitted or committed but unpushed makes no difference to anyone else.

### Unfetched change

A change that has reached the shared origin but not a given target's copy of the repo.

A target carrying an unfetched change is not drifted, and looks entirely healthy, because its target files agree with the repo it has.
Once fetched, an unfetched change becomes an unapplied change.
Rarely-used durable targets accumulate these silently.

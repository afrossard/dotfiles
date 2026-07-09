# Dotfiles redesign: work in progress

A `/grill-with-docs` session was interrupted partway through.
This file is the resume point.
It records the evidence that was expensive to gather and the questions still open.
It deliberately does not repeat the glossary (`CONTEXT.md`) or the settled decisions (`docs/adr/`).

## The actual problem

Not what the repo looks like it is.

The stated problem was "manage dotfiles across Mac, Linux and Chromebook Crostini".
The real workload is **one Mac used daily, plus a continuous stream of devcontainers**.
The Chromebook and the other Linux box are rare enough to be rounding errors.

"I copy the config manually across each" does not mean copying dotfiles into running containers.
It means **copy-pasting the container environment itself into every new repo**: the Homebrew install block, the `postCreateCommand.sh`, the alias file, the extension list.

## Findings (verified, do not re-derive)

### chezmoi was never installed

Not on this machine, and no evidence it ever ran anywhere.
No `~/.config/chezmoi`, no `~/.local/share/chezmoi`, no `.chezmoiignore`, no `.chezmoi.toml.tmpl`, no templates, no chezmoi binary.
The repo adopted chezmoi's *naming convention* (`dot_zshrc`, `private_dot_ssh/`, `private_Library/`) and nothing else.
Home-directory files are ordinary files, not symlinks and not chezmoi-applied.
"I never got the hang of chezmoi" is literally true.

### The repo is a 2023 snapshot, not a source of truth

Eight commits over three years.
Live `~/.zshrc` has nine lines the repo lacks (Claude Code PATH export, commented-out 1Password CLI lines).
Live `~/.ssh/config` has *dropped* the `Include "~/.colima/ssh_config"` line the repo still carries, so the two files have diverged in opposite directions.
Live VS Code settings share only four keys with the repo's copy.

### `chromebook/` uses a different, incompatible convention

Raw paths (`chromebook/homedir/.bash_aliases`), which chezmoi would never produce.
Two schemes in one repo.

### The sibling repos have rotted

All four devcontainers start `FROM mcr.microsoft.com/devcontainers/python:3-trixie` and each reinstalls Homebrew from scratch with a near-identical 15-line block.

| | homelab-kube | homelab-etl | homelab-fun | actual-budget-transformer |
|---|---|---|---|---|
| pinned `uv` | 0.11.2 | 0.9.18 | 0.11.14 | 0.11.19 |
| shell | zsh | bash | bash | zsh |
| Starship prompt | yes | **no** | **no** | yes |
| `chsh` to zsh | yes | no | no | yes |
| `/etc/zsh/zshenv` brew fix | **no** | n/a | n/a | yes |

`alias ll='ls -al'` exists in **five** separate files across these repos.
It is the most-duplicated line in the estate.

**Hard-won fixes do not propagate.**
`actual-budget-transformer/.devcontainer/Containerfile` carries a commented fix explaining that `~/.zshrc` is sourced only by interactive shells, so brew must also be added to `/etc/zsh/zshenv` or non-interactive tools lose it from `PATH`.
`homelab-kube` uses zsh too, lacks the fix, and therefore still has the bug.
Same story for the `gh` config-dir ownership fix.

`homelab-fun/.devcontainer/install_1password_cli.sh` is dead code, referenced from nowhere.
It installs a binary, so under ADR-0001 it is an image concern regardless.

### Config layering that the current setup smears together

Each Containerfile writes shell config into an image layer via `RUN cat <<EOF >> ~/.zshrc`.
That is configuration living inside tool installation, which is why the two cannot be updated independently.
Under ADR-0001 the base image must stop writing `~/.zshrc`.

### Unmanaged files that should probably be managed

`~/AGENTS.md` holds the user's global agent instructions and is **not** tracked anywhere.
`~/.claude/CLAUDE.md` is already a symlink to it, so the symlink pattern has been independently invented and validated.
`~/.claude/settings.json` is likewise unmanaged.

## Settled

- **Scope.** ADR-0001. Config only; the shared base image gets its own repo; editor settings deferred.
- **Divergence.** ADR-0002. Run-time detection, not templating. This removes chezmoi's reason to exist.
- **Vocabulary.** `CONTEXT.md`. Note especially that a *dotfile* here means home-directory user configuration and need not begin with a `.`.

## Open questions, in dependency order

### Q5 (was mid-flight): symlinks or copies?

**Recommendation: symlinks, installed by a small POSIX `install.sh` in this repo, with no dotfile manager at all.**

The argument: the repo drifted *because* home files are copies.
Symlinking makes drift structurally impossible on durable targets, because editing `~/.zshrc` then edits the repo, and `git status` is always the complete picture.
chezmoi would not have cured this, since `chezmoi apply` also writes copies; it merely offers `chezmoi diff` and `chezmoi add`, both of which are rituals the user must remember.
Rejecting GNU stow because it is a binary that must exist before the shell works, and its directory-folding semantics surprise people.
Rejecting a hand-rolled tool would normally be right, but the installer is tiny precisely because ADR-0002 deleted the templating requirement.

Two hazards to design around, not reasons to abandon symlinks:

- Applications that rewrite their own config atomically (temp file plus rename) destroy the symlink and leave a regular file. VS Code's `settings.json` does this. Open question whether Claude Code does the same to `~/.claude/settings.json`.
- `ssh` refuses a config that is group- or world-writable. Symlink permissions are ignored, the target's matter, and repo files are `644`, so the files are fine. But `~/.ssh` itself must be `700` and a naive `mkdir` yields `755`.

### Q6: bash, zsh, or both?

Two sibling repos use bash and two use zsh, hence the parallel `.bash_aliases` and `.zsh_aliases` files.
Worth deciding whether to standardise on zsh everywhere or to factor a POSIX-`sh` fragment that both shells source.

### Q7: are there any actual secrets?

If nothing in this repo is secret, chezmoi's last remaining advantage disappears entirely.
`~/.ssh/config` is not secret.
The 1Password agent socket path is a public constant.
Verify before concluding.

### Q8: how do containers get the config?

VS Code's `dotfiles.repository` **user** setting auto-clones a dotfiles repo into every devcontainer and Codespace and runs its install script.
It is currently not set, and is probably the single biggest available win.

Known gap: it applies only to containers launched by VS Code.
`actual-budget-transformer` starts a separate `claude` service from `docker-compose.yml` via a `claude-up` alias and `docker exec`.
That container would receive nothing.
Read `actual-budget-transformer/.devcontainer/docker-compose.yml` before answering.

### Q9: migration and disposal

Decide the fate of `chromebook/`, `private_Library/`, `private_dot_ssh/`, and the `dot_`/`private_` chezmoi naming convention.
The convention should almost certainly go, since nothing reads it.
Also decide whether `~/AGENTS.md` and `~/.claude/settings.json` come under management.

### Q10: sync ritual across durable targets

Symlinks solve the Mac.
The Chromebook still needs a `git pull` from time to time, and nobody will remember.
Decide whether that is acceptable (it may well be, given how rarely it is used) or whether something should nag.

## How to resume

Continue the grilling from Q5.
Ask one question at a time, give a recommendation with each, and wait for an answer before moving on.
Look facts up in the repos under `~/Documents/git/` rather than asking; the decisions are the user's.

Do not enact anything until the user confirms shared understanding.

## Suggested skills

- `/grilling` to resume the interview.
- `/domain-modeling` alongside it, to keep `CONTEXT.md` and `docs/adr/` current as terms and decisions resolve. Both are reachable together via `/grill-with-docs`.
- `/verify` once an `install.sh` exists, to exercise it end-to-end on a real fresh container rather than trusting a dry run.

## User preferences learned this session

Now recorded in `~/AGENTS.md`, repeated here only as a pointer:

- A repo's scope is bounded by its name; adjacent concerns get their own repo.
- Do not invent numbered labels for concepts and then expect them to be tracked.
- Durable facts belong in `~/AGENTS.md` (global) or a repo's `AGENTS.md` (local), never in machine-local agent state under `~/.claude/projects/`, which does not survive a machine re-install.

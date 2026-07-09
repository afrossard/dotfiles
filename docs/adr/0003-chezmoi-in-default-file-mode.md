# chezmoi, in its default file mode, with a drift indicator in the prompt

This repo has carried chezmoi's naming convention (`dot_zshrc`, `private_dot_ssh/`) since 2023 without ever installing chezmoi, so the convention decorated nothing.
We adopt chezmoi for real, in its default `mode = "file"`, and we make the naming convention load-bearing.
Because file mode writes copies rather than symlinks, drift is possible, and we accept that in exchange for the well-trodden path, guarding it with a drift indicator in the Starship prompt rather than with symlinks.

## Considered options

Rejecting a dotfile manager entirely, in favour of an `install.sh` that calls `ln`, was the incumbent recommendation.
It was rejected because an installer exists either way (Codespaces and VS Code both look for `install.sh`, `bootstrap.sh`, `setup.sh` and four other names), so the real question was only what that installer calls, and a hand-rolled thirty lines buys nothing that a maintained tool does not already do better.

GNU Stow was rejected, but not for the reasons first offered.
Its tree-folding is disarmed by `--no-folding`, and its refusal to overwrite an existing regular file is correct rather than a defect.
It falls to two things: it cannot set `~/.ssh` to mode `700`, having no hooks, and its Perl and its package must be installed on a target before that target has a working shell.

`mode = "symlink"` was seriously considered and is the reason this ADR exists.
It makes an uncaptured edit impossible, because editing `~/.zshrc` edits the source directly.
Every one of the four reasons chezmoi's author gives for defaulting to copies is void here: there are no encrypted files (verified: no private keys exist on disk at all, since 1Password serves them over the agent socket), no executable dotfiles, no templates (ADR-0002), and the `private_` attribute on `dot_ssh/` was measured to set `~/.ssh` to `700` without preventing `config` inside it from being symlinked.
It was rejected anyway, because the documentation says "if you really want to use symlinks... this currently requires a bit of manual work", and a config repo is a bad place to leave the beaten path.

Nix with home-manager would subsume this repo, the base-image repo, and the four sibling `uv` pins together, and would erase the `/opt/homebrew` versus `/home/linuxbrew` split that ADR-0002 exists to paper over.
It is deferred, not rejected. It is a decision about tool installation, and it should be made in the base-image repo. If it is ever made there, revisit this ADR, because home-manager would then be nearly free.

## Consequences

- On a durable target the source directory is chezmoi's default, `~/.local/share/chezmoi`, reached with `chezmoi cd`. The repo therefore no longer lives beside its siblings in `~/Documents/git`.
- On an ephemeral target the source directory is wherever the platform cloned it, which for VS Code and Codespaces is `~/dotfiles`. The repo does not record either path. `chezmoi generate install.sh` emits a non-interactive installer that derives the source directory from its own location at run time, which is ADR-0002's rule applied to the installer itself. That generated script is committed at the repo root, beside `.chezmoiroot` rather than inside the source root, because the platform looks for it at the root of the clone and because the directory it passes as `--source` is the one `.chezmoiroot` is read from. It therefore sits outside the source root and needs no `.chezmoiignore` entry to stay out of `$HOME`.
- **The source root is `home/`, named by a `.chezmoiroot` file at the repo root.** chezmoi maps its source root onto `$HOME`, so without this the repo's own `AGENTS.md`, `CONTEXT.md`, `docs/` and `skills-lock.json` are all delivered into the home directory. `AGENTS.md` is the sharp edge: this repo's `AGENTS.md` holds instructions about this repo, `~/AGENTS.md` holds the global agent instructions, and at the source root they are the same path. The two cannot coexist there, and `.chezmoiignore` cannot resolve it, because a file cannot be both ignored and delivered. Measured: with `.chezmoiroot`, `add` and `re-add` write into `home/` and the repo's own files stay out of `$HOME`. Source entries beginning with `.` are reserved by chezmoi and were never at risk, which is why `.claude/` and `.agents/` were already safe.
- **The base image must stop writing `~/.zshrc`.** This is not tidiness, but the reason is not the one first given here. Measured against chezmoi 2.71.0: on a target carrying no chezmoi persistent state, `chezmoi init --apply` overwrites a pre-existing `~/.zshrc` silently, exits `0`, and needs no TTY. Nothing fails; the base image's work is simply destroyed, and no one is told. The prompt appears only once chezmoi has written the file and it has since changed, when `apply` asks whether the file has changed since chezmoi last wrote it and, finding no TTY, fails. That state is reachable on an ephemeral target, because its persistent state lives at `~/.config/chezmoi/chezmoistate.boltdb` and `CONTEXT.md` notes that a mounted durable volume can outlive the container. So a base image that writes `~/.zshrc` loses its content on a fresh target and hangs the build on a returning one.
- Drift splits into the two kinds named in `CONTEXT.md`, and they are exactly chezmoi's two status columns. A non-blank first column is an *uncaptured edit*; a non-blank second column is an *unapplied change*.
- **The drift check must never remediate.** The two kinds need opposite remedies and each remedy destroys the other kind. Running `chezmoi apply` over an uncaptured edit deletes it; running `chezmoi re-add` over an unapplied change discards what was pulled. Only a human can tell which was intended.
- `chezmoi status` exits `0` whether or not it reports drift, so any check must test for empty output rather than an exit code.
- `chezmoi update` is `git pull` followed by `apply`, and therefore silently deletes uncaptured edits. It must not be used on a durable target without checking status first.
- The Starship indicator distinguishes the two kinds, borrowing the ahead/behind idiom already in the prompt's `git_status`. It costs roughly 22ms per prompt once warm, and roughly 350ms on the first prompt after a reboot while the binary is cold.
- The indicator does not run on an ephemeral target. A devcontainer cannot produce an uncaptured edit, because config flows outward to it and never flows back.
- **A green indicator means captured, not safe.** `chezmoi status` goes empty the instant you `re-add`, while the change still sits uncommitted in one machine's working tree. The indicator therefore also reports the publication state defined in `CONTEXT.md`: unpublished commits, read from the source repo's cached upstream ref, which needs no network; and unfetched commits, which do. A stamp file limits the `git fetch` that refreshes those refs to once a day, so the prompt stays offline and a rarely-used durable target still learns it is behind.

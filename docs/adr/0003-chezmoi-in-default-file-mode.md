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

- **The source directory is wherever the repo was cloned, on both kinds of target, and the repo names no path.**
  A durable target's clone goes wherever that machine keeps its git repos, which is not the same path on every machine.
  An ephemeral target's goes wherever the platform put it, which for VS Code and Codespaces is `~/dotfiles`.
  Neither path is written down here.
  This supersedes an earlier decision to adopt chezmoi's default `~/.local/share/chezmoi` on a durable target.
  That would have exiled an actively developed repo, one carrying its own ADRs, agent skills and issue workflow, into XDG data and away from its siblings, and it buys nothing, because the source directory has to be recorded per target regardless.
- **The generated config records the source directory it was initialised with: `sourceDir = {{ .chezmoi.sourceDir | quote }}`.**
  This line is load-bearing, not decorative.
  Measured against chezmoi 2.71.0: `--source` is *not* persisted by `init`, so without it every later bare `chezmoi status`, `re-add`, `apply` and `cd` looks in chezmoi's default directory and fails on any target that is not there.
  `chezmoi status` is precisely what the drift indicator runs.
  chezmoi's own documentation calls this setting "required because Codespaces clones your dotfiles repo to a different one to chezmoi's default".
  It is ADR-0002's run-time detection applied to the source directory itself: the path is discovered at `chezmoi init` and recorded in the generated config, never in the repo.
- The settings live in `home/.chezmoi.toml.tmpl`, which is a template only because that is the sole form chezmoi reads a source-root config from.
  Measured: a plain `.chezmoi.toml` there is silently ignored, generating no config file at all.
  It carries no template actions beyond the `sourceDir` line above, so it does not reintroduce what ADR-0002 rejected.
  **`chezmoi init` writes the config once.** A target initialised before a setting was added to the template keeps its old config until `chezmoi init` is run again, so adding a setting here does not reach a machine that has already bootstrapped.
  This is not silent, which is the only reason it is tolerable: chezmoi then warns `config file template has changed, run chezmoi init to regenerate config file` on every subsequent command.
- `chezmoi generate install.sh` emits a non-interactive installer that derives the source directory from its own location at run time, which is ADR-0002's rule applied to the installer itself.
  Because it does, the *same* installer bootstraps both kinds of target: clone the repo wherever it belongs on that machine, and run `./install.sh`.
  That generated script is committed at the repo root, beside `.chezmoiroot` rather than inside the source root, because the platform looks for it at the root of the clone and because the directory it passes as `--source` is the one `.chezmoiroot` is read from.
  It therefore sits outside the source root and needs no `.chezmoiignore` entry to stay out of `$HOME`.
  chezmoi's documentation does say to add one, but that advice is written for a repo with no `.chezmoiroot`, where the installer would sit inside the source root.
  Verified both ways: an `install.sh` inside `home/` is delivered to `~/install.sh`; at the repo root it is not.
- **The source root is `home/`, named by a `.chezmoiroot` file at the repo root.** chezmoi maps its source root onto `$HOME`, so without this the repo's own `AGENTS.md`, `CONTEXT.md`, `docs/` and `skills-lock.json` are all delivered into the home directory. `AGENTS.md` is the sharp edge: this repo's `AGENTS.md` holds instructions about this repo, `~/AGENTS.md` holds the global agent instructions, and at the source root they are the same path. The two cannot coexist there, and `.chezmoiignore` cannot resolve it, because a file cannot be both ignored and delivered. Measured: with `.chezmoiroot`, `add` and `re-add` write into `home/` and the repo's own files stay out of `$HOME`. Source entries beginning with `.` are reserved by chezmoi and were never at risk, which is why `.claude/` and `.agents/` were already safe.
- **`lessInteractive = true` in the generated config, because chezmoi's first apply is otherwise silently destructive.**
  chezmoi's "has this changed since I wrote it?" prompt can only fire once chezmoi has written the file, and on the first apply it never has.
  Measured against 2.71.0: adopting this repo on a machine already in use overwrites that machine's `~/.zshrc` and exits `0`, asking nothing, *and a controlling terminal does not save you*.
  The prompt is not suppressed for want of a TTY; it is never reached.
  The file it eats is precisely the uncaptured edit this repo exists to protect, and the nine unseen lines in the problem statement are exactly that file.
  `lessInteractive` widens the prompt to cover pre-existing targets as well as changed ones.
  It is chezmoi's own setting, so no guard script of ours is needed.
  Measured on every path: a durable target is asked `.zshrc already exists?` and offered `diff/overwrite/all-overwrite/skip/quit`, so the content can be inspected before anything is lost, and `skip` keeps the file while the rest of the tree still applies; a target with no TTY exits `1` and the pre-existing content survives; a clean target applies silently and exits `0`, so an ephemeral target is unaffected; and an unapplied change to a file chezmoi already wrote is not a prompt, so routine updates are untouched.
  This is what makes user story 19's "fail loudly rather than hang" true, and it enforces ADR-0006 at run time rather than by convention.
- **The `private_` attribute reproduces `~/.ssh` at `0700` on a target that lacks it; it does not correct a target that already has it.**
  The Mac is already `0700`, set by hand years ago, and chezmoi changes nothing there.
  The attribute exists so that a *fresh* target - a new machine, a container - gets `0700` rather than the `0755` a default umask would give it, because `ssh` refuses a config directory others can read.
  This is user story 20, and its point is that the mode stops being knowledge someone has to remember.
- **If `lessInteractive` does prompt `.ssh already exists?`, answer `overwrite`, not `skip`.**
  Measured: the prompt appears *only* where the directory's mode actually differs from `0700`, so it does not appear on the Mac at all - there, the first `~/.ssh` prompt is for the `config` file inside it.
  Where it does appear, the safe-looking answer is the wrong one: `skip` leaves the mode as it was, which fails silently, because a wrong mode looks like nothing at all until `ssh` refuses the config.
  `overwrite` on a directory sets its mode and nothing else.
  Measured: with an unmanaged `known_hosts` and an unmanaged private key inside, `overwrite` left both untouched and the key still at `0600`, took `~/.ssh` from `0755` to `0700`, and replaced only the managed `config`.
  chezmoi does not remove unmanaged files, so `overwrite` on `~/.ssh` cannot eat a key.
- **The base image must stop writing `~/.zshrc`,** and `lessInteractive` raises the stakes rather than lowering them.
  A container has no TTY, so a base image that writes that file now *fails* the build outright, where before it would have silently lost its own work on a fresh target.
  That is the intended trade, and it is user story 19: a failed build is strictly better than an unreported one.
  But it means the base image's `~/.zshrc` has to actually go, not merely be tolerated.
  The returning target was already a failure for a different reason: once chezmoi has written the file and something has since changed it, `apply` asks `.zshrc has changed since chezmoi last wrote it?` and, finding no TTY, exits `1` with `could not open a new TTY`.
  That state is reachable on an ephemeral target, because its persistent state lives at `~/.config/chezmoi/chezmoistate.boltdb` and `CONTEXT.md` notes that a mounted durable volume can outlive the container.
  Neither path hangs: measured with no controlling terminal, `apply` fails fast rather than waiting, so nothing here is a build-timeout risk.
- Drift splits into the two kinds named in `CONTEXT.md`, and they are exactly chezmoi's two status columns. A non-blank first column is an *uncaptured edit*; a non-blank second column is an *unapplied change*.
- **The drift check must never remediate.** The two kinds need opposite remedies and each remedy destroys the other kind. Running `chezmoi apply` over an uncaptured edit deletes it; running `chezmoi re-add` over an unapplied change discards what was pulled. Only a human can tell which was intended.
- `chezmoi status` exits `0` whether or not it reports drift, so any check must test for empty output rather than an exit code.
- `chezmoi update` is `git pull` followed by `apply`, and therefore silently deletes uncaptured edits. It must not be used on a durable target without checking status first.
- The Starship indicator distinguishes the two kinds, borrowing the ahead/behind idiom already in the prompt's `git_status`. It costs roughly 22ms per prompt once warm, and roughly 350ms on the first prompt after a reboot while the binary is cold.
- The indicator does not run on an ephemeral target. A devcontainer cannot produce an uncaptured edit, because config flows outward to it and never flows back.
- **A green indicator means captured, not safe.** `chezmoi status` goes empty the instant you `re-add`, while the change still sits uncommitted in one machine's working tree. The indicator therefore also reports the publication state defined in `CONTEXT.md`: unpublished commits, read from the source repo's cached upstream ref, which needs no network; and unfetched commits, which do. A stamp file limits the `git fetch` that refreshes those refs to once a day, so the prompt stays offline and a rarely-used durable target still learns it is behind.

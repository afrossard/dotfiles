# dotfiles

Home-directory configuration, managed with [chezmoi](https://chezmoi.io).

## Prerequisites

This repo manages home-directory config only; it never installs tools.

Each durable target needs a few things in place first, or already has them, before the config actually does anything.

### macOS

Homebrew is assumed present.
Install `chezmoi` with it before running the installer, so updates ride along with the standard update workflow.

```sh
brew install chezmoi starship font-fira-code-nerd-font
```

Do this _before_ `install.sh` below.
The install script installs `chezmoi` into `~/.local/bin` if it is absent, outside any package manager, and `~/.zshrc` puts `~/.local/bin` ahead of the Homebrew prefix - so that copy would shadow a later `brew install chezmoi` and leave you upgrading a binary you never run.

Install 1Password for Mac and turn on its SSH agent (Settings → Developer → "Use the SSH agent").
`~/.ssh/config` expects that agent's socket to exist; there are no private keys on disk anywhere in this repo's design.

Then, once the config is applied, set the terminal font to FiraCode Nerd Font Light.

### Chromebook (Linux)

Install git, curl, and zsh using apt, and make zsh the login shell.

```sh
sudo apt install git curl zsh
sudo chsh -s "$(command -v zsh)" "$USER"
```

Log out and back in (or open a fresh terminal) for the new login shell to take effect.
zsh is required before the target is useful at all: this repo ships no bash configuration.

Install Homebrew by following the instructions at [brew.sh](https://brew.sh), prepending `NONINTERACTIVE=1` to the command shown there so it does not stall waiting for a confirmation keypress.
Then install what the config expects:

```sh
brew install chezmoi starship font-fira-code-nerd-font
```

Install 1Password for Linux and turn on its SSH agent the same way, under Settings → Developer.
Its socket lands at a different path than macOS's, and `~/.ssh/config` probes for both, so either just works.

Then, once the config is applied, set the terminal font to FiraCode Nerd Font Light.

## Bootstrap

Clone the repo wherever it belongs on that machine.

```sh
git clone https://github.com/afrossard/dotfiles.git
```

Then initialise `chezmoi` with the install script.

```sh
cd dotfiles && ./install.sh
```

`install.sh` is generated (`chezmoi generate install.sh`); do not hand-edit it.
It runs `chezmoi init --apply` with this clone as the source directory, recording that path so `chezmoi cd` finds it later.

**On a machine already used, run it in a real terminal.**
chezmoi asks before overwriting any file it did not write, and that prompt is all that stands between your live `~/.zshrc` and the repo's.
Answer `diff` first, then `overwrite` or `skip`.
For `.ssh already exists?` answer `overwrite`: it sets the directory's mode and removes nothing, while `skip` leaves `~/.ssh` at `0755` and fails silently.
With no terminal the installer exits `1` and changes nothing, by design.

## Daily use

```sh
chezmoi cd       # this repo, wherever it lives here
chezmoi status   # what has drifted
chezmoi re-add   # capture an edit made directly in $HOME
chezmoi apply    # deliver a repo change to $HOME
```

Drift has two kinds needing opposite remedies, and each remedy destroys the other kind.
Read `status`'s **first** column ([CONTEXT.md](CONTEXT.md) defines the terms).

| `status` | kind                                 | remedy           |
| -------- | ------------------------------------ | ---------------- |
| `MM`     | uncaptured edit - you edited `$HOME` | `chezmoi re-add` |
| ` M`     | unapplied change - the repo is ahead | `chezmoi apply`  |

**Never `chezmoi update` without checking `status` first.**
It is `git pull` then `apply`, so it deletes an uncaptured edit.

The prompt reads that first column for you, and raises a `⌂` when anything is pending.

```
⌂l⇡1 ~/Downloads ❯          you edited $HOME; the repo has never seen it
⌂r⇡2⇣1 ~/work/api main ❯    the dotfiles repo is 2 unpushed, 1 unfetched
```

`l` is `$HOME` against the repo, `r` the repo against origin, `⇡` has to leave here, `⇣` is waiting to come here.
The badge never names a remedy, because a glyph that encodes one has to be decoded from memory at the moment you can least afford to get it wrong.
Run `chezmoi-drift` to be told, in words, what drifted and what to run.

`~/.zshrc` has exactly one writer, this repo ([ADR-0006](docs/adr/0006-zshrc-has-exactly-one-writer.md)).
Machine-unique values go in `~/.zshrc.local`, project shell config in `~/.zshrc.d/*.zsh`.
Neither is committed; absence of either is valid.

This repo must stay public: ephemeral targets bootstrap themselves by cloning it over HTTPS with no credentials.

## Tests

The suite builds a throwaway `$HOME`, a real chezmoi source directory and a real git origin, then drives real `chezmoi`, `git` and `starship` against them.
There is one seam, the door a user walks through: the repo is applied into that `$HOME`, and every assertion is on what the user would then see.

That door has two sides.
On one, the rendered prompt: the drift indicator can fail silently, because a custom module with no `when` never runs its command and looks exactly like a clean machine, so the tests read the glyph starship actually prints rather than the script's stdout.
On the other, the applied tree and the shell it configures: a file's mode, a symlink's target, and whether sourcing `~/.zshrc` wires in a tool exactly when that tool is installed.
No test reaches inside a script or fakes a tool's output.

No target needs any of this.
`tests/` sits outside `home/`, so it is never delivered, and nothing here is installed on a machine that merely uses the dotfiles.
It is a dependency of working _on_ this repo.

```sh
brew install bats-core
bats tests/
```

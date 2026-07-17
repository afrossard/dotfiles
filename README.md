# dotfiles

Home-directory configuration, managed with [chezmoi](https://chezmoi.io).

## Bootstrap

Clone the repo wherever it belongs on that machine.

```sh
git clone https://github.com/afrossard/dotfiles.git
```

On durable targets, install `chezmoi` with a package manager such as `brew` first, so that updates ride along with the standard update workflow.

```sh
brew install chezmoi
```

Do this *before* the next step.
The install script installs `chezmoi` into `~/.local/bin` if it is absent, outside any package manager, and `~/.zshrc` puts `~/.local/bin` ahead of the Homebrew prefix - so that copy would shadow a later `brew install chezmoi` and leave you upgrading a binary you never run.

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

Then install what the config expects:

```sh
brew install starship font-fira-code-nerd-font
```

and set the terminal font to FiraCode Nerd Font Light.

## Daily use

```sh
chezmoi cd       # this repo, wherever it lives here
chezmoi status   # what has drifted
chezmoi re-add   # capture an edit made directly in $HOME
chezmoi apply    # deliver a repo change to $HOME
```

Drift has two kinds needing opposite remedies, and each remedy destroys the other kind.
Read `status`'s **first** column ([CONTEXT.md](CONTEXT.md) defines the terms).

| `status` | kind | remedy |
| --- | --- | --- |
| `MM` | uncaptured edit - you edited `$HOME` | `chezmoi re-add` |
| ` M` | unapplied change - the repo is ahead | `chezmoi apply` |

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
It is a dependency of working *on* this repo.

```sh
brew install bats-core
bats tests/
```

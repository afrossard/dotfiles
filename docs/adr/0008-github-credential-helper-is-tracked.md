# The GitHub credential helper is tracked, not a local override

`gh auth setup-git` writes `credential.https://github.com.helper` into `~/.config/git/config`, the file this repo manages.
Every apply overwrites that file and deletes the line, so `git push` starts failing with `fatal: could not read Username for 'https://github.com'` while `gh` itself keeps working, because `gh`'s token lives in `~/.config/gh/hosts.yml`, a file this repo does not touch.
The credential blocks now live in `home/dot_config/git/config` itself, and `gh auth setup-git` is retired as a setup step.

## Considered options

Treating the helper as a local-override value, the way `~/.zshrc.local` holds machine-unique settings, was rejected because it is not a divergent value.
`helper = !gh auth git-credential` is byte-identical on every target, which under ADR-0002 is exactly the kind of value the tracked file is for.
The bug this ADR fixes is that an invariant had been left for a manual step to fill in, rather than that it was in the wrong kind of file.

Regenerating `config.local` from inside the target, so `gh auth setup-git` would have somewhere safe to write, was also rejected.
An included file is never a write target: with `config.local` present and non-empty, a plain `git config --global` still wrote to the parent file.
Only a per-invocation `GIT_CONFIG_GLOBAL` redirect would change that, and that is a step someone has to remember, which is the same failure this ADR exists to remove.

## Consequences

- `gh auth setup-git` is never needed again on any target. The token still comes from `gh auth login`, but wiring it into git no longer requires a second command.
- The command name is bare: `!gh auth git-credential`, not the absolute path `gh auth setup-git` bakes in. Git resolves the helper through `PATH` when it invokes it, so the line is portable across every target's Homebrew prefix. An absolute path is the one form that cannot travel between targets.
- The credential blocks sit after `[include]` in the tracked file. `gh auth setup-git` writes an empty `helper =` line before its own, and an empty value resets git's accumulated helper list. Placed after the include, that reset only clears what `config.local` set before it, so a stale `config.local` can add its own helper without erasing the tracked one. Placed before the include, the same reset would wipe the tracked block out entirely and no error would say so.
- ADR-0005's public-repo invariant still holds. The tracked line is a command name, not a credential; the token stays in `gh`'s own store, which this repo continues not to touch.
- SSH remotes are unaffected. Git does not enter the credential system for `ssh://` transport at all, so this change has no effect on any target already using an SSH remote.
- Manual migration: on this host, `~/.config/git/config.local` already carries the absolute-path helper `gh auth setup-git` wrote before this ADR. Until an operator empties that file by hand, its stale entry is tried first and the tracked block is never actually exercised on the machine it is used from most.

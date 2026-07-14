# `~/.zshrc` has exactly one writer

Today four Containerfiles append to `~/.zshrc` with `RUN cat <<EOF >> ~/.zshrc`, and four `postCreateCommand.sh` scripts append to it again.
From now on chezmoi is the only thing that writes that file.
Everything that used to append to it has somewhere better to go.

## Considered options

Carrying a `command -v` guard and an `eval` for each tool inside the single `~/.zshrc` is the natural reading of ADR-0002's run-time detection, and the guards really are free: `command -v flux` when flux is absent costs 0.018ms.
The evals are not free. `uv generate-shell-completion zsh` was measured at **165ms** and `gh completion -s zsh` at 34ms, paid on every shell start.
`postCreateCommand.sh` stacks `uv`, `helm` and `flux` that way today, so those containers already start shells in roughly half a second.
It would also make this repo carry a growing list of tool names it does not own.

## Consequences

- **Tool completions go on `fpath`.** Whatever installs a tool writes its completion function into a site-functions directory, and `~/.zshrc` only sets `fpath` and runs cached `compinit`. This is lazy where an `eval` is eager: `compinit` reads a completion file's `#compdef` tag and nothing else, and the body is read on the first Tab after the command is typed, or never. Verified: with a `_demo` file on `fpath`, opening a shell never read the file's body, yet `${+_comps[demo]}` was `1`. The 165ms is deferred, and this repo names no tools.
- **Project shell config goes in `~/.zshrc.d/`.** The last line of `~/.zshrc` sources `~/.zshrc.d/*.zsh` if any exist. `actual-budget-transformer`'s `dc`, `actual-up/down` and `claude-*` aliases move there, dropped in by its `postCreateCommand.sh`. The directory is untracked and its absence is always valid, exactly like the local override in `CONTEXT.md`.
- Three of the four `.zsh_aliases` and `.bash_aliases` files in the sibling repos contain nothing but `alias ll='ls -al'` and are deleted outright, since this repo now ships that alias.
- Nothing manufactures an uncaptured edit. A container that appended to `~/.zshrc` would leave chezmoi's state disagreeing with the file it manages. That is harmless on an ephemeral target, where config never flows back, but a rule that holds only where it is convenient is not a rule.

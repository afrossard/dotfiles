# dotfiles

Personal chezmoi-managed dotfiles.

## Layout

`home/` is the chezmoi source root, named by `.chezmoiroot`, and it is mapped onto `$HOME`.
Everything outside `home/` describes the repo and is never delivered to a target.

This file is not `home/AGENTS.md`.
This one holds instructions about this repo; that one is the global agent instruction file, delivered to `~/AGENTS.md` and symlinked to `~/.claude/CLAUDE.md`.
Edit the right one.

## Agent skills

### Issue tracker

Issues live in `afrossard/dotfiles` GitHub Issues, managed with the `gh` CLI.
External pull requests are not a triage surface.
See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles use their default label strings, unchanged.
See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root.
See `docs/agents/domain.md`.

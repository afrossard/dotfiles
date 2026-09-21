# Agent skills are vendored into the source root

The engineering skills (`grilling`, `domain-modeling`, `to-spec` and the rest, from `mattpocock/skills`) were installed into this repo by `npx skills` as a project-level copy: files under `.agents/skills/`, symlinks under `.claude/skills/`, and a `skills-lock.json`.
That made them available only while working in this repo, on the one machine that had run the installer.
They are user configuration that should follow the user to every repo and every target, so they are now dotfiles.
They live as plain files in `home/dot_agents/skills/<name>/`, delivered to `~/.agents/skills/<name>/`, and `~/.claude/skills/<name>` is a relative symlink to each (`home/dot_claude/skills/symlink_<name>`).
That is the `.agents` convention the project-level install already used, and it is why the real files are not under `.claude`: another agent that reads `~/.agents/skills` gets the same skills, and Claude Code is only one reader of them.

## Considered options

**A `.chezmoiexternal.toml` archive, pinned to a commit,** is chezmoi's own mechanism for third-party content, and it was measured rather than assumed.
Against chezmoi 2.72.2, one `type = "archive"` external per skill, with `stripComponents = 4` and an `include` glob, flattens upstream's `skills/<bucket>/<name>/` into one directory per skill correctly.
`chezmoi status` sees edits inside external content, and ten of them cost about 30ms, so the drift indicator's prompt budget survives.
It was rejected on robustness.
Every `chezmoi apply` then needs `github.com`, and a failed fetch fails the whole apply, so an ephemeral target that cannot reach GitHub for one moment loses its `~/.zshrc` over a skill.
Most of the test suite applies the whole tree, each test under its own cache, so each would download the archive and none could run offline.
Copies committed to the repo cost nothing at apply time and keep the suite hermetic.

**The Claude Code plugin** (`claude plugins install mattpocock-skills`) is what upstream recommends for subscribing to updates.
Enabling a plugin is a key in `~/.claude/settings.json` (`enabledPlugins`), which ADR-0007 keeps out of this repo until it can be owned key by key.
A skill set that a fresh target only gets after someone runs a command by hand is the state this repo exists to remove.

**`npx skills add --global`** installs into `~/.claude/skills/` directly.
Nothing chezmoi manages would then record it, so a new target would not receive it, which is the same gap in a different place.

## Consequences

- **`agents/` is left out of every skill.**
  Upstream ships an `agents/openai.yaml` beside each `SKILL.md` as Codex UI metadata.
  Nothing here runs Codex, and the copies this replaces had none; if a Codex target ever reads `~/.agents/skills`, this is the line to revisit.
- **The layout is flat, and a test holds it there.**
  Upstream files a skill under a bucket (`skills/engineering/domain-modeling/`); Claude Code finds a skill one directory below `~/.claude/skills/`, so a skill delivered inside its bucket is on disk and invisible.
  `tests/applied.bats` asserts every entry under `~/.claude/skills` is a link that resolves to `~/.agents/skills/<name>`, holds a `SKILL.md`, and declares that name.
- **Updating is a deliberate copy, and the diff is the review.**
  Clone the skill's upstream: `mattpocock/skills`, or `cursor/plugins` for `unslop`.
  Then for each skill: `rsync -a --delete --exclude=agents/ <clone>/<path>/<name>/ home/dot_agents/skills/<name>/`, where `<path>` is `skills/<bucket>` in the first and `pstack/skills` in the second.
  `git diff` shows what upstream changed in the instructions the agent will follow, before they reach a target.
  Renovate does not track these files, and that is intended: a skill is a prompt, and a prompt is read before it is adopted.
- **Only the per-skill entries are managed, not `~/.claude/skills/` or `~/.agents/` themselves.**
  Something other than chezmoi already writes `~/.claude/skills/synced/` and `~/.agents/.skill-lock.json`; naming only `<name>` leaves both alone.
- **Skills are vendored verbatim, and the notices travel with them.**
  Both upstreams are MIT, which asks that the copyright notice accompany substantial copies, and this repo must stay public.
  `THIRD-PARTY-NOTICES.md` at the repo root holds each upstream's license text.
  It sits outside `home/`, so it is not delivered to a target, and a new upstream adds a section there.
  A local edit to a vendored skill is overwritten by the next update, so a change worth keeping is sent upstream or re-applied after each update.
- **A new skill is two source entries,** its directory under `dot_agents/skills/` and a `symlink_<name>` beside the others under `dot_claude/skills/`.
  The test fails on either one missing: a directory with no link, or a link with no directory.
- **A skill or file that upstream drops stays on existing targets.**
  Deleting it from the source stops chezmoi managing it and does not remove it.
- **The per-repo output of these skills stays in each repo.**
  `setup-matt-pocock-skills` writes `docs/agents/*.md` and an `## Agent skills` block into the repo it runs in, and this repo's own copies of those are unaffected by where the skills live.

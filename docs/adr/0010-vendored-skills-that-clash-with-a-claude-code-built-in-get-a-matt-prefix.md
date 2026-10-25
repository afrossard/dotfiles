# Vendored skills that clash with a Claude Code built-in get a `matt-` prefix

Claude Code ships built-in skills, and two of them share a name with a skill vendored from `mattpocock/skills`: `code-review` and `prototype`.
A skill of the same name in `~/.claude/skills/` replaces the built-in for the user, so delivering the vendored copy under its upstream name makes the built-in unreachable.
The two do different jobs: the built-in `code-review` hunts bugs, the vendored one reviews a diff against the repo's standards and the originating spec, and both are wanted.

Upstream declines to rename skills over harness collisions, and for a copy that is not the Claude Code plugin it says to rename the folder and the `name:` field locally (`.out-of-scope/harness-name-collisions.md` in `mattpocock/skills`).
So a vendored skill whose name matches a Claude Code built-in is delivered as `matt-<name>`, and only then.
A clash with another tool's built-in, such as GitHub Copilot's `/research`, does not count, because Claude Code is the agent these skills are delivered for.

## Considered options

**Prefixing every vendored skill** would make the source of each skill obvious and pre-empt any future built-in.
It was rejected because it rewrites every skill-to-skill call in the vendored text on every update, for clashes that have not happened.

**Skipping a clashing skill** keeps the vendored text verbatim, but loses the skill, and `implement` and `tdd` refer to `code-review` by name.

## Consequences

- **The current renames are `code-review` to `matt-code-review` and `prototype` to `matt-prototype`.**
  `THIRD-PARTY-NOTICES.md` lists each with its upstream name.
- **A rename is the folder, the `name:` field and the `symlink_<name>` source together.**
  Changing only one leaves the name the user types out of step with the name an agent calls.
- **Calls to a renamed skill in other vendored skills use the new name.**
  Today these are `implement` and `tdd` (`matt-code-review`) and `wayfinder` (`matt-prototype`).
  The `prototype` ticket type in `wayfinder:<type>` labels is a label, not a skill name, and keeps its upstream spelling.
- **Every update re-applies these edits.**
  ADR-0009's `rsync` copies `<clone>/skills/<bucket>/<name>/` into `home/dot_agents/skills/matt-<name>/` for a renamed skill, after which the `name:` field and the calls above are edited again.
  `git diff` after an update shows any call upstream added under the old name.
- **A new Claude Code built-in can create a new clash.**
  Its built-in skill names are compiled into the binary rather than listed anywhere, so a clash is found when a built-in goes missing, and the fix is another rename under this rule.

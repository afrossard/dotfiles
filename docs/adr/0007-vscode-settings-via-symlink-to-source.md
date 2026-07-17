# VS Code settings, tracked via a symlink into the source directory

VS Code's user `settings.json` is authored configuration - formatter choices, editor and git preferences - that this repo declined to track, on the reading that a file an application rewrites at will is editor GUI state.
We now track it, delivered as a symlink back into the source directory, so VS Code rewrites the version-controlled file directly and no drift-and-recapture loop is needed at all.
Claude Code's `~/.claude/settings.json` is explicitly left out, because it is a genuinely different problem (see Considered options).

This reverses the VS Code half of ADR-0001, which deferred "application-rewritten settings" as one undifferentiated problem.
It is two problems.
The deferral turned on a real hazard - under ADR-0003's file mode, a file the application rewrites behind chezmoi's back registers as an uncaptured edit, and an indicator lit most of the time is one nobody reads - but that hazard is a property of *how often the app writes* and *what it writes*, not of the file being application-rewritten.
VS Code writes `settings.json` rarely, only when the user changes a setting, and everything it writes is authored config.
Claude Code rewrites `~/.claude/settings.json` on every `/model`, mixing `model` and `tui` session state in with `hooks` and `permissions`.
Only the second is the hazard the deferral described.

## Considered options

**A whole-file re-add loop** - track `settings.json` as an ordinary file and let the drift indicator prompt a `chezmoi re-add` after VS Code writes it - was the intuitive path, and the one that reads as "just like editing `~/.zshrc`."
It is sound in isolation.
It falls only when combined with the cross-OS requirement below, and the symlink beats it outright regardless, by needing no re-add step: the source file is what VS Code writes.

**Serving both macOS and Linux from a single source via a template** is chezmoi's documented recipe for one content at two OS-specific paths: a `.chezmoitemplates` file, a wrapper `.tmpl` at each path, and `.chezmoiignore` conditionals.
It is incompatible with capturing VS Code's own writes.
Measured against chezmoi 2.71.0, and stated in `chezmoi re-add --help`: "chezmoi will not overwrite templates."
A templated `settings.json` therefore makes `chezmoi re-add` a silent no-op - it exits 0 and captures nothing - so a change made in VS Code would never reach the repo and the indicator would stay lit forever.
This is the exact rot ADR-0003 guards against, reintroduced by the template rather than by frequent writes.

**Two plain per-OS copies, `.chezmoiignore`-selected,** keeps re-add working but stores the same JSON twice.
Re-adding on the Mac updates only the Mac copy; the Linux copy rots, and nothing reports it, because that path is not a target on the Mac.
It manufactures silent divergence inside the source tree - the precise failure this repo exists to prevent - and was rejected on that ground.

**The symlink into the source directory** is chezmoi's own recommended handling for externally-modified files, and `settings.json` is the example the documentation uses.
The target is a `symlink_` entry whose contents resolve through `{{ .chezmoi.sourceDir }}`, the same per-machine source path ADR-0003 already records at `chezmoi init`; the two OS paths are two such entries, `.chezmoiignore`-selected, both pointing at one raw file.
The one claim that could have sunk it - ADR-0001's assertion that an atomic rewrite "would destroy a symlink anyway" - was measured and found false for this Mac's VS Code.
Both write paths were exercised against a symlinked `settings.json`: a Settings-UI toggle and a text-editor `Cmd+S`.
Both wrote in place, leaving the symlink intact and the source-directory inode unchanged (chezmoi 2.71.0, VS Code as installed July 2026).
The severance premise is disproven here, and where it is not disproven - see the residual risk below - it is caught, not silent.

**Claude Code's `~/.claude/settings.json`** stays out, and is not merely deferred but has no current use case.
It mixes session state (`model`, `tui`) with authored config (`hooks`, `permissions`, `env`) in one file, so neither the symlink nor a whole-file re-add can own it without propagating the current model to every machine.
Owning it needs the key-level `modify_` script ADR-0001 describes, and that waits until there is a reason to write it.

## Consequences

- **The raw file lives inside the source root, `home/`.**
  When VS Code writes through the symlink, the source file changes, and the drift indicator's uncommitted-source mark (`r*`) lights - captured here, not yet committed.
  The remedy is `git commit && push`, which is the whole of "propagate it."
  This is one step shorter than editing `~/.zshrc`, which shows as an uncaptured edit and needs `chezmoi re-add` before the commit; the symlink skips that, because there is nothing to recapture.
- **`chezmoi status` stays clean on every VS Code write.**
  The target is still the symlink chezmoi wrote, so neither drift axis moves.
  The change surfaces only as the source-repo `r*` mark, which is exactly where a change that belongs in git should surface.
- **The uncommitted-source mark stays meaningful.**
  ADR-0003 scoped `r*` to the source root so the repo's own constantly-edited ADRs, skills and tests - all outside `home/` - would not keep it lit.
  Placing the raw file inside `home/` puts VS Code's rare, wanted changes on that mark without putting the repo's own churn there.
  Signal, not noise.
- **A severance elsewhere degrades to a visible fault, never a silent one.**
  The in-place write is proven only for this Mac's VS Code; Linux VS Code, a future version, or Codespaces are unverified.
  If any of them ever replaces the symlink with a regular file, that file no longer matches what chezmoi wrote, so `chezmoi status` reports an uncaptured edit and the indicator lights.
  The failure is caught by the safety net this repo already runs, which is the condition on which the residual risk was accepted rather than pre-empted.
- **The raw file is `.chezmoiignore`d so it is not itself delivered to `$HOME`.**
  Verified against chezmoi 2.71.0: with the ignore in place the file is referenced by the symlink and never written as a target of its own.
- **The `.chezmoiignore` names the whole per-OS `Code` subtree, not just the file.**
  Ignoring only the target `settings.json` still leaves chezmoi creating an empty `Code/User/` directory on the OS that does not use it.
  Measured against 2.71.0: a stray `~/.config/Code/User/` appeared on macOS until the ignore was widened to `.config/Code` (and symmetrically `Library/Application Support/Code` on Linux).
  The shared `Library`, `Application Support` and `.config` parents are never named, so nothing else under them is touched.
- **Every directory in the macOS path carries `private_`, because managing a target under `~/Library` otherwise relaxes it.**
  `~/Library` and its `Application Support` subtree are `0700` on macOS, and chezmoi manages every source directory it must descend through.
  A plain directory entry carries chezmoi's default `0755`, so the first apply widens `~/Library` to world-readable.
  Measured against 2.71.0: adopting the pre-existing dirs under `--force` took all of them from `0700` to `0755` in one sweep - a real privacy regression on a system directory, caught only by reading the mode back.
  The chain is therefore `private_Library/private_Application Support/private_Code/private_User/`, which reproduces `0700`; this is the same lesson ADR-0003 records for `~/.ssh`, in the opposite direction.
  The Linux chain carries `private_` on `Code` and `User` too, matching XDG's `0700` intent for `~/.config`, though that half is unverified on a Linux target.
- **This does not soften ADR-0003.**
  File mode remains the rule; this is one entry delivered as a symlink because the application writes it, which is the documented exception, not a reversal of the default.

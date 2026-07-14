# Default agent instructions

These are common instructions for agents across all scenarios.

## General Guidelines
- Never use the em dash. Use plain dash "-" instead
- When writing commit messages, NEVER auto-add your agent name as co-author
- Never manually modify CHANGELOG.md files or any files that are marked as auto-generated
- When writing or substantially editing long Markdown files, put each full sentence on its own Line. Preserve normal Markdown structure, but avoid wrapping multiple sentences onto one physical line.
- When making technical decisions, do not give much weight to development cost. Instead, prefer quality, simplicity, robustness, scalability, and long term maintainability.
- Prefer an established tool over a hand-rolled one, even when the hand-rolled one looks small. Discount the cost of writing it; do not discount the cost of being its only maintainer, or of a stranger having to read it. Before rejecting a candidate tool, check whether it is genuinely a standard or merely popular, and say which.
- Do not argue against a tool from memory of how it behaves. Install it in a scratch directory, drive it against a fake target, and read its own documentation first. Assertions about caching, defaults, flags, and file modes are cheap to test and frequently wrong. When a test contradicts an argument that has already been made, retract the argument explicitly rather than quietly moving on.
- When doing bug fixes, always start with reproducing the bug in an E2E setting as closely aligned with how an end user would experience it as possible. This makes sure you find the real problem so your fix will actually solve it.
- When end-to-end testing a product, be picky about the UI you see and be obsessed with pixel perfection. If something clearly looks off, even if it is not directly related to what you are doing, try to get it fixed.
- Apply that same high standard to engineering excellence: lint, test failures, and test flakiness. If you see one, even if it is not caused by what you are working on right now, still get it fixed.
- A repo's scope is bounded by its name. Do not bundle adjacent concerns into a repo because they are convenient to put there; propose a separate repo instead. A repo named `dotfiles` holds dotfiles, not container images or editor GUI state.
- Do not invent numbered labels for concepts and then expect them to be tracked. Give concepts real names.

## Memory

Persist durable facts as Markdown, never in machine-local agent state directories.
Anything under `~/.claude/projects/` is lost on machine re-install and must not be used for memory.

- Facts that apply everywhere go in `~/AGENTS.md`, which is symlinked to `~/.claude/CLAUDE.md`.
- Facts that apply to one repo go in that repo's `AGENTS.md`, committed alongside the code.


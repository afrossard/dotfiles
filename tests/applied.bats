#!/usr/bin/env bats
#
# The tree chezmoi delivers, asserted the way a user meets it: a mode, a symlink's
# target, a file's contents. Nothing here reads chezmoi's source attributes or its
# status; the test walks the applied $HOME, not home/. This is the applied-tree half
# of the harness, the counterpart to the rendered-prompt half in prompt.bats.

load helpers

setup() { apply_home; }

# Portable octal mode. `stat -f` is BSD-only and `stat -c` is GNU-only; perl's stat
# is neither, and the suite already leans on perl elsewhere.
mode_of() {
  perl -e 'printf "%03o\n", (stat $ARGV[0])[2] & 07777' "$1"
}

# Where a path lands after every symlink on the way is resolved.
resolves_to() {
  perl -MCwd -e 'print Cwd::abs_path($ARGV[0]) // ""' "$1"
}

@test "the ssh directory is delivered private" {
  # private_dot_ssh carries the private_ attribute so the directory lands at 0700,
  # not the 0755 a plain directory would. A world-readable ~/.ssh is a finding.
  assert_equal "700" "$(mode_of "$HOME/.ssh")"
}

@test "the ssh config is delivered private but is still an ordinary file" {
  # private_ on the file too: 0600. The design leans on private_ setting the mode
  # without turning the entry into anything other than a regular file.
  assert_equal "600" "$(mode_of "$HOME/.ssh/config")"
  [ -f "$HOME/.ssh/config" ]
  [ ! -L "$HOME/.ssh/config" ]
}

@test "the ssh config carries no colima Include" {
  # colima writes an `Include colima` line into ~/.ssh/config on first run. This
  # config is chezmoi's, delivered whole, and must not carry that machine-local
  # graft: its presence would mean the tracked file had been polluted at the source.
  run cat "$HOME/.ssh/config"
  refute_contains "colima" "$output"
  refute_contains "Include" "$output"
}

@test "the global agent instructions reach ~/.claude/CLAUDE.md through ~/AGENTS.md" {
  # symlink_CLAUDE.md delivers a link, not a copy, so editing ~/AGENTS.md is editing
  # what Claude reads. The link is relative (../AGENTS.md); what matters to a user is
  # where it resolves.
  [ -L "$HOME/.claude/CLAUDE.md" ]
  [ -f "$HOME/AGENTS.md" ]
  assert_equal "$(resolves_to "$HOME/AGENTS.md")" "$(resolves_to "$HOME/.claude/CLAUDE.md")"
}

@test "the link resolves to a real file, not a dangling target" {
  # A relative symlink is only as good as the file it points at existing after apply.
  [ -e "$HOME/.claude/CLAUDE.md" ]
  run cat "$HOME/.claude/CLAUDE.md"
  assert_contains "agent instructions" "$output"
}

# A fake `gh` on PATH, standing in for the real one: `git credential fill` shells
# out to whatever `gh` resolves to, and asserting on that call is how the shipped
# config is proven to work without a real `gh auth login` in the test environment.
stub_gh() {
  mkdir -p "$BATS_TEST_TMPDIR/stubbin"
  cat >"$BATS_TEST_TMPDIR/stubbin/gh" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "auth" ] && [ "$2" = "git-credential" ]; then
  cat >/dev/null
  echo "username=x-access-token"
  echo "password=stub-token"
fi
EOF
  chmod +x "$BATS_TEST_TMPDIR/stubbin/gh"
}

@test "git resolves a credential helper for github after apply" {
  apply_home
  stub_gh
  # apply_home isolates git with GIT_CONFIG_GLOBAL, which bypasses the file
  # chezmoi just delivered; unset it so git falls back to its own default
  # resolution of $HOME/.config/git/config, the way a real user meets it.
  unset GIT_CONFIG_GLOBAL
  run env PATH="$BATS_TEST_TMPDIR/stubbin:$PATH" \
    bash -c 'printf "protocol=https\nhost=github.com\n" | git credential fill'
  assert_contains "password=stub-token" "$output"
}

@test "a stale config.local does not suppress the tracked credential helper" {
  apply_home
  stub_gh
  # The exact shape `gh auth setup-git` leaves behind: an empty `helper =`
  # reset line, then a helper pinned to an absolute path from another target.
  mkdir -p "$HOME/.config/git"
  cat >"$HOME/.config/git/config.local" <<'EOF'
[credential]
	helper =
	helper = !/nonexistent/gh auth git-credential
EOF
  unset GIT_CONFIG_GLOBAL
  run env PATH="$BATS_TEST_TMPDIR/stubbin:$PATH" \
    bash -c 'printf "protocol=https\nhost=github.com\n" | git credential fill'
  # The stale absolute-path helper runs first and fails to resolve; the
  # tracked block sits after [include], so git still falls through to it
  # rather than treating the failed stale helper as the final answer.
  assert_contains "password=stub-token" "$output"
}

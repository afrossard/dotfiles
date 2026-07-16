#!/usr/bin/env bats
#
# The bare command. The prompt raises a hand; this is the half that says what to do
# about it, and the half that must never suggest a command that destroys the work
# another block is reporting.

load helpers

setup() { setup_target; }

@test "uncaptured edit: names the file, the remedy, and what apply would do" {
  printf 'edited in place\n' >"$HOME/.zshrc"
  run chezmoi-drift
  assert_equal "$status" 0
  assert_contains "1 uncaptured edit" "$output"
  assert_contains ".zshrc" "$output"
  assert_contains "chezmoi re-add" "$output"
  assert_contains "DELETES" "$output"
}

@test "unapplied change: names the file and the remedy" {
  printf 'a v2\n' >"$REPO/home/dot_a"
  git -C "$REPO" commit -qam "change a"
  git -C "$REPO" push -q origin main
  run chezmoi-drift
  assert_contains "1 unapplied change" "$output"
  assert_contains ".a" "$output"
  assert_contains "chezmoi apply" "$output"
}

@test "source uncommitted: names the file and the commit remedy" {
  printf 'edited in place\n' >"$HOME/.zshrc"
  chezmoi re-add --force >/dev/null
  run chezmoi-drift
  assert_contains "uncommitted" "$output"
  assert_contains "dot_zshrc" "$output"
  assert_contains "commit" "$output"
}

@test "unpublished commit: names the push remedy against the repo, not the source root" {
  printf 'a v2\n' >"$REPO/home/dot_a"
  git -C "$REPO" commit -qam "change a"
  chezmoi apply >/dev/null
  run chezmoi-drift
  assert_contains "1 unpublished commit" "$output"
  assert_contains "push" "$output"
  # The remedy must target the git top level; the source root is home/, one below.
  assert_contains "$REPO" "$output"
  refute_contains "$REPO/home" "$output"
}

@test "unfetched commits: says git pull, never chezmoi update" {
  # chezmoi update is git pull *followed by* apply, which deletes an uncaptured edit
  # in the same sweep. pull alone turns an unfetched change into an unapplied one,
  # whose own block then governs the safe apply.
  other_machine_pushes 2
  printf 'edited in place\n' >"$HOME/.zshrc"
  run chezmoi-drift
  assert_contains "2 unfetched commits" "$output"
  assert_contains "pull" "$output"
  refute_contains "chezmoi update" "$output"
}

@test "no suggested command destroys another block's work" {
  # Every block present at once. Nothing in the output may tell you to run chezmoi
  # update, which eats the uncaptured edit the first block is reporting.
  other_machine_pushes 2
  printf 'a v2\n' >"$REPO/home/dot_a"
  git -C "$REPO" commit -qam "change a"
  printf 'uncommitted\n' >>"$REPO/README.md"
  printf 'edited in place\n' >"$HOME/.zshrc"
  run chezmoi-drift
  refute_contains "chezmoi update" "$output"
  assert_contains "uncaptured edit" "$output"
  assert_contains "unapplied change" "$output"
  assert_contains "unfetched" "$output"
}

@test "plurals read correctly" {
  printf 'edited in place\n' >"$HOME/.zshrc"
  printf 'edited in place\n' >"$HOME/.a"
  run chezmoi-drift
  assert_contains "2 uncaptured edits" "$output"
  assert_contains "the repo has never seen them" "$output"
}

@test "singular reads correctly" {
  printf 'edited in place\n' >"$HOME/.zshrc"
  run chezmoi-drift
  assert_contains "1 uncaptured edit -" "$output"
  assert_contains "the repo has never seen it" "$output"
  refute_contains "1 uncaptured edits" "$output"
}

# --- the quiet cases each get one honest line --------------------------------

@test "in sync says so" {
  run chezmoi-drift
  assert_equal "$status" 0
  assert_contains "in sync" "$output"
}

@test "no upstream: publication state is unknown, and names the branch" {
  git -C "$REPO" checkout -q -b experiment
  run chezmoi-drift
  assert_equal "$status" 0
  assert_contains "publication state unknown" "$output"
  assert_contains "experiment" "$output"
  # It must not claim to be in sync when it cannot see the publication axis.
  refute_contains "in sync" "$output"
}

@test "an upstream that is gone is not an upstream" {
  # `git rev-parse` echoes an argument it cannot resolve to stdout, so a branch
  # whose upstream was deleted and pruned prints the literal `@{upstream}` while
  # exiting 128. Testing that output for emptiness reads it as a healthy upstream,
  # then reads 0/0 from a rev-list that failed too, and reports commits which may
  # exist on this machine alone as published.
  #
  # Reaching this needs `fetch.prune`, which no target here sets today - it is one
  # config line away, and git config is not managed by this repo. The guard is one
  # line; this test is what says why it is there.
  upstream_goes_away
  run chezmoi-drift
  assert_equal "$status" 0
  assert_contains "publication state unknown" "$output"
  refute_contains "in sync" "$output"
}

@test "a gone upstream drops only the marks it cannot measure" {
  upstream_goes_away
  printf 'edited in place\n' >"$HOME/.zshrc"
  assert_badge "⌂l⇡1"
}

@test "an unreadable axis does not silence the axes that were read" {
  # Measured clean is worth saying. Refusing to overclaim `in sync` must not mean
  # staying quiet about the two boundaries it did read.
  git -C "$REPO" checkout -q -b experiment
  run chezmoi-drift
  assert_contains "✓ nothing to capture or apply" "$output"
  assert_contains "publication state unknown" "$output"
  # The tick still never claims the word it cannot stand behind.
  refute_contains "publish" "${output%%publication*}"
}

@test "the tick claims all three boundaries only when all three were read" {
  run chezmoi-drift
  assert_contains "✓ in sync - nothing to capture, apply, or publish" "$output"
}

@test "no tick at all when the local axis itself could not be read" {
  # Nothing was measured clean, so there is nothing to affirm.
  chmod 000 "$HOME/.zshrc"
  run chezmoi-drift
  chmod 644 "$HOME/.zshrc"
  assert_contains "drift state unknown" "$output"
  refute_contains "✓" "$output"
}

@test "no upstream still reports the axes it can measure" {
  git -C "$REPO" checkout -q -b experiment
  printf 'edited in place\n' >"$HOME/.zshrc"
  run chezmoi-drift
  assert_contains "1 uncaptured edit" "$output"
  assert_contains "publication state unknown" "$output"
}

@test "chezmoi absent says so rather than nothing" {
  local bin="$BATS_TEST_TMPDIR/only-drift"
  mkdir -p "$bin"
  ln -sf "$HOME/.local/bin/chezmoi-drift" "$bin/chezmoi-drift"
  run env PATH="$bin:/usr/bin:/bin" chezmoi-drift
  assert_equal "$status" 0
  assert_contains "not managing this machine" "$output"
}

@test "no source directory says so rather than nothing" {
  rm -rf "$REPO"
  run chezmoi-drift
  assert_equal "$status" 0
  assert_contains "not managing this machine" "$output"
}

@test "an unknown argument is refused rather than guessed at" {
  run chezmoi-drift --explain-everything
  assert_equal "$status" 2
}

@test "a stray extra argument is refused rather than ignored" {
  run chezmoi-drift --prompt --explain
  assert_equal "$status" 2
}

# --- it never claims safety it did not measure -------------------------------

@test "a source that is not a git repo does not claim to be published" {
  # chezmoi's own `chezmoi init` with no repo URL leaves a plain source directory.
  # Publication cannot be measured at all there, and saying so is the whole job.
  rm -rf "$REPO/.git"
  run chezmoi-drift
  assert_equal "$status" 0
  assert_contains "publication state unknown" "$output"
  assert_contains "not a git repository" "$output"
  refute_contains "in sync" "$output"
}

@test "a source that is not a git repo still reports the drift it can see" {
  rm -rf "$REPO/.git"
  printf 'edited in place\n' >"$HOME/.zshrc"
  run chezmoi-drift
  assert_contains "1 uncaptured edit" "$output"
  assert_contains "publication state unknown" "$output"
}

@test "a chezmoi that cannot look is not a chezmoi that found nothing" {
  # Measured: an unreadable target makes `chezmoi status` exit 1 while
  # `chezmoi source-path` still exits 0, so this is not the unmanaged case. The
  # output is empty either way, and calling an unknown state "in sync" would call
  # a possible uncaptured edit safe - the one unforgivable answer.
  chmod 000 "$HOME/.zshrc"
  run chezmoi-drift
  chmod 644 "$HOME/.zshrc"
  assert_equal "$status" 0
  assert_contains "drift state unknown" "$output"
  refute_contains "in sync" "$output"
}

@test "the badge stays mute when chezmoi cannot look" {
  # The prompt degrades quietly on an axis it cannot measure; the explainer speaks.
  chmod 000 "$HOME/.zshrc"
  run --separate-stderr badge
  chmod 644 "$HOME/.zshrc"
  assert_equal "$status" 0
  assert_equal "$stderr" ""
  refute_contains "l⇡" "$output"
}

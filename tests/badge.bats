#!/usr/bin/env bats
#
# The badge, state by state. Each state is reached by driving chezmoi and git the
# way a user would, never by faking their output, because the bug this indicator
# exists to avoid - reading the second status column and naming the remedy that
# destroys your edit - is invisible to a test that stubs chezmoi.

load helpers

setup() { setup_target; }

# --- the five marks, one at a time ------------------------------------------

@test "clean target renders no badge at all" {
  assert_badge ""
}

@test "uncaptured edit renders l-up" {
  printf 'edited in place\n' >"$HOME/.zshrc"
  assert_badge "⌂l⇡1"
}

@test "unapplied change renders l-down" {
  # Committed and pushed, so the repo is clean and only the target is behind.
  printf 'a v2\n' >"$REPO/home/dot_a"
  git -C "$REPO" commit -qam "change a"
  git -C "$REPO" push -q origin main
  assert_badge "⌂l⇣1"
}

@test "source uncommitted renders r-star" {
  printf 'edited in place\n' >"$HOME/.zshrc"
  chezmoi re-add --force >/dev/null
  # chezmoi status is empty the instant you re-add; the change is still nowhere else.
  [ -z "$(chezmoi status)" ]
  assert_badge "⌂r*"
}

@test "unpublished commit renders r-up" {
  printf 'a v2\n' >"$REPO/home/dot_a"
  git -C "$REPO" commit -qam "change a"
  chezmoi apply >/dev/null
  assert_badge "⌂r⇡1"
}

@test "unfetched commit renders r-down" {
  other_machine_pushes 1
  assert_badge "⌂r⇣1"
}

# --- the hop letter is shared within its group -------------------------------

@test "both local marks share one l" {
  printf 'b v2\n' >"$REPO/home/dot_b"
  git -C "$REPO" commit -qam "change b"
  git -C "$REPO" push -q origin main
  printf 'edited in place\n' >"$HOME/.zshrc"
  assert_badge "⌂l⇡1⇣1"
}

@test "diverged source renders one r with both marks within" {
  other_machine_pushes 2
  printf 'local\n' >>"$REPO/README.md"
  git -C "$REPO" commit -qam "local commit"
  assert_badge "⌂r⇡1⇣2"
}

@test "worst case renders all five marks" {
  # 4 behind: another machine pushes, and we fetch the refs.
  other_machine_pushes 4
  # 2 unapplied: committed in the source, not yet applied here.
  printf 'a v2\n' >"$REPO/home/dot_a"
  git -C "$REPO" commit -qam "change a"
  printf 'b v2\n' >"$REPO/home/dot_b"
  git -C "$REPO" commit -qam "change b"
  # 3 ahead: a third commit outside the source root, so it delivers nothing.
  printf 'local\n' >>"$REPO/README.md"
  git -C "$REPO" commit -qam "local commit"
  # r*: uncommitted, and outside the source root so it adds no unapplied change.
  printf 'uncommitted\n' >>"$REPO/README.md"
  # 1 uncaptured: edited directly on the target.
  printf 'edited in place\n' >"$HOME/.zshrc"
  assert_badge "⌂l⇡1⇣2r*⇡3⇣4"
}

@test "counts are per file, not per status column" {
  # An uncaptured edit reads MM: apply *would* change the target, and that is
  # exactly the apply that deletes the edit. Counting columns independently would
  # report this one file as an uncaptured edit and an unapplied change at once.
  printf 'edited in place\n' >"$HOME/.zshrc"
  printf 'edited in place\n' >"$HOME/.a"
  [ "$(chezmoi status | grep -c '^MM')" -eq 2 ]
  assert_badge "⌂l⇡2"
}

# --- degrading quietly -------------------------------------------------------

@test "no badge where chezmoi is not installed" {
  # The script is still on PATH; chezmoi is not.
  local bin="$BATS_TEST_TMPDIR/only-drift"
  mkdir -p "$bin"
  ln -sf "$HOME/.local/bin/chezmoi-drift" "$bin/chezmoi-drift"
  printf 'edited in place\n' >"$HOME/.zshrc"
  run env PATH="$bin:/usr/bin:/bin" chezmoi-drift --prompt
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "no badge where there is no source directory" {
  rm -rf "$REPO"
  run chezmoi-drift --prompt
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "no upstream drops only the marks it cannot measure" {
  git -C "$REPO" checkout -q -b experiment
  printf 'edited in place\n' >"$HOME/.zshrc"   # l-up
  printf 'b v2\n' >"$REPO/home/dot_b"          # l-down, once committed
  git -C "$REPO" commit -qam "change b"
  printf 'uncommitted\n' >>"$REPO/README.md"   # r-star
  assert_badge "⌂l⇡1⇣1r*"
}

@test "no badge on a clean target whose branch has no upstream" {
  git -C "$REPO" checkout -q -b experiment
  assert_badge ""
}

# --- the promise it must never break ----------------------------------------

@test "rendering the badge modifies nothing" {
  printf 'edited in place\n' >"$HOME/.zshrc"
  printf 'a v2\n' >"$REPO/home/dot_a"
  local before_home before_repo
  before_home="$(find "$HOME" -type f ! -path '*/chezmoi/*' -exec shasum {} + | sort)"
  before_repo="$(git -C "$REPO" status --porcelain; git -C "$REPO" rev-parse HEAD)"
  badge >/dev/null
  chezmoi-drift >/dev/null
  [ "$(find "$HOME" -type f ! -path '*/chezmoi/*' -exec shasum {} + | sort)" = "$before_home" ]
  [ "$(git -C "$REPO" status --porcelain; git -C "$REPO" rev-parse HEAD)" = "$before_repo" ]
}

#!/usr/bin/env bats
#
# Applying itself, not the tree it produces: the guarantee that `chezmoi apply` on a
# machine with no controlling terminal terminates rather than blocking on a prompt.
# This is the install.sh path - a fresh clone applied non-interactively - and the
# one case that most needs it, a $HOME whose ~/.zshrc was written by something other
# than chezmoi.

load helpers

@test "apply on a fresh home completes without a controlling terminal" {
  # The common bootstrap: nothing chezmoi did not write, so nothing to prompt about.
  # It must finish on its own with stdin closed, and deliver the tree.
  prepare_home
  run with_timeout 60 chezmoi apply
  [ "$status" -ne 124 ] || {
    echo "chezmoi apply hung on a fresh home with no TTY" >&2
    return 1
  }
  assert_equal "0" "$status"
  [ -f "$HOME/.zshrc" ]
}

@test "apply does not hang on a home whose zshrc was pre-written by something else" {
  # lessInteractive makes chezmoi refuse to silently overwrite a target it did not
  # write. Without a TTY it cannot ask, so the guarantee is not that it succeeds but
  # that it fails fast: it returns instead of blocking forever on an unanswerable
  # prompt, which is what would wedge a container build.
  prepare_home
  printf 'written by something other than chezmoi\n' >"$HOME/.zshrc"

  run with_timeout 60 chezmoi apply
  [ "$status" -ne 124 ] || {
    echo "chezmoi apply hung on a foreign ~/.zshrc with no TTY" >&2
    return 1
  }
}

@test "apply leaves a foreign zshrc intact rather than destroying it unread" {
  # The reason the prompt exists at all: the foreign file must still be there after
  # the refused apply, not silently replaced by the tracked one. This is the whole
  # point of lessInteractive over a plain overwrite.
  prepare_home
  printf 'written by something other than chezmoi\n' >"$HOME/.zshrc"

  with_timeout 60 chezmoi apply || true
  run cat "$HOME/.zshrc"
  assert_contains "written by something other than chezmoi" "$output"
}

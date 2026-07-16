#!/usr/bin/env bats
#
# The badge as starship actually renders it. The acceptance criterion is the
# rendered prompt, not the script's stdout, because the module's own wiring is
# where this feature failed in prototype: a custom module with no `when` never runs
# its command, renders nothing, and looks exactly like a clean machine.

load helpers

setup() { setup_target; }

@test "the module runs at all: a drifted target reaches the rendered prompt" {
  # Guards the prototype's silent failure. Without `when`, starship never runs the
  # command and this prompt is indistinguishable from a clean one.
  printf 'edited in place\n' >"$HOME/.zshrc"
  run render_prompt
  assert_contains "⌂l⇡1" "$output"
}

@test "the badge is leftmost, ahead of the directory" {
  printf 'edited in place\n' >"$HOME/.zshrc"
  cd "$BATS_TEST_TMPDIR"
  local line dir badge_at dir_at
  line="$(prompt_line)"
  dir="$(basename "$BATS_TEST_TMPDIR")"
  assert_contains "⌂l⇡1" "$line"
  assert_contains "$dir" "$line"
  badge_at="${line%%⌂*}"
  dir_at="${line%%$dir*}"
  [ "${#badge_at}" -lt "${#dir_at}" ]
}

@test "a clean target emits no stray space where the badge would be" {
  # The conditional format group, "([$output]($style) )", is what makes this true.
  # Without it a clean home leaks a space into every prompt forever. Verified to
  # fail against the plain format.
  local line
  line="$(prompt_line)"
  [ -n "$line" ]
  refute_contains "⌂" "$line"
  case "$line" in
    " "*)
      echo "prompt line opens with a stray space: [$line]" >&2
      return 1
      ;;
  esac
}

@test "the badge sits beside git's own arrows without ambiguity" {
  # The badge's ⇡⇣ and git_status's ⇡⇣ are the same glyphs by design; scope is
  # carried by the ⌂ and the hop letter, so both can share one line.
  printf 'a v2\n' >"$REPO/home/dot_a"
  git -C "$REPO" commit -qam "change a"
  chezmoi apply >/dev/null

  local work="$BATS_TEST_TMPDIR/work"
  git init -q -b main "$work"
  git -C "$work" commit -q --allow-empty -m one
  git -C "$work" remote add origin "$ORIGIN"

  cd "$work"
  run render_prompt
  assert_contains "⌂r⇡1" "$output"
  assert_contains "main" "$output"
}

@test "the badge is a single colour whatever the state" {
  # Presence is the signal, not hue. The destroyable case and the benign case must
  # not be distinguishable by colour.
  local uncaptured_colour unapplied_colour

  printf 'edited in place\n' >"$HOME/.zshrc"
  uncaptured_colour="$(badge_colour)"
  printf 'zshrc v1\n' >"$HOME/.zshrc"

  printf 'b v2\n' >"$REPO/home/dot_b"
  git -C "$REPO" commit -qam "change b"
  git -C "$REPO" push -q origin main
  unapplied_colour="$(badge_colour)"

  [ -n "$uncaptured_colour" ]
  [ -n "$unapplied_colour" ]
  assert_equal "$uncaptured_colour" "$unapplied_colour"
}

@test "the module stays well inside starship's command timeout" {
  printf 'edited in place\n' >"$HOME/.zshrc"
  badge >/dev/null # warm the binaries; measured cold, this is ~350ms
  local start end elapsed
  start=$(now_ms)
  badge >/dev/null
  end=$(now_ms)
  elapsed=$((end - start))
  # starship's default command_timeout is 500ms, and a timed-out module renders
  # nothing - which looks exactly like a clean machine.
  [ "$elapsed" -lt 500 ] || {
    echo "badge took ${elapsed}ms, against starship's 500ms command_timeout" >&2
    return 1
  }
}

@test "chezmoi delivers the script executable" {
  # ADR-0003 recorded "no executable dotfiles" as a reason symlink mode was viable.
  # This file is the counter-example, and the executable_ attribute is what carries it.
  [ -x "$HOME/.local/bin/chezmoi-drift" ]
}

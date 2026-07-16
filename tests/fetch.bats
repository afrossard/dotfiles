#!/usr/bin/env bats
#
# The daily fetch. This is the only part of the indicator that touches the network,
# and the prompt must never wait on it. A rarely-used durable target still has to
# learn it is behind, which is the whole reason the fetch exists at all.

load helpers

setup() { setup_target; }

@test "a stale stamp triggers a fetch, and the badge learns it is behind" {
  # Another machine pushes. This target's refs are stale and nothing has fetched.
  local clone="$BATS_TEST_TMPDIR/other"
  git clone -q "$ORIGIN" "$clone"
  echo elsewhere >>"$clone/README.md"
  git -C "$clone" commit -qam elsewhere
  git -C "$clone" push -q origin main

  rm -f "$XDG_CACHE_HOME/chezmoi-drift/fetch"
  [ -z "$(badge)" ]   # refs are stale, so nothing is known yet

  # The fetch is detached, so it lands after the prompt has already been drawn.
  local waited=0
  while [ "$(badge)" != "⌂r⇣1" ] && [ "$waited" -lt 100 ]; do
    sleep 0.1
    waited=$((waited + 1))
  done
  assert_badge "⌂r⇣1"
}

@test "a fresh stamp fetches nothing" {
  local clone="$BATS_TEST_TMPDIR/other"
  git clone -q "$ORIGIN" "$clone"
  echo elsewhere >>"$clone/README.md"
  git -C "$clone" commit -qam elsewhere
  git -C "$clone" push -q origin main

  touch "$XDG_CACHE_HOME/chezmoi-drift/fetch"
  badge >/dev/null
  sleep 1
  # Still silent: the stamp is fresh, so the refs were never refreshed.
  assert_badge ""
}

@test "the stamp is written before the fetch, so a failing fetch is not retried per prompt" {
  # An unreachable origin is the common case for this: a laptop on a train.
  git -C "$REPO" remote set-url origin "$BATS_TEST_TMPDIR/nowhere.git"
  rm -f "$XDG_CACHE_HOME/chezmoi-drift/fetch"
  badge >/dev/null
  [ -f "$XDG_CACHE_HOME/chezmoi-drift/fetch" ]
}

@test "an unreachable origin costs the prompt nothing and says nothing" {
  # A laptop on a train. The fetch is detached, so the badge must not wait on it.
  git -C "$REPO" remote set-url origin "$BATS_TEST_TMPDIR/nowhere.git"
  rm -f "$XDG_CACHE_HOME/chezmoi-drift/fetch"
  badge >/dev/null # warm the binaries; this is a budget, not a benchmark
  rm -f "$XDG_CACHE_HOME/chezmoi-drift/fetch"
  local start end elapsed
  start=$(now_ms)
  run badge
  end=$(now_ms)
  elapsed=$((end - start))
  assert_equal "$status" 0
  assert_equal "$output" ""
  [ "$elapsed" -lt 500 ] || {
    echo "badge took ${elapsed}ms against an unreachable origin" >&2
    return 1
  }
}

@test "the fetch does not hold starship's pipe open" {
  # The fetch is detached with its streams closed. If it inherited the pipe,
  # reading the module's output would block until the fetch finished.
  render_prompt >/dev/null # warm the binaries
  rm -f "$XDG_CACHE_HOME/chezmoi-drift/fetch"
  local start end elapsed
  start=$(now_ms)
  render_prompt >/dev/null
  end=$(now_ms)
  elapsed=$((end - start))
  [ "$elapsed" -lt 1000 ] || {
    echo "rendering the prompt took ${elapsed}ms with a fetch due" >&2
    return 1
  }
}

@test "an unwritable cache costs a stale count, not a line of stderr per prompt" {
  # Found on a real target, where ~/.cache could not be created: mkdir and touch
  # complained, and starship shows a custom module's stdout while its stderr goes
  # straight to the terminal - so this printed two lines above every prompt.
  rm -rf "$XDG_CACHE_HOME"
  mkdir -p "$XDG_CACHE_HOME"
  chmod 500 "$XDG_CACHE_HOME"
  printf 'edited in place\n' >"$HOME/.zshrc"

  run --separate-stderr badge
  chmod 700 "$XDG_CACHE_HOME"

  assert_equal "$status" 0
  assert_equal "$stderr" ""
  # The axes it can still measure are unaffected.
  assert_equal "$output" "⌂l⇡1"
}

@test "no upstream means no fetch is attempted" {
  git -C "$REPO" checkout -q -b experiment
  rm -f "$XDG_CACHE_HOME/chezmoi-drift/fetch"
  badge >/dev/null
  # Nothing to fetch against, so the stamp is not even claimed.
  [ ! -f "$XDG_CACHE_HOME/chezmoi-drift/fetch" ]
}

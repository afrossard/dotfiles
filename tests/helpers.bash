# Builds a real target for the drift indicator to measure: a real chezmoi source
# directory, a real git repo with a real origin, and a real $HOME that chezmoi has
# applied. Nothing here is a stub. The indicator is exercised the way a user meets
# it - as the file chezmoi delivered, on PATH, rendered by starship.
#
# This harness is bash because bats is bash; a bats file is a bash script and the
# framework has no other mode. It does not make the subject bash: everything under
# test is reached as a subprocess, and chezmoi-drift itself is zsh (ADR-0004).

# `run --separate-stderr`, which the fetch suite needs to prove the prompt path
# never speaks on stderr, is 1.5.0+.
bats_require_minimum_version 1.5.0

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Every state in the acceptance criteria is reached by driving the same commands a
# user would. These helpers name the states; they do not fake them.

setup_target() {
  export HOME="$BATS_TEST_TMPDIR/home"
  export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/cache"
  export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
  export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
  export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/gitconfig"
  : >"$GIT_CONFIG_GLOBAL"

  ORIGIN="$BATS_TEST_TMPDIR/origin.git"
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$HOME"

  git init -q --bare -b main "$ORIGIN"
  git init -q -b main "$REPO"

  # Shaped like the real repo: .chezmoiroot names home/ as the source root, so the
  # source directory and the git top level are deliberately not the same path.
  echo home >"$REPO/.chezmoiroot"
  mkdir -p "$REPO/home/dot_config" "$REPO/home/dot_local/bin"
  cp "$PROJECT_ROOT/home/.chezmoi.toml.tmpl" "$REPO/home/.chezmoi.toml.tmpl"
  cp "$PROJECT_ROOT/home/dot_config/starship.toml" "$REPO/home/dot_config/starship.toml"
  cp "$PROJECT_ROOT/home/dot_local/bin/executable_chezmoi-drift" \
    "$REPO/home/dot_local/bin/executable_chezmoi-drift"
  printf 'zshrc v1\n' >"$REPO/home/dot_zshrc"
  printf 'a v1\n' >"$REPO/home/dot_a"
  printf 'b v1\n' >"$REPO/home/dot_b"
  # Outside the source root, so changing it moves the repo without touching $HOME.
  printf 'readme\n' >"$REPO/README.md"

  git -C "$REPO" add -A
  git -C "$REPO" commit -qm "initial"
  git -C "$REPO" remote add origin "$ORIGIN"
  git -C "$REPO" push -q -u origin main

  chezmoi init --source="$REPO" >/dev/null
  chezmoi apply >/dev/null

  # ~/.local/bin is on PATH from dot_zshrc; the module inherits it via starship.
  export PATH="$HOME/.local/bin:$PATH"
  export STARSHIP_CONFIG="$HOME/.config/starship.toml"
  export STARSHIP_CACHE="$BATS_TEST_TMPDIR/starship-cache"
  export STARSHIP_SHELL=zsh

  # A fresh stamp keeps the daily fetch from firing during tests that are not about
  # it. The fetch has its own test, which removes this.
  mkdir -p "$XDG_CACHE_HOME/chezmoi-drift"
  touch "$XDG_CACHE_HOME/chezmoi-drift/fetch"
}

# A second clone, standing in for another machine pushing to the shared origin.
other_machine_pushes() {
  local n="${1:-1}" clone="$BATS_TEST_TMPDIR/other"
  if [ ! -d "$clone" ]; then
    git clone -q "$ORIGIN" "$clone"
  fi
  local i
  for ((i = 0; i < n; i++)); do
    echo "from elsewhere $RANDOM$i" >>"$clone/README.md"
    git -C "$clone" commit -qam "elsewhere $i"
  done
  git -C "$clone" push -q origin main
  # The indicator reads cached refs; refreshing them is the fetch's job, done here
  # explicitly so a test that is not about the fetch stays deterministic.
  git -C "$REPO" fetch -q origin
}

badge() {
  chezmoi-drift --prompt
}

# What starship actually puts on the line, with the zsh escape wrappers and colour
# removed. Asserting here rather than on the script's stdout is what makes the
# module's own wiring - `when`, the conditional format group, the ordering - part of
# the test rather than an assumption.
render_prompt() {
  starship prompt --cmd-duration 0 2>/dev/null |
    perl -pe 's/\e\[[0-9;]*m//g; s/%[{}]//g'
}

# The line the badge actually shares with the directory. starship's add_newline
# defaults to true, so the rendered prompt opens with a blank line; asserting on
# that one passes whatever the module does.
prompt_line() {
  render_prompt | grep -v '^$' | head -1
}

# A real millisecond clock. `date +%s000` appends a literal 000 and so resolves to
# whole seconds: it reads 0ms or 1000ms depending only on whether a second boundary
# was crossed, which makes a sub-second budget untestable. BSD date has no %N.
now_ms() {
  perl -MTime::HiRes=time -e 'printf "%.0f\n", time * 1000'
}

# The colour starship wraps the badge in, as an escape sequence.
badge_colour() {
  starship prompt --cmd-duration 0 2>/dev/null |
    perl -ne 'print $1 if /(\e\[[0-9;]*m)[^\e]*⌂/'
}

# Assertions return non-zero explicitly rather than leaning on errexit. bats runs
# under `env bash`, which on macOS is the system bash 3.2, and bash 3.2 does not
# apply `set -e` to a bare `[[ ]]`: a failing one mid-test lets the test pass. That
# is the same class of silent pass as a custom module with no `when`, and it is not
# worth carrying in a suite whose whole job is to notice things.

assert_contains() {
  case "$2" in *"$1"*) return 0 ;; esac
  {
    echo "expected output to contain: $1"
    echo "actual output:"
    printf '%s\n' "$2"
  } >&2
  return 1
}

refute_contains() {
  case "$2" in *"$1"*) ;; *) return 0 ;; esac
  {
    echo "expected output NOT to contain: $1"
    echo "actual output:"
    printf '%s\n' "$2"
  } >&2
  return 1
}

assert_equal() {
  [ "$1" = "$2" ] && return 0
  {
    echo "expected: $2"
    echo "actual:   $1"
  } >&2
  return 1
}

assert_badge() {
  local expected="$1"
  local actual
  actual="$(badge)"
  if [ "$actual" != "$expected" ]; then
    echo "expected badge: '$expected'" >&2
    echo "actual badge:   '$actual'" >&2
    echo "chezmoi status:" >&2
    chezmoi status >&2
    echo "git status:" >&2
    git -C "$REPO" status --short --branch >&2
    return 1
  fi
}

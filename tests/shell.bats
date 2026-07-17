#!/usr/bin/env bats
#
# The shell the dotfiles configure, exercised by sourcing the delivered ~/.zshrc in a
# fresh non-interactive zsh and reading what it left behind. The contract under test
# is ADR-0002's: probe for a tool at run time, and let its absence be a missing
# feature rather than an error. So each axis is asserted as "wired in exactly when the
# tool is present", which holds on a laptop that has the tool and on a bare container
# that does not, without either faking the tool or reaching inside the file.

load helpers

setup() { apply_home; }

@test "startup neither errors nor hangs without a controlling terminal" {
  # The umbrella guarantee: brew probing, compinit, the starship guard and the
  # ~/.zshrc.d loop all run with stdin closed and none of them stalls or complains.
  # compinit is invoked -i precisely so an insecure fpath entry is ignored rather
  # than turned into a prompt that a container with no TTY could never answer.
  run --separate-stderr with_timeout 30 zsh -fc 'source $HOME/.zshrc'
  [ "$status" -ne 124 ] || {
    echo "sourcing ~/.zshrc hung with no TTY" >&2
    return 1
  }
  assert_equal "0" "$status"
  assert_equal "" "$stderr"
}

@test "homebrew's environment is loaded exactly when brew is present at a known path" {
  # The two candidate paths are macOS's and Linux's. On a host with brew at either,
  # its shellenv is evaluated and HOMEBREW_PREFIX is exported; on a host with neither,
  # the loop falls through silently and the shell is merely brew-less, not broken.
  local prefix
  prefix="$(run_zshrc 'print -r -- ${HOMEBREW_PREFIX:-unset}')"
  if [[ -x /opt/homebrew/bin/brew || -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    refute_contains "unset" "$prefix"
  else
    assert_equal "unset" "$prefix"
  fi
}

@test "starship is wired into the prompt exactly when starship is installed" {
  # The guard is `command -v starship`: never an unconditional eval that would make a
  # starship-less machine's shell error on every login. Present -> the precmd hook
  # its init defines exists; absent -> it does not, and startup was still clean.
  local have hooked
  have="$(run_zshrc 'command -v starship >/dev/null && echo yes || echo no')"
  hooked="$(run_zshrc 'print -r -- ${+functions[prompt_starship_precmd]}')"
  if [ "$have" = "yes" ]; then
    assert_equal "1" "$hooked"
  else
    assert_equal "0" "$hooked"
  fi
}

@test "an absent ~/.zshrc.d is not an error" {
  # The N glob qualifier makes the empty match expand to nothing rather than to a
  # literal ~/.zshrc.d/*.zsh that source would then fail to open.
  [ ! -d "$HOME/.zshrc.d" ]
  run run_zshrc 'echo ok'
  assert_equal "ok" "$output"
}

@test "an empty ~/.zshrc.d is not an error" {
  mkdir -p "$HOME/.zshrc.d"
  run run_zshrc 'echo ok'
  assert_equal "ok" "$output"
}

@test "a populated ~/.zshrc.d has each drop-in sourced" {
  mkdir -p "$HOME/.zshrc.d"
  printf 'export ZSHRCD_ONE=one\n' >"$HOME/.zshrc.d/10-one.zsh"
  printf 'export ZSHRCD_TWO=two\n' >"$HOME/.zshrc.d/20-two.zsh"
  # A file without the .zsh suffix is not on the glob and must not be sourced.
  printf 'export ZSHRCD_SKIPPED=yes\n' >"$HOME/.zshrc.d/notes.txt"

  local out
  out="$(run_zshrc 'print -r -- ${ZSHRCD_ONE:-} ${ZSHRCD_TWO:-} ${ZSHRCD_SKIPPED:-none}')"
  assert_equal "one two none" "$out"
}

@test "shell startup runs no tool's completion generator" {
  # The regression this guards: someone adding `eval \"\$(sometool completion zsh)\"`,
  # which spawns a tool on every login to print completion code. The design instead
  # autoloads completion functions from fpath, so no such external command is run.
  # zsh's own completion machinery - compinit, the _tool autoloads, zstyle
  # :completion: - is not a generator and must not trip this.
  # `completions?` also catches the plural form (rustup completions zsh). The
  # leading space-or-start is what keeps this off zsh's own `:completion:` zstyle
  # contexts and `_tool_completions` functions, where the word is preceded by `:`
  # or `_` rather than a command boundary.
  local trace
  trace="$(zshrc_startup_trace)"
  refute_matches '(^| )completions? (zsh|bash|fish|ksh|pwsh|powershell)' "$trace"
}

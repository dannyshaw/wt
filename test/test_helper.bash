#!/usr/bin/env bash
# Common test setup for wt tests

TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"

load 'libs/bats-support/load'
load 'libs/bats-assert/load'

# Create an isolated git environment for testing
setup_test_repo() {
  export WT_REPO="$BATS_TEST_TMPDIR/repo"
  export WT_TREES="$BATS_TEST_TMPDIR/trees"
  export WT_MAX=5

  mkdir -p "$WT_REPO"
  git -C "$WT_REPO" init --quiet
  git -C "$WT_REPO" config user.name "Test"
  git -C "$WT_REPO" config user.email "test@test.com"

  # Need at least one commit for worktrees to work
  echo "init" > "$WT_REPO/README.md"
  git -C "$WT_REPO" add .
  git -C "$WT_REPO" commit --quiet -m "init"
}

# Write a .wt.yml config file to the test repo (pass content via stdin)
write_wt_config() {
  cat >"$WT_REPO/.wt.yml"
}

# Write a global ~/.wt.yml config file (pass content via stdin)
write_global_config() {
  cat >"$HOME/.wt.yml"
}

# Create a fake "origin/master" so branch operations work
setup_fake_origin() {
  local bare="$BATS_TEST_TMPDIR/origin.git"
  git clone --bare --quiet "$WT_REPO" "$bare"
  git -C "$WT_REPO" remote add origin "$bare"
  git -C "$WT_REPO" fetch --quiet origin
}

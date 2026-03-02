#!/usr/bin/env bats

load test_helper

WT="$PROJECT_DIR/wt"

# --- Help & version ---

@test "help exits 0" {
  run "$WT" help
  assert_success
  assert_output --partial "worktree manager"
}

@test "--help exits 0" {
  run "$WT" --help
  assert_success
  assert_output --partial "worktree manager"
}

@test "-h exits 0" {
  run "$WT" -h
  assert_success
  assert_output --partial "worktree manager"
}

@test "no args shows help" {
  run "$WT"
  assert_success
  assert_output --partial "worktree manager"
}

@test "--version prints version" {
  run "$WT" --version
  assert_success
  assert_output --partial "wt "
}

@test "unknown command fails" {
  run "$WT" garbage
  assert_failure
  assert_output --partial "unknown command"
}

# --- Subcommand help ---

@test "new --help" {
  run "$WT" new --help
  assert_success
  assert_output --partial "Usage: wt new"
}

@test "rm --help" {
  run "$WT" rm --help
  assert_success
  assert_output --partial "Usage: wt rm"
}

@test "mv --help" {
  run "$WT" mv --help
  assert_success
  assert_output --partial "Usage: wt mv"
}

@test "path --help" {
  run "$WT" path --help
  assert_success
  assert_output --partial "Usage: wt path"
}

@test "shell --help" {
  run "$WT" shell --help
  assert_success
  assert_output --partial "wt shell"
}

# --- Argument validation ---

@test "new without branch fails" {
  run "$WT" new
  assert_failure
  assert_output --partial "branch name required"
}

@test "rm without name fails" {
  setup_test_repo
  run "$WT" rm
  assert_failure
  assert_output --partial "name required"
}

@test "mv without path fails" {
  setup_test_repo
  run "$WT" mv
  assert_failure
  assert_output --partial "path required"
}

@test "path without name fails" {
  setup_test_repo
  run "$WT" path
  assert_failure
  assert_output --partial "name required"
}

@test "shell without arg fails" {
  run "$WT" shell
  assert_failure
  assert_output --partial "specify a shell"
}

@test "cd without shell integration fails" {
  run "$WT" cd
  assert_failure
  assert_output --partial "shell integration"
}

# --- Shell integration ---

@test "shell zsh outputs valid code" {
  run "$WT" shell zsh
  assert_success
  assert_output --partial "wt shell integration (zsh)"
  assert_output --partial "compdef _wt wt"
}

@test "shell bash outputs valid code" {
  run "$WT" shell bash
  assert_success
  assert_output --partial "wt shell integration (bash)"
  assert_output --partial "complete -F _wt_completions wt"
}

# --- Worktree operations ---

@test "new creates a worktree" {
  setup_test_repo
  setup_fake_origin

  run "$WT" new test/my-feature
  assert_success
  assert_output --partial "done:"
  [ -d "$WT_TREES/my-feature" ]
}

@test "new uses custom folder name" {
  setup_test_repo
  setup_fake_origin

  run "$WT" new test/my-feature custom-name
  assert_success
  [ -d "$WT_TREES/custom-name" ]
  [ ! -d "$WT_TREES/my-feature" ]
}

@test "new fails on duplicate folder" {
  setup_test_repo
  setup_fake_origin

  "$WT" new test/branch-a feature
  run "$WT" new test/branch-b feature
  assert_failure
  assert_output --partial "folder already exists"
}

@test "new respects WT_MAX limit" {
  setup_test_repo
  setup_fake_origin
  export WT_MAX=2

  "$WT" new test/branch-a aaa
  "$WT" new test/branch-b bbb
  run "$WT" new test/branch-c ccc
  assert_failure
  assert_output --partial "max"
}

@test "new checks out existing local branch" {
  setup_test_repo
  setup_fake_origin

  git -C "$WT_REPO" branch test/existing
  run "$WT" new test/existing
  assert_success
  assert_output --partial "existing local branch"
  [ -d "$WT_TREES/existing" ]
}

@test "rm removes a worktree" {
  setup_test_repo
  setup_fake_origin

  "$WT" new test/to-remove
  [ -d "$WT_TREES/to-remove" ]

  run "$WT" rm to-remove <<< "n"
  assert_success
  assert_output --partial "removed worktree"
  [ ! -d "$WT_TREES/to-remove" ]
}

@test "rm fails on nonexistent worktree" {
  setup_test_repo
  run "$WT" rm nonexistent
  assert_failure
  assert_output --partial "no worktree at"
}

@test "path prints worktree path" {
  setup_test_repo
  setup_fake_origin

  "$WT" new test/findme
  run "$WT" path findme
  assert_success
  assert_output "$WT_TREES/findme"
}

@test "path fuzzy matches" {
  setup_test_repo
  setup_fake_origin

  "$WT" new test/my-long-feature-name
  run "$WT" path long-feat
  assert_success
  assert_output "$WT_TREES/my-long-feature-name"
}

@test "path fails on no match" {
  setup_test_repo
  mkdir -p "$WT_TREES"
  run "$WT" path nonexistent
  assert_failure
  assert_output --partial "no worktree matching"
}

@test "ls runs without error" {
  setup_test_repo
  setup_fake_origin

  "$WT" new test/listed
  run "$WT" ls
  assert_success
  assert_output --partial "WORKTREES"
  assert_output --partial "RECENT BRANCHES"
}

@test "mv moves a worktree" {
  setup_test_repo
  setup_fake_origin

  # Create a worktree outside WT_TREES
  local outside="$BATS_TEST_TMPDIR/outside"
  git -C "$WT_REPO" worktree add "$outside" -b test/moveable

  run "$WT" mv "$outside" moved
  assert_success
  assert_output --partial "done:"
  [ -d "$WT_TREES/moved" ]
  [ ! -d "$outside" ]
}

# --- Dotfile symlinking ---

@test "new symlinks untracked dotfiles" {
  setup_test_repo
  setup_fake_origin

  # Create an untracked dotfile in the repo
  echo "test" > "$WT_REPO/.envrc"

  run "$WT" new test/with-dots
  assert_success
  [ -L "$WT_TREES/with-dots/.envrc" ]
}

@test "new does not symlink git-tracked dotfiles" {
  setup_test_repo
  setup_fake_origin

  echo "tracked" > "$WT_REPO/.tracked"
  git -C "$WT_REPO" add .tracked
  git -C "$WT_REPO" commit --quiet -m "add tracked dotfile"
  # Update origin so new branch works
  git -C "$WT_REPO" push --quiet origin master

  run "$WT" new test/no-tracked-dots
  assert_success
  [ ! -L "$WT_TREES/no-tracked-dots/.tracked" ]
}

@test "new does not symlink .git" {
  setup_test_repo
  setup_fake_origin

  run "$WT" new test/no-dotgit
  assert_success
  [ ! -L "$WT_TREES/no-dotgit/.git" ]
}

# --- Config ---

@test "fails without repo" {
  export WT_REPO="/tmp/nonexistent-$$"
  export WT_TREES="/tmp/trees-$$"
  run "$WT" new test/fail
  assert_failure
  assert_output --partial "not a git repository"
}

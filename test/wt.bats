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

@test "ls handles broken worktree with own .git directory" {
  setup_test_repo
  setup_fake_origin

  "$WT" new test/good-wt
  "$WT" new test/bad-wt

  # Corrupt bad-wt by replacing its .git file with a .git directory
  rm "$WT_TREES/bad-wt/.git"
  mkdir "$WT_TREES/bad-wt/.git"

  run "$WT" ls
  assert_success
  assert_output --partial "WORKTREES"
  assert_output --partial "good-wt"
  assert_output --partial "not a linked worktree"
}

@test "ls handles missing worktree path" {
  setup_test_repo
  setup_fake_origin

  "$WT" new test/will-vanish

  # Remove the worktree directory out from under git
  rm -rf "$WT_TREES/will-vanish"

  run "$WT" ls
  assert_success
  assert_output --partial "WORKTREES"
  assert_output --partial "missing path"
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

# --- No auto-symlink without wt.yml ---

@test "new does not auto-symlink without wt.yml" {
  setup_test_repo
  setup_fake_origin

  echo "test" > "$WT_REPO/.envrc"

  run "$WT" new test/no-auto-sym
  assert_success
  [ ! -L "$WT_TREES/no-auto-sym/.envrc" ]
}

# --- Config ---

@test "fails without repo" {
  export WT_REPO="/tmp/nonexistent-$$"
  export WT_TREES="/tmp/trees-$$"
  run "$WT" new test/fail
  assert_failure
  assert_output --partial "not a git repository"
}

# --- wt.yml config ---

@test "wt.yml symlink creates link" {
  setup_test_repo
  setup_fake_origin

  echo "direnv content" > "$WT_REPO/.envrc"
  write_wt_config <<'EOF'
post_create:
  - symlink: .envrc
EOF

  run "$WT" new test/cfg-sym
  assert_success
  [ -L "$WT_TREES/cfg-sym/.envrc" ]
}

@test "wt.yml symlink handles nested paths" {
  setup_test_repo
  setup_fake_origin

  mkdir -p "$WT_REPO/tod_project"
  echo "nested" > "$WT_REPO/tod_project/.envrc"
  write_wt_config <<'EOF'
post_create:
  - symlink: tod_project/.envrc
EOF

  run "$WT" new test/cfg-nested
  assert_success
  [ -L "$WT_TREES/cfg-nested/tod_project/.envrc" ]
}

@test "wt.yml copy copies file" {
  setup_test_repo
  setup_fake_origin

  echo "SECRET=abc" > "$WT_REPO/.env.example"
  write_wt_config <<'EOF'
post_create:
  - copy: .env.example
EOF

  run "$WT" new test/cfg-copy
  assert_success
  [ -f "$WT_TREES/cfg-copy/.env.example" ]
  [ ! -L "$WT_TREES/cfg-copy/.env.example" ]
  [ "$(cat "$WT_TREES/cfg-copy/.env.example")" = "SECRET=abc" ]
}

@test "wt.yml run executes command" {
  setup_test_repo
  setup_fake_origin

  write_wt_config <<'EOF'
post_create:
  - run: touch marker
EOF

  run "$WT" new test/cfg-run
  assert_success
  [ -f "$WT_TREES/cfg-run/marker" ]
}

@test "wt.yml run with dir" {
  setup_test_repo
  setup_fake_origin

  write_wt_config <<'EOF'
post_create:
  - run: touch marker
    dir: subdir
EOF

  # Create subdir in repo so it exists in worktree checkout
  mkdir -p "$WT_REPO/subdir"
  touch "$WT_REPO/subdir/.gitkeep"
  git -C "$WT_REPO" add subdir/.gitkeep
  git -C "$WT_REPO" commit --quiet -m "add subdir"
  git -C "$WT_REPO" push --quiet origin master

  run "$WT" new test/cfg-rundir
  assert_success
  [ -f "$WT_TREES/cfg-rundir/subdir/marker" ]
}

@test "wt.yml trees overrides default" {
  setup_test_repo
  setup_fake_origin

  local custom_trees="$BATS_TEST_TMPDIR/custom-trees"
  write_wt_config <<EOF
trees: $custom_trees
post_create: []
EOF

  unset WT_TREES
  run "$WT" new test/cfg-trees
  assert_success
  [ -d "$custom_trees/cfg-trees" ]
}

@test "wt.yml trees yields to env var" {
  setup_test_repo
  setup_fake_origin

  local custom_trees="$BATS_TEST_TMPDIR/custom-trees"
  write_wt_config <<EOF
trees: $custom_trees
post_create: []
EOF

  # WT_TREES is already set by setup_test_repo — it should take precedence
  run "$WT" new test/cfg-envpri
  assert_success
  [ -d "$WT_TREES/cfg-envpri" ]
  [ ! -d "$custom_trees/cfg-envpri" ]
}

@test "wt.yml empty post_create does nothing" {
  setup_test_repo
  setup_fake_origin

  echo "should not appear" > "$WT_REPO/.envrc"
  write_wt_config <<'EOF'
post_create: []
EOF

  run "$WT" new test/cfg-nosym
  assert_success
  [ ! -L "$WT_TREES/cfg-nosym/.envrc" ]
}

@test "wt.yml warns on missing source" {
  setup_test_repo
  setup_fake_origin

  write_wt_config <<'EOF'
post_create:
  - symlink: .nonexistent
EOF

  run "$WT" new test/cfg-miss
  assert_success
  assert_output --partial "warning:"
  assert_output --partial "not found"
}

@test "wt.yml run failure is non-fatal" {
  setup_test_repo
  setup_fake_origin

  write_wt_config <<'EOF'
post_create:
  - run: false
  - run: touch survived
EOF

  run "$WT" new test/cfg-failrun
  assert_success
  [ -f "$WT_TREES/cfg-failrun/survived" ]
}

@test "wt.yml fallback works" {
  setup_test_repo
  setup_fake_origin

  echo "legacy" >"$WT_REPO/.envrc"
  cat >"$WT_REPO/wt.yml" <<'EOF'
post_create:
  - symlink: .envrc
EOF

  run "$WT" new test/legacy-yml
  assert_success
  [ -L "$WT_TREES/legacy-yml/.envrc" ]
}

@test ".wt.yml takes precedence over wt.yml" {
  setup_test_repo
  setup_fake_origin

  echo "data" >"$WT_REPO/.envrc"
  echo "extra" >"$WT_REPO/.extra"

  # wt.yml symlinks .extra, .wt.yml symlinks .envrc
  cat >"$WT_REPO/wt.yml" <<'EOF'
post_create:
  - symlink: .extra
EOF
  write_wt_config <<'EOF'
post_create:
  - symlink: .envrc
EOF

  run "$WT" new test/precedence
  assert_success
  [ -L "$WT_TREES/precedence/.envrc" ]
  [ ! -L "$WT_TREES/precedence/.extra" ]
}

@test "global ~/.wt.yml works with repo-scoped section" {
  setup_test_repo
  setup_fake_origin

  echo "data" >"$WT_REPO/.envrc"

  # Use fake HOME so we don't touch real ~/.wt.yml
  local real_home="$HOME"
  export HOME="$BATS_TEST_TMPDIR/fakehome"
  mkdir -p "$HOME"

  cat >"$HOME/.wt.yml" <<EOF
${WT_REPO}:
  post_create:
    - symlink: .envrc
EOF

  run "$WT" new test/global-cfg
  export HOME="$real_home"
  assert_success
  [ -L "$WT_TREES/global-cfg/.envrc" ]
}

@test "per-repo .wt.yml takes precedence over global ~/.wt.yml" {
  setup_test_repo
  setup_fake_origin

  echo "data" >"$WT_REPO/.envrc"
  echo "extra" >"$WT_REPO/.extra"

  local real_home="$HOME"
  export HOME="$BATS_TEST_TMPDIR/fakehome"
  mkdir -p "$HOME"

  # Global says symlink .extra
  cat >"$HOME/.wt.yml" <<EOF
${WT_REPO}:
  post_create:
    - symlink: .extra
EOF

  # Per-repo says symlink .envrc
  write_wt_config <<'EOF'
post_create:
  - symlink: .envrc
EOF

  run "$WT" new test/local-wins
  export HOME="$real_home"
  assert_success
  [ -L "$WT_TREES/local-wins/.envrc" ]
  [ ! -L "$WT_TREES/local-wins/.extra" ]
}

# wt

A simple git worktree manager for organised branch workflows.

> [!IMPORTANT]
> You may want to consider using one of these more established tools - they're both excellent.
> I've incorporated ideas from these tools into wt, mostly to tailor it to my personal preferences.
> - [git-wt](https://github.com/k1LoW/git-wt)
> - [wtp](https://github.com/satococoa/wtp)

Keep your worktrees in one place, switch between them quickly, and see what's going on at a glance.

## Install

```sh
# Clone and symlink
git clone https://github.com/dannyshaw/wt.git ~/.wt
ln -sf ~/.wt/wt ~/.local/bin/wt

# Or just download
curl -fsSL https://raw.githubusercontent.com/dannyshaw/wt/main/wt -o ~/.local/bin/wt
chmod +x ~/.local/bin/wt
```

Make sure `~/.local/bin` is in your `PATH`.

### Shell integration

Add to your rc file for `wt cd`, auto-cd after `wt new`, and tab completions:

```sh
# ~/.zshrc
eval "$(wt shell zsh)"

# ~/.bashrc
eval "$(wt shell bash)"
```

## Usage

```
wt new <branch> [name]    Create a worktree (or move if already checked out)
wt rm <name>              Remove a worktree (prompts for branch deletion)
wt mv <path> [name]       Move an existing worktree into trees/
wt cd <name>              cd to a worktree (needs shell integration)
wt post_init <name>       Apply post-create actions to an existing worktree
wt ls [days]              List worktrees and recent branches (default: 14d)
wt path <name>            Print worktree path (supports fuzzy match)
wt help                   Show help
```

### Examples

```sh
# Create a worktree for a new feature branch (from origin/master)
wt new danny/my-feature

# Create with a custom folder name
wt new danny/my-feature myf

# Check out an existing remote branch
wt new danny/existing-branch

# List everything — worktrees, recent branches, ahead/behind, dirty state
wt ls

# Jump to a worktree (fuzzy match)
wt cd feat

# Remove a worktree (prompts about uncommitted changes and branch deletion)
wt rm my-feature

# Get the path for scripting
cd "$(wt path django)"
```

### What `wt ls` shows

```
WORKTREES

  danny/my-feature                            +3/-0 (2 uncommitted) (1 unpushed)
  ~/dev/edrolo/trees/my-feature
  master                                      +0/-0
  ~/dev/edrolo/edrolo

RECENT BRANCHES (not in a worktree, last 14d)

  2026-03-01  danny/other-thing                 +5/-12  [pushed]
  2026-02-28  danny/experiment                  +1/-0   [local only]
```

Colour-coded: green for ahead, red for behind, yellow for uncommitted changes, magenta for push status.

## Configuration

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `WT_REPO` | Auto-detected from git | Path to the main repository |
| `WT_TREES` | Sibling `trees/` dir | Where worktrees are created |
| `WT_MAX` | `15` | Maximum number of worktrees |

### Config file (`.wt.yml`)

Config is looked up in order:

1. `.wt.yml` in repo root
2. `wt.yml` in repo root (backwards compatibility)
3. `~/.wt.yml` (global, scoped by repo path)

The first match wins. Without any config, no post-create actions run.

#### Per-repo config

Place a `.wt.yml` in your repo root to control what happens after a worktree is created (via `wt new` or `wt mv`).

```yaml
# Optional: override the trees directory (env var takes precedence)
trees: ../trees

post_create:
  - symlink: .envrc           # symlink a file/dir from the main repo
  - symlink: .vscode/settings.json  # nested paths work too
  - copy: .env.example        # copy a file/dir (not a link)
  - run: npm install           # run a shell command in the worktree
  - run: uv sync
    dir: backend               # optional working directory for run
```

#### Global config (`~/.wt.yml`)

For repos you don't control (or to keep config out of the repo), use `~/.wt.yml` with sections scoped by the repo's absolute path:

```yaml
/Users/danny/dev/edrolo/edrolo:
  post_create:
    - symlink: .envrc
    - run: npm install

/Users/danny/dev/other/project:
  trees: ../worktrees
  post_create:
    - run: uv sync
```

#### Actions

| Action | Behaviour |
|--------|-----------|
| `symlink: <path>` | Create a symlink from the main repo to the worktree. Skipped if the destination already exists. |
| `copy: <path>` | Copy a file or directory from the main repo. Skipped if the destination already exists. |
| `run: <command>` | Run a shell command inside the worktree. Optional `dir:` sets the working directory (default: worktree root). |

**Notes:**

- Symlink and copy actions are idempotent — safe to re-run via `wt post_init`.
- Run actions always re-execute (useful for `npm install`, `uv sync`, etc.).
- Failed actions are non-fatal — other actions still run, and a summary is printed.

### Applying post-create to existing worktrees

If a worktree was created by other means (e.g. `git worktree add`), you can apply the `post_create` actions after the fact:

```sh
wt post_init my-feature
```

This is idempotent — symlinks and copies that already exist are skipped.

## Features

- **Auto-detection** — works without config if you're inside a git repo
- **Post-create hooks** — configure symlinks, file copies, and shell commands via `wt.yml`
- **Conflict handling** — if a branch is already checked out elsewhere, offers to move it
- **Fuzzy matching** — `wt cd` and `wt path` match by substring
- **Safe removal** — warns about uncommitted changes, prompts before deleting branches
- **Colour output** — at-a-glance status with ahead/behind, dirty state, push status (disabled when piped)
- **Bash 3.2 compatible** — works on stock macOS

## Requirements

- Git
- Bash 3.2+ (macOS default works)

## License

MIT

# wt

A simple git worktree manager for organised branch workflows.

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

Add to your rc file for `wt cd` and tab completions:

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

All config is via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `WT_REPO` | Auto-detected from git | Path to the main repository |
| `WT_TREES` | Sibling `trees/` dir | Where worktrees are created |
| `WT_MAX` | `15` | Maximum number of worktrees |

## Features

- **Auto-detection** — works without config if you're inside a git repo
- **Dotfile symlinking** — untracked dotfiles (`.envrc`, `.venv`, `.vscode`, etc.) are automatically symlinked into new worktrees
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

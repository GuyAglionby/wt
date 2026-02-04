# Changelog

## 0.1.2

### Fixed

- `wt add` incorrectly created a new uv environment (`uv venv && uv sync`) when the source worktree had a real `.venv` directory. It now always symlinks to the main worktree's venv, respecting the rule that worktrees depend on main, never on each other.
- `wt add` failed to cd into the new worktree. `find_agent_files` matched files inside `.git/worktrees/*/agent_base/`, and copying them into a linked worktree failed because `.git` is a file there, not a directory. The find now prunes `.git`.
- `wt cd` (bare, no args) printed the main worktree path twice as extra output. The awk `exit` statement jumps to `END` rather than skipping it, so the path was printed by both the blank-line rule and the `END` rule.

## 0.1.1

### Fixed

- `wt rm` crashed with `unbound variable` error when the argument wasn't a valid worktree (or was a branch without a worktree). The indirect array reference used to pass the `--force` flag was incompatible with bash 3.2 + `set -u` on empty arrays.

## 0.1.0

Initial release.

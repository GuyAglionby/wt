# Changelog

## 0.5.1

### Fixed

- `wt rm` no longer deletes pre-existing branches with unmerged work when no new commits were made in the worktree session. Previously, `wt add existingbranch && wt rm existingbranch` would delete the branch because HEAD equalled the recorded starting commit, even if the branch contained valuable unmerged work. Now always consults the merge check (`merge-base --is-ancestor`, local branch reachability, GitHub PR status) before deciding.

## 0.5.0

### Added

- `wt cp` now supports branch-qualified paths: `wt cp branch/path/to/file.py .` pulls a specific file from another branch's worktree. Multiple files work too: `wt cp branch/a.py branch/b.py .`. Paths are resolved relative to the worktree root. The longest matching branch name is used, so `feature/login/file.py` correctly matches branch `feature/login` even if a `feature` branch also exists.

## 0.4.1

### Fixed

- `wt rm` now deletes the branch when it has been merged into **any** local branch, not only when reachable from the remote default branch. If the branch is reachable from the remote default branch, behavior is unchanged. Otherwise, if the branch is reachable from any other local branch (e.g. local main not yet pushed, or another branch like `develop`), the branch is considered merged and is deleted. This fixes the case where you fast-forward merge into local main and run `wt rm` before pushing.

## 0.4.0

### Added

- `wt add` now checks remotes when the branch doesn't exist locally. If the branch is found on a single remote, prompts to check it out as a tracking branch. If found on multiple remotes, shows a selection menu. Use `--no-check-remote` to skip and create a new branch directly.

## 0.3.3

### Fixed

- `wt cp` resolved file paths relative to the worktree root instead of the current working directory. Running `wt cp foo.sh other` from a subdirectory like `scripts/` would fail with "path not found" because it looked for `foo.sh` at the repo root instead of `scripts/foo.sh`. Now uses `git rev-parse --show-prefix` to prepend the cwd prefix to relative paths.

## 0.3.2

### Fixed

- `wt add` created directories with literal `/` in the name for branches like `feature/foo`, resulting in nested directories. Now replaces `/` with `-` in the directory name (e.g., `worktree--repo--feature-foo`). The git branch itself keeps the original name.

## 0.3.1

### Fixed

- `wt base` returned a stale commit after `git rebase`. The `starting_commit` recorded at worktree creation time became unreachable when a rebase rewrote the branch's history, making `wt base` misleading and causing the "no work done" branch deletion shortcut to fail. Now installs a `post-rewrite` git hook (via `wt add`) that automatically updates `starting_commit` when a rebase changes the branch's base. The hook is idempotent and coexists with existing `post-rewrite` hooks.

## 0.3.0

### Added

- `wt cleanup` command that scans all linked worktrees and removes those whose branches have been merged or have no changes from their starting commit. Skips worktrees with untracked files, detached HEADs, or unmerged commits. Supports `--dry-run` to preview what would happen without making changes.
- `wt sync-agent --dry-run` flag to preview what agent file syncing would do without making changes. Shows which files would be copied, merged cleanly, conflict, or overwritten.

### Changed

- Extracted `_decide_branch_deletion` and `_check_untracked_files` helpers from `_rm_single` so `wt cleanup` and `wt rm` share the same decision logic.

## 0.2.1

### Fixed

- `wt add` created new branches from the main worktree's HEAD instead of the current worktree's HEAD. When running `wt add new-branch` from a linked worktree, the new branch should start from the current worktree's commit, not main's. The `git worktree add -b` command was run with `-C "$repo_root"`, which resolved `HEAD` against the main worktree. Now captures the current HEAD before dispatching to git.

## 0.2.0

### Added

- `wt rm` now detects branches that have been merged into the default branch, even via squash or rebase merge. Previously, the branch deletion heuristic only compared the worktree HEAD to its starting commit — if any commits were made, the branch was always retained, even if the work had already been merged upstream.

  The new logic has two layers:
  1. **Fast local check**: if the branch HEAD is reachable from the remote default branch (e.g., after a merge commit or fast-forward), the branch is deleted without any API calls.
  2. **GitHub PR check**: if commit hashes differ (squash/rebase merge), `wt rm` uses `gh` to find a merged PR for the branch and verifies that local HEAD matches or is behind the PR's final commit. Handles the common case where the remote branch has been deleted after merge.

  When `gh` is not installed or the repo is not on GitHub, the existing heuristic is used as a fallback.

## 0.1.5

### Fixed

- `wt venv` failed with "Missing credentials" when run from a shell with an activated venv. The command unset `VIRTUAL_ENV` but left the old venv's bin directory in `PATH`, causing `uv sync` to find a stale keyring/credential helper. Now strips the venv's bin from `PATH` too, mirroring what `deactivate` does.

## 0.1.4

### Fixed

- `wt rm` showed "unbound variable" error for `merged` when syncing agent files. The `sync_agent_files` function used a RETURN trap to clean up a temp file, but bash's variable scoping with RETURN traps is unreliable. Now cleans up the temp file immediately after use.

## 0.1.3

### Fixed

- `wt rm` printed "Worktree removed" even when `git worktree remove` failed (e.g., due to modified/untracked files without `--force`). The misleading success message appeared because `_rm_single` runs inside `if ! ...` which disables `set -e`.

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

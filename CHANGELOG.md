# Changelog

## 0.1.1

### Fixed

- `wt rm` crashed with `unbound variable` error when the argument wasn't a valid worktree (or was a branch without a worktree). The indirect array reference used to pass the `--force` flag was incompatible with bash 3.2 + `set -u` on empty arrays.

## 0.1.0

Initial release.

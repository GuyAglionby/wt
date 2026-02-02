# wt

A git worktree manager that lets you think in branches, not directories.

_Disclaimer: this readme is auto-generated, but I have reviewed it._

## Installation

Place the `wt` script somewhere in your `PATH`:

```sh
cp wt ~/.local/bin/wt
chmod +x ~/.local/bin/wt
```

Then install shell integration (bash or zsh):

```sh
wt install
```

Or manually add to your shell rc file:

```sh
eval "$(wt init)"
```

## What wt gives you

`wt` makes the branch name the primary handle for everything. You add, remove, navigate, rename, and copy files between worktrees by branch name. Worktrees are placed at `../worktree--{repo}--{branch}` relative to the main worktree, but you rarely need to think about paths at all.

**Branch-first navigation.** `wt cd feature-x` moves your shell into the worktree for that branch. `wt cd` takes you back to the main worktree. `wt cd -` returns to wherever you just were.

**Copying files across branches.** When you're working on related changes across branches, `wt copy feature-x src/utils.py` pulls a file from another branch into yours, and `wt copy src/utils.py feature-x` pushes one the other way. Tracked dirty files in the destination are protected from overwriting by default.

**Safe cleanup.** `wt rm` removes worktrees and handles branch cleanup automatically. It records the commit a worktree was spawned from, and only deletes the branch if no new commits have been made since. Work is never silently discarded.

**Shared environments by default.** New worktrees share the `.venv` of the worktree where they were created, so you don't reinstall dependencies for every branch. `.env` is copied over, and `pre-commit install` runs automatically if a config is present. When a worktree needs its own environment — for example, to test a different package version — `wt venv` replaces the shared link with a standalone virtual environment using [uv](https://docs.astral.sh/uv/).

Worktrees are independent of each other. You can delete any worktree at any time without affecting the others. When you create a worktree from one that has its own environment, the new worktree gets its own environment too, not a reference to its sibling's. Think of worktrees as branches, not as a hierarchy: each one depends on the main repo, but never on another worktree.

**AI coding agent integration.** `wt` is designed to work alongside AI coding agents like [Claude Code](https://docs.anthropic.com/en/docs/claude-code), [Cursor](https://cursor.com), and [Codex](https://openai.com/index/introducing-codex/). When you create a worktree, agent context files are copied from the main worktree so the agent has the same instructions in every branch. When you delete a worktree, any changes to those files are three-way merged back into the main worktree, so configuration improvements made during a feature branch aren't lost.

By default, `wt` syncs these patterns:

- `CLAUDE.md`, `AGENTS.md`, `.cursorrules` (at any depth)
- `.claude/skills/*`, `.cursor/rules/*`, `.codex/skills/*` (arbitrary nesting)

Add custom patterns via the `WT_AGENT_PATTERNS` environment variable (colon-separated):

```sh
export WT_AGENT_PATTERNS=".github/copilot-instructions.md:*/.my-agent/config/*"
```

## Command reference

<details>
<summary><code>wt add &lt;branch&gt;</code></summary>

Create a new worktree for the given branch. If the branch doesn't exist, it's created from the current HEAD. Sets up the environment and agent files as described above, and moves your shell into the new worktree.

</details>

<details>
<summary><code>wt cd [branch]</code></summary>

Switch your shell to the worktree for the given branch.

With no argument, switch to the main worktree. `wt cd -` returns to the previous worktree. `wt cd -N` goes back N entries in the directory stack.

</details>

<details>
<summary><code>wt rm &lt;branch&gt;... [options]</code></summary>

Remove one or more worktrees by branch name.

Before removal, any modified agent files are merged back into the main worktree using three-way merge. `wt` stores a base snapshot of these files at worktree creation time so it can distinguish genuine conflicts from independent edits. If a conflict can't be auto-resolved, your editor is opened. Removal is aborted if conflicts remain unresolved.

After removal, the branch is deleted only if its HEAD still matches the recorded starting commit -- i.e., no new work was done. If you've committed to the branch, it's retained.

If you're inside the worktree being removed, your shell is moved back to the main worktree.

Options:
- `--force`, `-f` -- remove even with uncommitted or untracked files
- `--force-delete-branch` -- delete the branch regardless of commits (implies `--force`)

</details>

<details>
<summary><code>wt mv &lt;new-branch&gt;</code></summary>

Rename the current worktree's branch and move the worktree directory to match the new name. Must be run from inside a linked worktree, not the main worktree.

</details>

<details>
<summary><code>wt copy &lt;branch&gt; &lt;path&gt;... | &lt;path&gt;... &lt;branch&gt;</code></summary>

Copy files between the current worktree and another. Direction is inferred from argument position: branch first means pull from that branch, branch last means push to it. Directories are expanded to their tracked contents.

By default, only tracked files are copied, and files with uncommitted changes in the destination are not overwritten. This prevents accidentally destroying in-progress work.

Options:
- `--include-untracked` -- also copy untracked files
- `--overwrite` -- overwrite files with uncommitted changes in the destination

</details>

<details>
<summary><code>wt list</code></summary>

List all worktrees.

</details>

<details>
<summary><code>wt base [branch]</code></summary>

Show the commit a worktree was spawned from. Defaults to the current worktree. This is the commit recorded by `wt add` and used by `wt rm` for the branch deletion heuristic.

</details>

<details>
<summary><code>wt sync-agent [branch]</code></summary>

Merge agent files from a worktree into the main worktree without removing the worktree. Uses the same three-way merge as `wt rm`. Defaults to the current worktree.

</details>

<details>
<summary><code>wt venv</code></summary>

Replace the symlinked `.venv` in the current worktree with a standalone virtual environment. Runs `uv venv` and `uv sync`, then activates it in your shell.

</details>

<details>
<summary><code>wt update</code></summary>

Update `wt` to the latest version from GitHub.

</details>

<details>
<summary><code>wt version</code></summary>

Print the current version.

</details>

## To do

- **Poetry support.** Environment management currently assumes uv. Poetry projects need equivalent `wt venv` support.
- **Agent settings syncing.** Coding agents store settings files (e.g., `.claude/settings.json`) that configure allowed tools, permissions, and other preferences. These should be synced to new worktrees so the agent starts with the same permissions, avoiding repeated approval prompts.
- **History rewriting on worktree deletion.** When a worktree is removed, conversation history and file references from AI agents still point at the now-deleted worktree paths. These should be rewritten to reference the main worktree so that context is preserved.

## Why worktrees?

If you've worked on more than one branch in a repository, you've run into the friction of `git checkout`: stash your work, switch branches, wait for your editor to catch up, switch back, pop the stash. If you need two branches open at the same time -- reviewing one while working on another, running tests on a feature branch while fixing something on main -- you're stuck.

Git worktrees let you check out multiple branches into separate directories simultaneously. Each worktree is a full working copy backed by a single shared `.git` object store. No cloning, no duplicated history, no stashing. Every branch you need is live and editable at the same time.

The trade-off is that raw `git worktree` commands operate on directory paths. You construct paths by hand, remember where each worktree lives, and clean up branches yourself. For occasional use this is fine. Once worktrees become part of your daily workflow -- and they should, particularly if you work with AI coding agents that benefit from isolated working directories -- the bookkeeping adds up.

`wt` removes that bookkeeping. Worktree directories are derived from branch names automatically. Navigation, creation, deletion, file transfer, and environment setup all operate on branch names. The directory structure becomes an implementation detail rather than something you manage.

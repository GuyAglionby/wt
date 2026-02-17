#!/usr/bin/env bats
# Tests for cmd_add — worktree creation

load test_helper

@test "add creates worktree at expected path" {
    cd "$REPO_DIR"
    run wt add test-branch
    [ "$status" -eq 0 ]

    local wt_dir
    wt_dir=$(get_worktree_dir "test-branch")
    [ -d "$wt_dir" ]
    [ -e "$wt_dir/.git" ]
}

@test "add creates new branch from current HEAD" {
    cd "$REPO_DIR"
    local head_before
    head_before=$(git rev-parse HEAD)

    run wt add new-feature
    [ "$status" -eq 0 ]

    local wt_dir
    wt_dir=$(get_worktree_dir "new-feature")
    local wt_head
    wt_head=$(git -C "$wt_dir" rev-parse HEAD)
    [ "$wt_head" = "$head_before" ]
}

@test "add checks out existing branch" {
    cd "$REPO_DIR"
    git branch existing-branch >/dev/null 2>&1

    run wt add existing-branch
    [ "$status" -eq 0 ]

    local wt_dir
    wt_dir=$(get_worktree_dir "existing-branch")
    local branch
    branch=$(git -C "$wt_dir" rev-parse --abbrev-ref HEAD)
    [ "$branch" = "existing-branch" ]
}

@test "add records starting_commit" {
    cd "$REPO_DIR"
    run wt add sc-test
    [ "$status" -eq 0 ]

    local sc
    sc=$(get_starting_commit "sc-test")
    [ -n "$sc" ]
}

@test "starting_commit matches HEAD of new worktree" {
    cd "$REPO_DIR"
    run wt add sc-match
    [ "$status" -eq 0 ]

    local sc
    sc=$(get_starting_commit "sc-match")
    local wt_dir
    wt_dir=$(get_worktree_dir "sc-match")
    local wt_head
    wt_head=$(git -C "$wt_dir" rev-parse HEAD)
    [ "$sc" = "$wt_head" ]
}

@test "add installs post-rewrite hook" {
    cd "$REPO_DIR"
    run wt add hook-test
    [ "$status" -eq 0 ]

    [ -f "$REPO_DIR/.git/hooks/post-rewrite" ]
    [ -x "$REPO_DIR/.git/hooks/post-rewrite" ]
    grep -q "BEGIN WT" "$REPO_DIR/.git/hooks/post-rewrite"
}

@test "add symlinks .venv to main worktree's venv" {
    cd "$REPO_DIR"
    mkdir -p .venv/bin
    printf '#!/bin/bash\n' > .venv/bin/activate

    run wt add venv-test
    [ "$status" -eq 0 ]

    local wt_dir
    wt_dir=$(get_worktree_dir "venv-test")
    [ -L "$wt_dir/.venv" ]
    local target
    target=$(readlink "$wt_dir/.venv")
    [ "$target" = "$REPO_DIR/.venv" ]
}

@test "add symlinks .venv to main's real venv when run from linked worktree" {
    cd "$REPO_DIR"
    mkdir -p .venv/bin
    printf '#!/bin/bash\n' > .venv/bin/activate

    # Create first worktree (gets symlink to main's .venv)
    wt add first-wt >/dev/null 2>&1
    local first_dir
    first_dir=$(get_worktree_dir "first-wt")

    # Create second worktree from the first worktree
    cd "$first_dir"
    run wt add second-wt
    [ "$status" -eq 0 ]

    local second_dir
    second_dir=$(get_worktree_dir "second-wt")
    [ -L "$second_dir/.venv" ]
    # Should resolve to main's real .venv, not the first worktree's symlink
    local target
    target=$(cd "$second_dir/.venv" && pwd -P)
    local main_real
    main_real=$(cd "$REPO_DIR/.venv" && pwd -P)
    [ "$target" = "$main_real" ]
}

@test "add copies .env from source worktree" {
    cd "$REPO_DIR"
    echo "SECRET=abc" > .env

    run wt add env-test
    [ "$status" -eq 0 ]

    local wt_dir
    wt_dir=$(get_worktree_dir "env-test")
    [ -f "$wt_dir/.env" ]
    grep -q "SECRET=abc" "$wt_dir/.env"
}

@test "add copies agent files to new worktree" {
    cd "$REPO_DIR"
    echo "# Agent instructions" > CLAUDE.md
    git add CLAUDE.md && git commit -m "Add CLAUDE.md" >/dev/null 2>&1

    run wt add agent-test
    [ "$status" -eq 0 ]

    local wt_dir
    wt_dir=$(get_worktree_dir "agent-test")
    [ -f "$wt_dir/CLAUDE.md" ]
    grep -q "Agent instructions" "$wt_dir/CLAUDE.md"
}

@test "add saves agent base snapshot" {
    cd "$REPO_DIR"
    echo "# Base content" > CLAUDE.md
    git add CLAUDE.md && git commit -m "Add CLAUDE.md" >/dev/null 2>&1

    run wt add base-snap
    [ "$status" -eq 0 ]

    local wt_dir
    wt_dir=$(get_worktree_dir "base-snap")
    local wt_name
    wt_name=$(basename "$(git -C "$wt_dir" rev-parse --git-dir)")
    [ -f "$REPO_DIR/.git/worktrees/$wt_name/agent_base/CLAUDE.md" ]
    grep -q "Base content" "$REPO_DIR/.git/worktrees/$wt_name/agent_base/CLAUDE.md"
}

@test "add replaces slashes with dashes in directory name" {
    cd "$REPO_DIR"
    run wt add feature/my-thing
    [ "$status" -eq 0 ]

    local wt_dir
    wt_dir=$(get_worktree_dir "feature/my-thing")
    [ -d "$wt_dir" ]
    # Directory name uses dashes, not slashes
    [[ "$(basename "$wt_dir")" == *"feature-my-thing"* ]]
    # But the git branch keeps the slash
    local branch
    branch=$(git -C "$wt_dir" rev-parse --abbrev-ref HEAD)
    [ "$branch" = "feature/my-thing" ]
}

@test "add errors if worktree already exists" {
    cd "$REPO_DIR"
    wt add duplicate-test >/dev/null 2>&1

    run wt add duplicate-test
    [ "$status" -ne 0 ]
    [[ "$output" == *"already exists"* ]]
}

@test "add errors if no branch name given" {
    cd "$REPO_DIR"
    run wt add
    [ "$status" -ne 0 ]
}

@test "add emits __WT_CD__ signal" {
    cd "$REPO_DIR"
    run wt add cd-signal
    [ "$status" -eq 0 ]

    local wt_dir
    wt_dir=$(get_worktree_dir "cd-signal")
    local cd_path
    cd_path=$(get_signal "__WT_CD__")
    [ "$cd_path" = "$wt_dir" ]
}

# ─── Remote branch checking ─────────────────────────────────────────────────

@test "add --no-check-remote skips remote check" {
    cd "$REPO_DIR"

    # Create a bare remote with a branch
    local remote_bare="$TEST_DIR/remote.git"
    git init --bare "$remote_bare" >/dev/null 2>&1
    git remote add origin "$remote_bare"
    git push origin main >/dev/null 2>&1

    # Create a branch on the remote with a different commit
    local clone_dir="$TEST_DIR/clone"
    git clone "$remote_bare" "$clone_dir" >/dev/null 2>&1
    git -C "$clone_dir" checkout -b remote-feature >/dev/null 2>&1
    git -C "$clone_dir" commit --allow-empty -m "Remote commit" >/dev/null 2>&1
    local remote_head
    remote_head=$(git -C "$clone_dir" rev-parse HEAD)
    git -C "$clone_dir" push origin remote-feature >/dev/null 2>&1

    local local_head
    local_head=$(git rev-parse HEAD)

    run wt add --no-check-remote remote-feature
    [ "$status" -eq 0 ]

    local wt_dir
    wt_dir=$(get_worktree_dir "remote-feature")
    local wt_head
    wt_head=$(git -C "$wt_dir" rev-parse HEAD)
    # Should match local HEAD, not remote
    [ "$wt_head" = "$local_head" ]
    [ "$wt_head" != "$remote_head" ]
}

@test "add creates new branch when no remote has it" {
    cd "$REPO_DIR"

    # Create a bare remote without the target branch
    local remote_bare="$TEST_DIR/remote.git"
    git init --bare "$remote_bare" >/dev/null 2>&1
    git remote add origin "$remote_bare"
    git push origin main >/dev/null 2>&1

    local local_head
    local_head=$(git rev-parse HEAD)

    run wt add brand-new-branch
    [ "$status" -eq 0 ]

    local wt_dir
    wt_dir=$(get_worktree_dir "brand-new-branch")
    local wt_head
    wt_head=$(git -C "$wt_dir" rev-parse HEAD)
    [ "$wt_head" = "$local_head" ]
}

@test "add fetches and tracks remote branch when tty unavailable" {
    cd "$REPO_DIR"

    # Create a bare remote with a branch
    local remote_bare="$TEST_DIR/remote.git"
    git init --bare "$remote_bare" >/dev/null 2>&1
    git remote add origin "$remote_bare"
    git push origin main >/dev/null 2>&1

    # Create a branch on the remote with a different commit
    local clone_dir="$TEST_DIR/clone"
    git clone "$remote_bare" "$clone_dir" >/dev/null 2>&1
    git -C "$clone_dir" checkout -b remote-feature >/dev/null 2>&1
    git -C "$clone_dir" commit --allow-empty -m "Remote commit" >/dev/null 2>&1
    local remote_head
    remote_head=$(git -C "$clone_dir" rev-parse HEAD)
    git -C "$clone_dir" push origin remote-feature >/dev/null 2>&1

    # Run without tty - default answer is Y (empty input = confirm)
    run wt add remote-feature
    [ "$status" -eq 0 ]

    local wt_dir
    wt_dir=$(get_worktree_dir "remote-feature")
    local wt_head
    wt_head=$(git -C "$wt_dir" rev-parse HEAD)
    # Should match the remote commit since it was fetched and tracked
    [ "$wt_head" = "$remote_head" ]

    # Verify the prompt was shown
    [[ "$output" == *"found on remote"* ]]
}

@test "add with multiple remotes creates new branch when tty unavailable" {
    cd "$REPO_DIR"

    # Create two bare remotes, both with the branch
    local remote1="$TEST_DIR/remote1.git"
    local remote2="$TEST_DIR/remote2.git"
    git init --bare "$remote1" >/dev/null 2>&1
    git init --bare "$remote2" >/dev/null 2>&1
    git remote add origin "$remote1"
    git remote add upstream "$remote2"
    git push origin main >/dev/null 2>&1
    git push upstream main >/dev/null 2>&1

    local clone_dir="$TEST_DIR/clone"
    git clone "$remote1" "$clone_dir" >/dev/null 2>&1
    git -C "$clone_dir" checkout -b shared-feature >/dev/null 2>&1
    git -C "$clone_dir" commit --allow-empty -m "Remote commit" >/dev/null 2>&1
    git -C "$clone_dir" push origin shared-feature >/dev/null 2>&1
    git -C "$clone_dir" remote add upstream "$remote2"
    git -C "$clone_dir" push upstream shared-feature >/dev/null 2>&1

    local local_head
    local_head=$(git rev-parse HEAD)

    # select menu can't get tty input, falls through to new branch
    run wt add shared-feature
    [ "$status" -eq 0 ]

    local wt_dir
    wt_dir=$(get_worktree_dir "shared-feature")
    local wt_head
    wt_head=$(git -C "$wt_dir" rev-parse HEAD)
    # Should be local HEAD since select couldn't get input
    [ "$wt_head" = "$local_head" ]

    # Verify it mentioned multiple remotes
    [[ "$output" == *"found on multiple remotes"* ]]
}

@test "add --help shows add usage" {
    cd "$REPO_DIR"
    run wt add --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--no-check-remote"* ]]
}

#!/usr/bin/env bats
# Tests for cmd_move — branch rename and worktree directory move

load test_helper

@test "move renames branch and moves worktree directory" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "old-name"

    local old_dir new_dir
    old_dir=$(get_worktree_dir "old-name")
    new_dir=$(get_worktree_dir "new-name")
    cd "$old_dir"

    run wt mv new-name
    [ "$status" -eq 0 ]
    [[ "$output" == *"Branch renamed"* ]]

    [ ! -d "$old_dir" ]
    [ -d "$new_dir" ]

    local branch
    branch=$(git -C "$new_dir" rev-parse --abbrev-ref HEAD)
    [ "$branch" = "new-name" ]
}

@test "move emits __WT_CD__ to new path" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "mv-cd"

    local old_dir
    old_dir=$(get_worktree_dir "mv-cd")
    cd "$old_dir"

    local new_dir
    new_dir=$(get_worktree_dir "mv-renamed")

    run wt mv mv-renamed
    [ "$status" -eq 0 ]

    local cd_path
    cd_path=$(get_signal "__WT_CD__")
    [ "$cd_path" = "$new_dir" ]
}

@test "move errors if run from main repo" {
    cd "$REPO_DIR"
    commit_file "base.txt"

    run wt mv some-branch
    [ "$status" -ne 0 ]
    [[ "$output" == *"main repo"* ]]
}

@test "move errors if target branch exists and is not ancestor" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "source-mv"

    # Create a branch with its own commit (not in the worktree's history)
    cd "$REPO_DIR"
    git checkout -b divergent >/dev/null 2>&1
    commit_file "divergent-work.txt"
    git checkout main >/dev/null 2>&1

    # Also make a commit in the worktree so HEAD differs
    cd "$(get_worktree_dir "source-mv")"
    commit_file "wt-work.txt"

    run wt mv divergent
    [ "$status" -ne 0 ]
    [[ "$output" == *"already exists"* ]]
}

@test "move replaces target branch if it's an ancestor of HEAD" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "ancestor-src"

    # Create a branch at current HEAD (will be ancestor of worktree HEAD after commit)
    local ancestor_commit
    ancestor_commit=$(git rev-parse HEAD)
    git branch ancestor-target "$ancestor_commit" >/dev/null 2>&1

    local wt_dir
    wt_dir=$(get_worktree_dir "ancestor-src")
    cd "$wt_dir"
    commit_file "ahead.txt"

    run wt mv ancestor-target
    [ "$status" -eq 0 ]
    [[ "$output" == *"ancestor"* ]]

    local new_dir
    new_dir=$(get_worktree_dir "ancestor-target")
    [ -d "$new_dir" ]
}

@test "move is noop if already on target branch" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "same-name"

    local wt_dir
    wt_dir=$(get_worktree_dir "same-name")
    cd "$wt_dir"

    run wt mv same-name
    [ "$status" -eq 0 ]
    [[ "$output" == *"nothing to do"* ]]
}

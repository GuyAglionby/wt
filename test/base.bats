#!/usr/bin/env bats
# Tests for cmd_base — show starting commit

load test_helper

@test "base shows starting commit for current worktree" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "base-test"

    local expected_sc
    expected_sc=$(get_starting_commit "base-test")

    local wt_dir
    wt_dir=$(get_worktree_dir "base-test")
    cd "$wt_dir"

    run wt base
    [ "$status" -eq 0 ]
    [ "$output" = "$expected_sc" ]
}

@test "base shows starting commit for specified branch" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "base-branch"

    local expected_sc
    expected_sc=$(get_starting_commit "base-branch")

    cd "$REPO_DIR"
    run wt base base-branch
    [ "$status" -eq 0 ]
    [ "$output" = "$expected_sc" ]
}

@test "base errors when run from main repo without argument" {
    cd "$REPO_DIR"
    commit_file "base.txt"

    run wt base
    [ "$status" -ne 0 ]
    [[ "$output" == *"main repo"* ]]
}

@test "base errors when no starting_commit recorded" {
    cd "$REPO_DIR"
    commit_file "base.txt"

    # Create worktree without wt (no starting_commit metadata)
    local wt_dir
    wt_dir=$(get_worktree_dir "no-sc")
    git worktree add "$wt_dir" -b no-sc >/dev/null 2>&1

    cd "$wt_dir"
    run wt base
    [ "$status" -ne 0 ]
    [[ "$output" == *"no starting commit"* ]]
}

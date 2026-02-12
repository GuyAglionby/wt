#!/usr/bin/env bats
# Tests for worktree resolution helper functions

load test_helper

@test "get_worktree_path returns {parent}/worktree--{repo}--{branch}" {
    cd "$REPO_DIR"
    run wt add test-branch
    [ "$status" -eq 0 ]

    local expected
    expected=$(get_worktree_dir "test-branch")
    [ -d "$expected" ]
}

@test "normalize_branch strips worktree--repo-- prefix" {
    cd "$REPO_DIR"
    # Create a worktree, then try to add using the directory-style name
    wt add feature >/dev/null 2>&1
    local wt_dir
    wt_dir=$(get_worktree_dir "feature")
    [ -d "$wt_dir" ]

    # The directory name is worktree--myrepo--feature
    local dir_name
    dir_name=$(basename "$wt_dir")

    # resolve_worktree should normalize the prefix and find the worktree
    run wt cd "$dir_name"
    [ "$status" -eq 0 ]
    [[ "$output" == *"__WT_CD__:${wt_dir}"* ]]
}

@test "normalize_branch passes through plain branch names" {
    cd "$REPO_DIR"
    wt add mybranch >/dev/null 2>&1
    local wt_dir
    wt_dir=$(get_worktree_dir "mybranch")

    run wt cd mybranch
    [ "$status" -eq 0 ]
    [[ "$output" == *"__WT_CD__:${wt_dir}"* ]]
}

@test "resolve_worktree accepts branch name" {
    cd "$REPO_DIR"
    wt add resolve-test >/dev/null 2>&1
    local wt_dir
    wt_dir=$(get_worktree_dir "resolve-test")

    run wt cd resolve-test
    [ "$status" -eq 0 ]
    [[ "$output" == *"__WT_CD__:${wt_dir}"* ]]
}

@test "resolve_worktree accepts path" {
    cd "$REPO_DIR"
    wt add path-test >/dev/null 2>&1
    local wt_dir
    wt_dir=$(get_worktree_dir "path-test")

    run wt cd "$wt_dir"
    [ "$status" -eq 0 ]
    [[ "$output" == *"__WT_CD__:${wt_dir}"* ]]
}

@test "resolve_worktree rejects non-existent branch" {
    cd "$REPO_DIR"
    run wt cd nonexistent-branch
    [ "$status" -ne 0 ]
    [[ "$output" == *"no worktree found"* ]]
}

@test "resolve_worktree rejects path outside any worktree" {
    cd "$REPO_DIR"
    local random_dir="$TEST_DIR/not-a-worktree"
    mkdir -p "$random_dir"

    run wt cd "$random_dir"
    [ "$status" -ne 0 ]
}

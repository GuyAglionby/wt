#!/usr/bin/env bats
# Tests for cmd_cleanup — batch cleanup of worktrees

load test_helper

@test "cleanup removes worktrees with no changes" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "clean-a"
    create_worktree "clean-b"

    run wt cleanup
    [ "$status" -eq 0 ]
    [[ "$output" == *"2 removed"* ]]

    local dir_a dir_b
    dir_a=$(get_worktree_dir "clean-a")
    dir_b=$(get_worktree_dir "clean-b")
    [ ! -d "$dir_a" ]
    [ ! -d "$dir_b" ]
}

@test "cleanup skips worktrees with untracked files" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "has-untracked"

    local wt_dir
    wt_dir=$(get_worktree_dir "has-untracked")
    echo "temp" > "$wt_dir/untracked.txt"

    run wt cleanup
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 skipped"* ]]
    [ -d "$wt_dir" ]
}

@test "cleanup skips detached HEAD worktrees" {
    cd "$REPO_DIR"
    commit_file "base.txt"

    # Create a worktree with detached HEAD
    local wt_dir
    wt_dir=$(get_worktree_dir "detached")
    git worktree add --detach "$wt_dir" HEAD >/dev/null 2>&1

    run wt cleanup
    [ "$status" -eq 0 ]
    [[ "$output" == *"detached HEAD"* ]]
    [ -d "$wt_dir" ]
}

@test "cleanup --dry-run shows what would happen without changes" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "dry-clean"
    create_worktree "dry-untracked"

    local wt_dir
    wt_dir=$(get_worktree_dir "dry-untracked")
    echo "temp" > "$wt_dir/untracked.txt"

    run wt cleanup --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Would remove"* ]]
    [[ "$output" == *"Would skip"* ]]
    [[ "$output" == *"Dry run"* ]]

    # Nothing should actually be removed
    local clean_dir
    clean_dir=$(get_worktree_dir "dry-clean")
    [ -d "$clean_dir" ]
    [ -d "$wt_dir" ]
}

@test "cleanup reports correct counts" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "count-clean"
    create_worktree "count-dirty"

    local dirty_dir
    dirty_dir=$(get_worktree_dir "count-dirty")
    echo "temp" > "$dirty_dir/junk.txt"

    run wt cleanup
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 removed"* ]]
    [[ "$output" == *"1 skipped"* ]]
}

@test "cleanup with no linked worktrees says so" {
    cd "$REPO_DIR"
    commit_file "base.txt"

    run wt cleanup
    [ "$status" -eq 0 ]
    [[ "$output" == *"No linked worktrees found"* ]]
}

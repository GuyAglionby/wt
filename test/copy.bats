#!/usr/bin/env bats
# Tests for cmd_copy — file copying between worktrees

load test_helper

setup() {
    _common_setup
    # Set up a base file and worktree for most tests
    commit_file "shared.txt" "shared content"
    create_worktree "other"
}

teardown() {
    _common_teardown
}

# --- Direction detection ---

@test "copy: branch first pulls from other worktree" {
    local wt_dir
    wt_dir=$(get_worktree_dir "other")
    cd "$wt_dir"
    commit_file "feature.txt" "from other"
    cd "$REPO_DIR"

    run wt copy other feature.txt
    [ "$status" -eq 0 ]
    [ -f "$REPO_DIR/feature.txt" ]
    grep -q "from other" "$REPO_DIR/feature.txt"
}

@test "copy: branch last pushes to other worktree" {
    cd "$REPO_DIR"
    commit_file "pushed.txt" "from main"

    local wt_dir
    wt_dir=$(get_worktree_dir "other")

    run wt copy pushed.txt other
    [ "$status" -eq 0 ]
    [ -f "$wt_dir/pushed.txt" ]
    grep -q "from main" "$wt_dir/pushed.txt"
}

@test "copy errors when both args resolve to worktrees" {
    cd "$REPO_DIR"
    create_worktree "another"

    run wt copy other another
    [ "$status" -ne 0 ]
    [[ "$output" == *"ambiguous"* ]] || [[ "$output" == *"neither"* ]] || [[ "$output" == *"resolve"* ]]
}

# --- Safety ---

@test "copy rejects if destination has uncommitted changes in tracked file" {
    local wt_dir
    wt_dir=$(get_worktree_dir "other")

    # shared.txt exists in both; modify in destination without committing
    echo "modified" > "$REPO_DIR/shared.txt"

    # Try to copy shared.txt from other to main
    cd "$REPO_DIR"
    run wt copy other shared.txt
    [ "$status" -ne 0 ]
    [[ "$output" == *"uncommitted changes"* ]] || [[ "$output" == *"overwritten"* ]]
}

@test "copy rejects if destination has existing untracked file" {
    local wt_dir
    wt_dir=$(get_worktree_dir "other")
    cd "$wt_dir"
    commit_file "newfile.txt" "new content"
    cd "$REPO_DIR"

    # Create an untracked file with the same name in destination
    echo "local version" > "$REPO_DIR/newfile.txt"

    run wt copy other newfile.txt
    [ "$status" -ne 0 ]
    [[ "$output" == *"overwritten"* ]]
}

@test "copy --overwrite allows overwriting" {
    local wt_dir
    wt_dir=$(get_worktree_dir "other")
    cd "$wt_dir"
    commit_file "overwrite-me.txt" "other version"
    cd "$REPO_DIR"

    echo "local version" > "$REPO_DIR/overwrite-me.txt"

    run wt copy --overwrite other overwrite-me.txt
    [ "$status" -eq 0 ]
    grep -q "other version" "$REPO_DIR/overwrite-me.txt"
}

@test "copy rejects untracked source files without --include-untracked" {
    local wt_dir
    wt_dir=$(get_worktree_dir "other")
    echo "untracked data" > "$wt_dir/untracked.txt"

    cd "$REPO_DIR"
    run wt copy other untracked.txt
    [ "$status" -ne 0 ]
    [[ "$output" == *"untracked"* ]]
}

@test "copy --include-untracked copies untracked files" {
    local wt_dir
    wt_dir=$(get_worktree_dir "other")
    echo "untracked data" > "$wt_dir/untracked.txt"

    cd "$REPO_DIR"
    run wt copy --include-untracked other untracked.txt
    [ "$status" -eq 0 ]
    [ -f "$REPO_DIR/untracked.txt" ]
    grep -q "untracked data" "$REPO_DIR/untracked.txt"
}

# --- Functionality ---

@test "copy copies single file" {
    local wt_dir
    wt_dir=$(get_worktree_dir "other")
    cd "$wt_dir"
    commit_file "single.txt" "single file content"
    cd "$REPO_DIR"

    run wt copy other single.txt
    [ "$status" -eq 0 ]
    [ -f "$REPO_DIR/single.txt" ]
    grep -q "single file content" "$REPO_DIR/single.txt"
}

@test "copy copies directory (expands to tracked files)" {
    local wt_dir
    wt_dir=$(get_worktree_dir "other")
    cd "$wt_dir"
    mkdir -p subdir
    commit_file "subdir/a.txt" "file a"
    commit_file "subdir/b.txt" "file b"
    cd "$REPO_DIR"

    run wt copy other subdir
    [ "$status" -eq 0 ]
    [ -f "$REPO_DIR/subdir/a.txt" ]
    [ -f "$REPO_DIR/subdir/b.txt" ]
}

@test "copy errors on missing source path" {
    cd "$REPO_DIR"
    run wt copy other nonexistent.txt
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "copy errors with no args" {
    cd "$REPO_DIR"
    run wt copy
    [ "$status" -ne 0 ]
}

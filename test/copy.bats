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

@test "copy: push works from subdirectory" {
    cd "$REPO_DIR"
    mkdir -p scripts
    commit_file "scripts/deploy.sh" "deploy content"

    local wt_dir
    wt_dir=$(get_worktree_dir "other")

    cd "$REPO_DIR/scripts"
    run wt copy deploy.sh other
    [ "$status" -eq 0 ]
    [ -f "$wt_dir/scripts/deploy.sh" ]
    grep -q "deploy content" "$wt_dir/scripts/deploy.sh"
}

@test "copy: pull works from subdirectory" {
    local wt_dir
    wt_dir=$(get_worktree_dir "other")
    cd "$wt_dir"
    mkdir -p scripts
    commit_file "scripts/build.sh" "build content"

    cd "$REPO_DIR"
    mkdir -p scripts
    cd scripts

    run wt copy other build.sh
    [ "$status" -eq 0 ]
    [ -f "$REPO_DIR/scripts/build.sh" ]
    grep -q "build content" "$REPO_DIR/scripts/build.sh"
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

# --- Branch-qualified path syntax (branch/path) ---

@test "copy: branch/path syntax pulls single file" {
    local wt_dir
    wt_dir=$(get_worktree_dir "other")
    cd "$wt_dir"
    commit_file "feature.txt" "from other"
    cd "$REPO_DIR"

    run wt copy other/feature.txt .
    [ "$status" -eq 0 ]
    [ -f "$REPO_DIR/feature.txt" ]
    grep -q "from other" "$REPO_DIR/feature.txt"
}

@test "copy: branch/path syntax pulls nested file" {
    local wt_dir
    wt_dir=$(get_worktree_dir "other")
    cd "$wt_dir"
    mkdir -p src/utils
    commit_file "src/utils/helper.py" "helper content"
    cd "$REPO_DIR"

    run wt copy other/src/utils/helper.py .
    [ "$status" -eq 0 ]
    [ -f "$REPO_DIR/src/utils/helper.py" ]
    grep -q "helper content" "$REPO_DIR/src/utils/helper.py"
}

@test "copy: branch/path syntax pulls multiple files" {
    local wt_dir
    wt_dir=$(get_worktree_dir "other")
    cd "$wt_dir"
    commit_file "a.txt" "file a"
    commit_file "b.txt" "file b"
    cd "$REPO_DIR"

    run wt copy other/a.txt other/b.txt .
    [ "$status" -eq 0 ]
    [ -f "$REPO_DIR/a.txt" ]
    [ -f "$REPO_DIR/b.txt" ]
    grep -q "file a" "$REPO_DIR/a.txt"
    grep -q "file b" "$REPO_DIR/b.txt"
}

@test "copy: branch/path syntax pulls directory" {
    local wt_dir
    wt_dir=$(get_worktree_dir "other")
    cd "$wt_dir"
    mkdir -p subdir
    commit_file "subdir/x.txt" "x content"
    commit_file "subdir/y.txt" "y content"
    cd "$REPO_DIR"

    run wt copy other/subdir .
    [ "$status" -eq 0 ]
    [ -f "$REPO_DIR/subdir/x.txt" ]
    [ -f "$REPO_DIR/subdir/y.txt" ]
}

@test "copy: branch/path syntax with slash in branch name" {
    cd "$REPO_DIR"
    create_worktree "feature/login"
    local wt_dir
    wt_dir=$(get_worktree_dir "feature/login")
    cd "$wt_dir"
    commit_file "auth.py" "auth code"
    cd "$REPO_DIR"

    run wt copy feature/login/auth.py .
    [ "$status" -eq 0 ]
    [ -f "$REPO_DIR/auth.py" ]
    grep -q "auth code" "$REPO_DIR/auth.py"
}

@test "copy: branch/path syntax errors on missing path" {
    cd "$REPO_DIR"

    run wt copy other/nonexistent.txt .
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "copy: branch/path syntax respects --overwrite" {
    local wt_dir
    wt_dir=$(get_worktree_dir "other")
    cd "$wt_dir"
    commit_file "conflict.txt" "other version"
    cd "$REPO_DIR"

    echo "local version" > "$REPO_DIR/conflict.txt"

    run wt copy --overwrite other/conflict.txt .
    [ "$status" -eq 0 ]
    grep -q "other version" "$REPO_DIR/conflict.txt"
}

@test "copy: branch/path syntax hints when branch has no worktree" {
    cd "$REPO_DIR"
    # Create a branch without a worktree
    git branch no-worktree-branch

    run wt copy no-worktree-branch/some/file.py .
    [ "$status" -ne 0 ]
    [[ "$output" == *"no worktree"* ]]
    [[ "$output" == *"wt add"* ]]
}

@test "copy: branch/path syntax rejects push direction" {
    cd "$REPO_DIR"
    commit_file "local.txt" "local content"

    run wt copy local.txt other/dest
    [ "$status" -ne 0 ]
}

@test "copy: branch/path syntax works from linked worktree" {
    # Create two linked worktrees
    create_worktree "source-branch"
    create_worktree "dest-branch"

    local source_dir dest_dir
    source_dir=$(get_worktree_dir "source-branch")
    dest_dir=$(get_worktree_dir "dest-branch")

    # Add a file to source worktree
    cd "$source_dir"
    commit_file "src/module.py" "module content"

    # Run from dest worktree, pull from source
    cd "$dest_dir"
    run wt copy source-branch/src/module.py .
    [ "$status" -eq 0 ]
    [ -f "$dest_dir/src/module.py" ]
    grep -q "module content" "$dest_dir/src/module.py"
}

@test "copy: old syntax still works with branch/path available" {
    local wt_dir
    wt_dir=$(get_worktree_dir "other")
    cd "$wt_dir"
    commit_file "old-style.txt" "old style content"
    cd "$REPO_DIR"

    run wt copy other old-style.txt
    [ "$status" -eq 0 ]
    [ -f "$REPO_DIR/old-style.txt" ]
    grep -q "old style content" "$REPO_DIR/old-style.txt"
}

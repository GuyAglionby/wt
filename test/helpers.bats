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

@test "get_worktree_path replaces slashes with dashes" {
    cd "$REPO_DIR"
    run wt add feat/slash-test
    [ "$status" -eq 0 ]

    local wt_dir
    wt_dir=$(get_worktree_dir "feat/slash-test")
    [ -d "$wt_dir" ]
    [[ "$(basename "$wt_dir")" == "worktree--myrepo--feat-slash-test" ]]
}

@test "resolve_worktree finds slash-branch by branch name" {
    cd "$REPO_DIR"
    wt add feat/resolve >/dev/null 2>&1
    local wt_dir
    wt_dir=$(get_worktree_dir "feat/resolve")

    run wt cd feat/resolve
    [ "$status" -eq 0 ]
    [[ "$output" == *"__WT_CD__:${wt_dir}"* ]]
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

@test "resolve_worktree finds detached-HEAD worktree by directory name" {
    cd "$REPO_DIR"
    wt add detach-test >/dev/null 2>&1
    local wt_dir
    wt_dir=$(get_worktree_dir "detach-test")

    # Detach HEAD in the worktree so it has no branch line in porcelain output
    git -C "$wt_dir" checkout --detach HEAD >/dev/null 2>&1

    local dir_name
    dir_name=$(basename "$wt_dir")

    # Should still resolve via directory basename matching
    run wt cd "$dir_name"
    [ "$status" -eq 0 ]
    [[ "$output" == *"__WT_CD__:${wt_dir}"* ]]
}

@test "resolve_worktree rejects non-existent branch" {
    cd "$REPO_DIR"
    run wt cd nonexistent-branch
    [ "$status" -ne 0 ]
    [[ "$output" == *"no worktree found"* ]]
}

@test "_resolve-branch-path splits branch/path" {
    cd "$REPO_DIR"
    wt add test-branch >/dev/null 2>&1
    local wt_dir
    wt_dir=$(get_worktree_dir "test-branch")
    cd "$wt_dir"
    commit_file "src/app.py" "content"
    cd "$REPO_DIR"

    run wt _resolve-branch-path test-branch/src/app.py
    [ "$status" -eq 0 ]
    local wt_path branch_name rel_path
    wt_path=$(echo "$output" | sed -n '1p')
    branch_name=$(echo "$output" | sed -n '2p')
    rel_path=$(echo "$output" | sed -n '3p')
    [ "$wt_path" = "$wt_dir" ]
    [ "$branch_name" = "test-branch" ]
    [ "$rel_path" = "src/app.py" ]
}

@test "_resolve-branch-path handles slash in branch name" {
    cd "$REPO_DIR"
    wt add feat/login >/dev/null 2>&1

    run wt _resolve-branch-path feat/login/auth.py
    [ "$status" -eq 0 ]
    local branch_name rel_path
    branch_name=$(echo "$output" | sed -n '2p')
    rel_path=$(echo "$output" | sed -n '3p')
    [ "$branch_name" = "feat/login" ]
    [ "$rel_path" = "auth.py" ]
}

@test "_resolve-branch-path fails for non-existent branch" {
    cd "$REPO_DIR"
    run wt _resolve-branch-path nonexistent/file.py
    [ "$status" -ne 0 ]
}

@test "_resolve-branch-path fails without slash" {
    cd "$REPO_DIR"
    wt add some-branch >/dev/null 2>&1
    run wt _resolve-branch-path some-branch
    [ "$status" -ne 0 ]
}

@test "resolve_worktree rejects path outside any worktree" {
    cd "$REPO_DIR"
    local random_dir="$TEST_DIR/not-a-worktree"
    mkdir -p "$random_dir"

    run wt cd "$random_dir"
    [ "$status" -ne 0 ]
}

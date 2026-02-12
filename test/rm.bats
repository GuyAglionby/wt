#!/usr/bin/env bats
# Tests for cmd_rm — worktree removal and branch deletion heuristic

load test_helper

# --- Branch deletion heuristic ---

@test "rm deletes branch when no commits made (HEAD == starting_commit)" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "no-changes"

    run wt rm no-changes
    [ "$status" -eq 0 ]
    [[ "$output" == *"Branch deleted"* ]]
    [[ "$output" == *"no changes"* ]]

    # Branch should be gone
    ! git show-ref --verify --quiet "refs/heads/no-changes"
}

@test "rm retains branch when commits were made" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "has-commits"

    local wt_dir
    wt_dir=$(get_worktree_dir "has-commits")
    cd "$wt_dir"
    commit_file "new-work.txt"
    cd "$REPO_DIR"

    run wt rm has-commits
    [ "$status" -eq 0 ]
    [[ "$output" == *"Branch retained"* ]]

    # Branch should still exist
    git show-ref --verify --quiet "refs/heads/has-commits"
}

@test "rm retains branch when no starting_commit recorded" {
    cd "$REPO_DIR"
    commit_file "base.txt"

    # Manually create a worktree without wt (no starting_commit)
    local wt_dir
    wt_dir=$(get_worktree_dir "manual-wt")
    git worktree add "$wt_dir" -b manual-wt >/dev/null 2>&1

    run wt rm manual-wt
    [ "$status" -eq 0 ]
    [[ "$output" == *"Branch retained"* ]]
    [[ "$output" == *"no starting commit"* ]]
}

@test "rm --force-delete-branch always deletes" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "force-del"

    local wt_dir
    wt_dir=$(get_worktree_dir "force-del")
    cd "$wt_dir"
    commit_file "important-work.txt"
    cd "$REPO_DIR"

    run wt rm --force-delete-branch force-del
    [ "$status" -eq 0 ]
    [[ "$output" == *"Branch deleted"* ]]
    [[ "$output" == *"forced"* ]]

    ! git show-ref --verify --quiet "refs/heads/force-del"
}

@test "rm deletes branch when commits are reachable from remote default branch" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "merged-branch"

    local wt_dir
    wt_dir=$(get_worktree_dir "merged-branch")
    cd "$wt_dir"
    commit_file "feature.txt"
    local branch_head
    branch_head=$(git rev-parse HEAD)
    cd "$REPO_DIR"

    # Simulate: merge the branch into main, then update the remote ref
    git merge merged-branch -m "Merge merged-branch" >/dev/null 2>&1
    git update-ref refs/remotes/origin/main "$(git rev-parse main)"

    run wt rm merged-branch
    [ "$status" -eq 0 ]
    [[ "$output" == *"Branch deleted"* ]]
    [[ "$output" == *"already in"* ]]
}

@test "rm deletes branch when GitHub PR is merged and local matches PR head" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "pr-merged"

    local wt_dir
    wt_dir=$(get_worktree_dir "pr-merged")
    cd "$wt_dir"
    commit_file "pr-work.txt"
    local branch_head
    branch_head=$(git rev-parse HEAD)
    cd "$REPO_DIR"

    # Mock gh to return a merged PR with matching headRefOid
    mock_gh "42 MERGED $branch_head"

    run wt rm pr-merged
    [ "$status" -eq 0 ]
    [[ "$output" == *"Branch deleted"* ]]
    [[ "$output" == *"PR #42 merged"* ]]
}

@test "rm retains branch when PR is merged but local has additional commits" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "pr-extra"

    local wt_dir
    wt_dir=$(get_worktree_dir "pr-extra")
    cd "$wt_dir"
    commit_file "pr-work.txt"
    local pr_head
    pr_head=$(git rev-parse HEAD)
    commit_file "extra-work.txt"
    cd "$REPO_DIR"

    # Mock gh: PR merged at pr_head, but local has moved ahead
    mock_gh "99 MERGED $pr_head"

    run wt rm pr-extra
    [ "$status" -eq 0 ]
    [[ "$output" == *"Branch retained"* ]]
    [[ "$output" == *"additional commits"* ]]
}

@test "rm retains branch when PR exists but is not merged" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "pr-open"

    local wt_dir
    wt_dir=$(get_worktree_dir "pr-open")
    cd "$wt_dir"
    commit_file "open-work.txt"
    local branch_head
    branch_head=$(git rev-parse HEAD)
    cd "$REPO_DIR"

    mock_gh "55 OPEN $branch_head"

    run wt rm pr-open
    [ "$status" -eq 0 ]
    [[ "$output" == *"Branch retained"* ]]
}

@test "rm retains branch when gh is not available (fallback)" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "no-gh"

    local wt_dir
    wt_dir=$(get_worktree_dir "no-gh")
    cd "$wt_dir"
    commit_file "work.txt"
    cd "$REPO_DIR"

    # gh mock already returns exit 1 (from setup)
    run wt rm no-gh
    [ "$status" -eq 0 ]
    [[ "$output" == *"Branch retained"* ]]
}

# --- Safety ---

@test "rm rejects removal when untracked files present" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "has-untracked"

    local wt_dir
    wt_dir=$(get_worktree_dir "has-untracked")
    echo "temp data" > "$wt_dir/untracked.txt"

    run wt rm has-untracked
    [ "$status" -ne 0 ]
    [[ "$output" == *"untracked files"* ]]
}

@test "rm allows removal with --force despite untracked files" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "force-untracked"

    local wt_dir
    wt_dir=$(get_worktree_dir "force-untracked")
    echo "temp data" > "$wt_dir/untracked.txt"

    run wt rm --force force-untracked
    [ "$status" -eq 0 ]
    [[ "$output" == *"Worktree removed"* ]]
    [ ! -d "$wt_dir" ]
}

@test "rm removes worktree directory" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "remove-dir"

    local wt_dir
    wt_dir=$(get_worktree_dir "remove-dir")
    [ -d "$wt_dir" ]

    run wt rm remove-dir
    [ "$status" -eq 0 ]
    [ ! -d "$wt_dir" ]
}

@test "rm emits __WT_CD__ when user is inside removed worktree" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "cd-on-rm"

    local wt_dir
    wt_dir=$(get_worktree_dir "cd-on-rm")
    cd "$wt_dir"

    run wt rm cd-on-rm
    [ "$status" -eq 0 ]
    [[ "$output" == *"__WT_CD__:${REPO_DIR}"* ]]
}

# --- Multiple removal ---

@test "rm removes multiple worktrees in one call" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "multi-a"
    create_worktree "multi-b"

    local dir_a dir_b
    dir_a=$(get_worktree_dir "multi-a")
    dir_b=$(get_worktree_dir "multi-b")
    [ -d "$dir_a" ]
    [ -d "$dir_b" ]

    cd "$REPO_DIR"
    run wt rm multi-a multi-b
    [ "$status" -eq 0 ]
    [ ! -d "$dir_a" ]
    [ ! -d "$dir_b" ]
}

@test "rm continues on partial failures and returns error" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "good-rm"

    # "bad-rm" doesn't exist
    cd "$REPO_DIR"
    run wt rm bad-rm good-rm
    [ "$status" -ne 0 ]
    # good-rm should still have been removed
    local good_dir
    good_dir=$(get_worktree_dir "good-rm")
    [ ! -d "$good_dir" ]
}

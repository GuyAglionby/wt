#!/usr/bin/env bats
# Tests for agent file sync and three-way merge

load test_helper

@test "sync-agent: new file in worktree is copied to main" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "sync-new"

    local wt_dir
    wt_dir=$(get_worktree_dir "sync-new")

    # Create a new agent file only in the worktree
    echo "# New agent file" > "$wt_dir/AGENTS.md"

    cd "$wt_dir"
    run wt sync-agent
    [ "$status" -eq 0 ]
    [[ "$output" == *"Copying new file"* ]]
    [ -f "$REPO_DIR/AGENTS.md" ]
    grep -q "New agent file" "$REPO_DIR/AGENTS.md"
}

@test "sync-agent: unchanged file produces no action" {
    cd "$REPO_DIR"
    echo "# Same content" > CLAUDE.md
    git add CLAUDE.md && git commit -m "Add CLAUDE.md" >/dev/null 2>&1
    create_worktree "sync-unchanged"

    local wt_dir
    wt_dir=$(get_worktree_dir "sync-unchanged")

    cd "$wt_dir"
    run wt sync-agent
    [ "$status" -eq 0 ]
    # Should not mention merging or copying
    [[ "$output" != *"Merging"* ]]
    [[ "$output" != *"Copying"* ]]
}

@test "sync-agent: worktree-only changes are merged cleanly" {
    cd "$REPO_DIR"
    echo "# Original" > CLAUDE.md
    git add CLAUDE.md && git commit -m "Add CLAUDE.md" >/dev/null 2>&1
    create_worktree "sync-wt-only"

    local wt_dir
    wt_dir=$(get_worktree_dir "sync-wt-only")
    echo "# Modified in worktree" > "$wt_dir/CLAUDE.md"

    cd "$wt_dir"
    run wt sync-agent
    [ "$status" -eq 0 ]
    [[ "$output" == *"Merging"* ]]
    grep -q "Modified in worktree" "$REPO_DIR/CLAUDE.md"
}

@test "sync-agent: both sides changed, no conflict, merges cleanly" {
    cd "$REPO_DIR"
    # Create a multi-line file so changes can be in different regions
    printf 'line1\nline2\nline3\nline4\nline5\n' > CLAUDE.md
    git add CLAUDE.md && git commit -m "Add CLAUDE.md" >/dev/null 2>&1
    create_worktree "sync-both"

    local wt_dir
    wt_dir=$(get_worktree_dir "sync-both")

    # Change different lines in each
    cd "$REPO_DIR"
    printf 'line1-main\nline2\nline3\nline4\nline5\n' > CLAUDE.md

    printf 'line1\nline2\nline3\nline4\nline5-wt\n' > "$wt_dir/CLAUDE.md"

    cd "$wt_dir"
    run wt sync-agent
    [ "$status" -eq 0 ]
    [[ "$output" == *"Merged"* ]]
    # Both changes should be present
    grep -q "line1-main" "$REPO_DIR/CLAUDE.md"
    grep -q "line5-wt" "$REPO_DIR/CLAUDE.md"
}

@test "sync-agent: conflict returns error" {
    cd "$REPO_DIR"
    echo "original content" > CLAUDE.md
    git add CLAUDE.md && git commit -m "Add CLAUDE.md" >/dev/null 2>&1
    create_worktree "sync-conflict"

    local wt_dir
    wt_dir=$(get_worktree_dir "sync-conflict")

    # Change the same line in both
    echo "main version" > "$REPO_DIR/CLAUDE.md"
    echo "worktree version" > "$wt_dir/CLAUDE.md"

    # Set EDITOR to something that preserves conflict markers
    export EDITOR="cat"

    cd "$wt_dir"
    run wt sync-agent
    [ "$status" -ne 0 ]
}

@test "sync-agent: no base snapshot uses worktree version with warning" {
    cd "$REPO_DIR"
    echo "# Main version" > CLAUDE.md
    git add CLAUDE.md && git commit -m "Add CLAUDE.md" >/dev/null 2>&1
    create_worktree "sync-no-base"

    local wt_dir
    wt_dir=$(get_worktree_dir "sync-no-base")
    local wt_name
    wt_name=$(basename "$(git -C "$wt_dir" rev-parse --git-dir)")

    # Remove the base snapshot
    rm -rf "$REPO_DIR/.git/worktrees/$wt_name/agent_base"

    echo "# Worktree version" > "$wt_dir/CLAUDE.md"

    cd "$wt_dir"
    run wt sync-agent
    [ "$status" -eq 0 ]
    [[ "$output" == *"no base snapshot"* ]]
    grep -q "Worktree version" "$REPO_DIR/CLAUDE.md"
}

@test "sync-agent --dry-run shows what would be merged without writing" {
    cd "$REPO_DIR"
    echo "# Original" > CLAUDE.md
    git add CLAUDE.md && git commit -m "Add CLAUDE.md" >/dev/null 2>&1
    create_worktree "sync-dry"

    local wt_dir
    wt_dir=$(get_worktree_dir "sync-dry")
    echo "# Changed" > "$wt_dir/CLAUDE.md"

    cd "$wt_dir"
    run wt sync-agent --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Would merge"* ]]

    # Main file should still have original content
    grep -q "Original" "$REPO_DIR/CLAUDE.md"
}

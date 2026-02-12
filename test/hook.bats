#!/usr/bin/env bats
# Tests for post-rewrite hook installation and behavior

load test_helper

# --- Installation ---

@test "hook: creates hook file when none exists" {
    cd "$REPO_DIR"
    rm -f "$REPO_DIR/.git/hooks/post-rewrite"
    create_worktree "hook-create"

    [ -f "$REPO_DIR/.git/hooks/post-rewrite" ]
    head -1 "$REPO_DIR/.git/hooks/post-rewrite" | grep -q "#!/usr/bin/env bash"
    grep -q "BEGIN WT" "$REPO_DIR/.git/hooks/post-rewrite"
    grep -q "END WT" "$REPO_DIR/.git/hooks/post-rewrite"
}

@test "hook: appends to existing hook without WT markers" {
    cd "$REPO_DIR"
    mkdir -p "$REPO_DIR/.git/hooks"
    printf '#!/usr/bin/env bash\necho "existing hook"\n' > "$REPO_DIR/.git/hooks/post-rewrite"
    chmod +x "$REPO_DIR/.git/hooks/post-rewrite"

    create_worktree "hook-append"

    grep -q 'echo "existing hook"' "$REPO_DIR/.git/hooks/post-rewrite"
    grep -q "BEGIN WT" "$REPO_DIR/.git/hooks/post-rewrite"
}

@test "hook: replaces existing WT section (idempotency)" {
    cd "$REPO_DIR"
    commit_file "base.txt"
    create_worktree "hook-first"

    # Count WT sections — should be exactly one
    local count
    count=$(grep -c "BEGIN WT" "$REPO_DIR/.git/hooks/post-rewrite")
    [ "$count" -eq 1 ]

    # Add another worktree — hook should still have exactly one section
    create_worktree "hook-second"
    count=$(grep -c "BEGIN WT" "$REPO_DIR/.git/hooks/post-rewrite")
    [ "$count" -eq 1 ]
}

@test "hook: preserves content outside WT markers" {
    cd "$REPO_DIR"
    mkdir -p "$REPO_DIR/.git/hooks"
    cat > "$REPO_DIR/.git/hooks/post-rewrite" <<'EOF'
#!/usr/bin/env bash
echo "before wt"
# --- BEGIN WT ---
echo "old wt content"
# --- END WT ---
echo "after wt"
EOF
    chmod +x "$REPO_DIR/.git/hooks/post-rewrite"

    create_worktree "hook-preserve"

    grep -q 'echo "before wt"' "$REPO_DIR/.git/hooks/post-rewrite"
    grep -q 'echo "after wt"' "$REPO_DIR/.git/hooks/post-rewrite"
    # Old content should be replaced
    ! grep -q 'echo "old wt content"' "$REPO_DIR/.git/hooks/post-rewrite"
    # New content should be present
    grep -q 'starting_commit' "$REPO_DIR/.git/hooks/post-rewrite"
}

@test "hook: file is executable" {
    cd "$REPO_DIR"
    create_worktree "hook-exec"
    [ -x "$REPO_DIR/.git/hooks/post-rewrite" ]
}

# --- Behavior (end-to-end) ---

@test "hook: rebase onto new base updates starting_commit" {
    cd "$REPO_DIR"
    commit_file "base.txt" "base"
    local base_commit
    base_commit=$(git rev-parse HEAD)

    create_worktree "hook-rebase"
    local wt_dir
    wt_dir=$(get_worktree_dir "hook-rebase")

    local original_sc
    original_sc=$(get_starting_commit "hook-rebase")
    [ "$original_sc" = "$base_commit" ]

    # Make a commit in the worktree
    cd "$wt_dir"
    commit_file "feature.txt" "feature work"

    # Create a divergent base on main (reset and recommit differently)
    cd "$REPO_DIR"
    local initial_commit
    initial_commit=$(git rev-parse HEAD~1)
    git reset --hard "$initial_commit" >/dev/null 2>&1
    commit_file "new-base.txt" "divergent base"
    local new_base
    new_base=$(git rev-parse HEAD)

    # Rebase worktree onto the divergent main using --onto
    cd "$wt_dir"
    git rebase --onto "$new_base" "$base_commit" hook-rebase >/dev/null 2>&1

    # old base_commit is NOT an ancestor of HEAD now
    # so the hook should update starting_commit to new_base
    local updated_sc
    updated_sc=$(get_starting_commit "hook-rebase")
    [ "$updated_sc" = "$new_base" ]
}

@test "hook: squash rebase preserves starting_commit when base unchanged" {
    cd "$REPO_DIR"
    commit_file "base.txt" "base"
    local base_commit
    base_commit=$(git rev-parse HEAD)

    create_worktree "hook-squash"
    local wt_dir
    wt_dir=$(get_worktree_dir "hook-squash")

    cd "$wt_dir"
    commit_file "a.txt" "a"
    commit_file "b.txt" "b"

    local original_sc
    original_sc=$(get_starting_commit "hook-squash")

    # Squash the two commits into one (still on same base)
    GIT_SEQUENCE_EDITOR="sed -i.bak 's/^pick/fixup/' " git rebase -i HEAD~2 2>/dev/null || \
    GIT_SEQUENCE_EDITOR="sed -i '' 's/^pick/fixup/' " git rebase -i HEAD~2 2>/dev/null || true

    # starting_commit should remain the same (base didn't change)
    local updated_sc
    updated_sc=$(get_starting_commit "hook-squash")
    [ "$updated_sc" = "$original_sc" ]
}

@test "hook: only fires for rebase, not amend" {
    cd "$REPO_DIR"
    commit_file "base.txt" "base"
    create_worktree "hook-amend"

    local wt_dir
    wt_dir=$(get_worktree_dir "hook-amend")
    cd "$wt_dir"
    commit_file "feature.txt" "feature"

    local original_sc
    original_sc=$(get_starting_commit "hook-amend")

    # Amend the commit
    echo "amended" > feature.txt
    git add feature.txt
    git commit --amend -m "Amended feature" >/dev/null 2>&1

    # starting_commit should not change
    local updated_sc
    updated_sc=$(get_starting_commit "hook-amend")
    [ "$updated_sc" = "$original_sc" ]
}

@test "hook: only acts in linked worktrees, not main repo" {
    cd "$REPO_DIR"
    commit_file "base.txt" "base"
    create_worktree "hook-main-test"

    # Verify hook exists
    [ -f "$REPO_DIR/.git/hooks/post-rewrite" ]

    # Make commits on main and rebase (simulate)
    cd "$REPO_DIR"
    commit_file "a.txt" "a"
    commit_file "b.txt" "b"

    # The hook should not crash or try to update anything for main repo
    # (git_dir for main doesn't contain /worktrees/)
    GIT_SEQUENCE_EDITOR="sed -i.bak 's/^pick/fixup/' " git rebase -i HEAD~2 2>/dev/null || \
    GIT_SEQUENCE_EDITOR="sed -i '' 's/^pick/fixup/' " git rebase -i HEAD~2 2>/dev/null || true

    # No starting_commit file should be created for main
    [ ! -f "$REPO_DIR/.git/starting_commit" ]
}

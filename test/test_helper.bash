# test/test_helper.bash — shared setup/teardown and helpers for wt bats tests

WT_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/wt"

_common_setup() {
    TEST_DIR="$(cd "$(mktemp -d)" && pwd -P)"
    TEST_HOME="$(cd "$(mktemp -d)" && pwd -P)"
    ORIG_HOME="$HOME"
    export HOME="$TEST_HOME"

    export GIT_AUTHOR_NAME="Test User"
    export GIT_AUTHOR_EMAIL="test@example.com"
    export GIT_COMMITTER_NAME="Test User"
    export GIT_COMMITTER_EMAIL="test@example.com"
    export GIT_CONFIG_NOSYSTEM=1

    REPO_DIR="$TEST_DIR/myrepo"
    mkdir -p "$REPO_DIR"
    cd "$REPO_DIR"
    git init -b main >/dev/null 2>&1
    git commit --allow-empty -m "Initial commit" >/dev/null 2>&1

    # Put wt on PATH (and our mock bin dir)
    mkdir -p "$TEST_DIR/bin"
    cp "$WT_BIN" "$TEST_DIR/bin/wt"
    chmod +x "$TEST_DIR/bin/wt"
    export PATH="$TEST_DIR/bin:$PATH"

    # Remove gh from PATH so tests don't hit real GitHub
    unmock_gh
}

_common_teardown() {
    cd /
    rm -rf "$TEST_DIR" "$TEST_HOME"
    export HOME="$ORIG_HOME"
}

setup() {
    _common_setup
}

teardown() {
    _common_teardown
}

# --- Helpers ---

commit_file() {
    local filename="$1"
    local content="${2:-content of $filename}"
    mkdir -p "$(dirname "$filename")"
    printf '%s\n' "$content" > "$filename"
    git add "$filename"
    git commit -m "Add $filename" >/dev/null 2>&1
}

get_worktree_dir() {
    local branch="$1"
    local safe_branch="${branch//\//-}"
    local repo_name
    repo_name=$(basename "$REPO_DIR")
    local parent_dir
    parent_dir=$(dirname "$REPO_DIR")
    echo "${parent_dir}/worktree--${repo_name}--${safe_branch}"
}

create_worktree() {
    local branch="$1"
    cd "$REPO_DIR"
    wt add "$branch" >/dev/null 2>&1
}

get_starting_commit() {
    local branch="$1"
    local wt_dir
    wt_dir=$(get_worktree_dir "$branch")
    local wt_name
    wt_name=$(basename "$(git -C "$wt_dir" rev-parse --git-dir)")
    cat "$REPO_DIR/.git/worktrees/$wt_name/starting_commit"
}

mock_gh() {
    local pr_output="${1:-}"
    local repo_nwo="${2:-}"
    local default_branch="${3:-main}"
    cat > "$TEST_DIR/bin/gh" <<GHEOF
#!/usr/bin/env bash
if [[ "\$1" == "pr" ]]; then
    echo '$pr_output'
elif [[ "\$1" == "repo" ]]; then
    for arg in "\$@"; do
        case "\$arg" in
            *nameWithOwner*) echo '$repo_nwo'; exit 0 ;;
            *defaultBranchRef*) echo '$default_branch'; exit 0 ;;
        esac
    done
fi
GHEOF
    chmod +x "$TEST_DIR/bin/gh"
}

unmock_gh() {
    # Create a gh that always fails, so tests never hit real GitHub
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/gh" <<'GHEOF'
#!/usr/bin/env bash
exit 1
GHEOF
    chmod +x "$TEST_DIR/bin/gh"
}

# Extract a specific IPC signal value from $output
get_signal() {
    local signal="$1"
    echo "$output" | grep "^${signal}:" | head -1 | sed "s/^${signal}://"
}

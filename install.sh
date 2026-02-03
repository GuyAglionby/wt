#!/bin/sh
set -eu

WT_RAW_URL="https://raw.githubusercontent.com/GuyAglionby/wt/main/wt"
INSTALL_DIR="${WT_INSTALL_DIR:-$HOME/.local/bin}"

main() {
    mkdir -p "$INSTALL_DIR"

    local tmp
    tmp=$(mktemp)

    echo "Downloading wt to $INSTALL_DIR/wt..."
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$WT_RAW_URL" -o "$tmp"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$tmp" "$WT_RAW_URL"
    else
        echo "Error: curl or wget required" >&2
        rm -f "$tmp"
        exit 1
    fi

    if ! bash -n "$tmp" 2>/dev/null; then
        echo "Error: downloaded file has syntax errors, aborting" >&2
        rm -f "$tmp"
        exit 1
    fi

    chmod +x "$tmp"
    mv "$tmp" "$INSTALL_DIR/wt"

    # Detect shell and rc file
    local shell_name
    shell_name=$(basename "${SHELL:-bash}")
    local rc_file
    case "$shell_name" in
        zsh)  rc_file="$HOME/.zshrc" ;;
        bash) rc_file="$HOME/.bashrc" ;;
        *)
            echo "Installed wt to $INSTALL_DIR/wt"
            echo ""
            echo "Unsupported shell '$shell_name'. Manually add to your rc file:"
            echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
            echo '  eval "$(wt init)"'
            exit 0
            ;;
    esac

    local additions=""

    # Check if INSTALL_DIR is in PATH
    case ":$PATH:" in
        *":$INSTALL_DIR:"*) ;;
        *) additions="export PATH=\"$INSTALL_DIR:\$PATH\"" ;;
    esac

    # Check if wt init is already present
    local init_line='eval "$(wt init)"'
    if ! grep -qF "$init_line" "$rc_file" 2>/dev/null; then
        if [ -n "$additions" ]; then
            additions="$additions
$init_line"
        else
            additions="$init_line"
        fi
    fi

    if [ -n "$additions" ]; then
        printf '\n# wt\n%s\n' "$additions" >> "$rc_file"
        echo "Added to $rc_file:"
        echo "$additions" | while IFS= read -r line; do
            echo "  $line"
        done
    else
        echo "Shell integration already configured in $rc_file"
    fi

    echo ""
    echo "Installed wt to $INSTALL_DIR/wt"
    echo "Restart your shell or run: source $rc_file"
}

main

#!/bin/bash
set -e
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# Link home directories to SYNC_DIR
link_home_directories() {
    if [[ ! -f "$HOME_DIRS" ]] || [[ ! -s "$HOME_DIRS" ]]; then
        log_info "No home directories to link"
        return
    fi

    log_info "Linking home directories to $SYNC_DIR..."
    while IFS= read -r line || [[ -n "$line" ]]; do
        entry=$(parse_entry "$line") || continue

        local target="$HOME/$entry"
        local sync_target="$SYNC_DIR/$entry"

        if [[ -L "$target" ]]; then
            log_info "Already linked: ~/$entry"
            continue
        fi

        if [[ -d "$target" ]]; then
            if [[ -e "${target}_old" ]]; then
                log_warn "Cannot rename ~/$entry — ~/${entry}_old already exists, skipping"
                continue
            fi
            mv "$target" "${target}_old"
            log_info "Renamed ~/$entry to ~/${entry}_old"
        fi

        mkdir -p "$sync_target"
        ln -s "$sync_target" "$target"
        log_info "Linked ~/$entry -> $sync_target"
    done < "$HOME_DIRS"
}

link_home_directories

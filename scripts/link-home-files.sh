#!/bin/bash
set -e
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# Link home files to SYNC_DIR
link_home_files() {
    if [[ ! -f "$HOME_FILES" ]] || [[ ! -s "$HOME_FILES" ]]; then
        log_info "No home files to link"
        return
    fi

    log_info "Linking home files to $SYNC_DIR..."
    while IFS= read -r line || [[ -n "$line" ]]; do
        entry=$(parse_entry "$line") || continue

        local target="$HOME/$entry"
        local sync_target="$SYNC_DIR/$entry"

        if [[ -L "$target" ]]; then
            log_info "Already linked: ~/$entry"
            continue
        fi

        if [[ -f "$target" ]]; then
            if [[ -e "${target}_old" ]]; then
                log_warn "Cannot rename ~/$entry — ~/${entry}_old already exists, skipping"
                continue
            fi
            mkdir -p "$(dirname "$sync_target")"
            if [[ ! -e "$sync_target" ]]; then
                cp "$target" "$sync_target"
            fi
            mv "$target" "${target}_old"
            log_info "Renamed ~/$entry to ~/${entry}_old"
        else
            mkdir -p "$(dirname "$sync_target")"
        fi

        ln -s "$sync_target" "$target"
        log_info "Linked ~/$entry -> $sync_target"
    done < "$HOME_FILES"
}

link_home_files

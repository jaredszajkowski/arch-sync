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
    local sync_root
    sync_root=$(realpath -m "$SYNC_DIR")
    while IFS= read -r line || [[ -n "$line" ]]; do
        entry=$(parse_entry "$line") || continue

        local target="$HOME/$entry"
        local sync_target="$SYNC_DIR/$entry"

        if [[ -L "$target" ]]; then
            log_info "Already linked: ~/$entry"
            continue
        fi

        # Guard: a parent of this entry is already linked into SYNC_DIR, so
        # $target resolves inside the sync tree. Renaming/linking it would
        # move the real synced file aside and create a self-referential link.
        local resolved
        resolved=$(realpath -m "$target")
        if [[ "$resolved" == "$sync_root" || "$resolved" == "$sync_root"/* ]]; then
            log_warn "Skipping ~/$entry — already inside $SYNC_DIR via a linked parent directory (remove this entry from $(basename "$HOME_FILES"))"
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

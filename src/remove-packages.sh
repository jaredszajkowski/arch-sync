#!/bin/bash
set -e
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# Remove unwanted packages
remove_packages() {
    if [[ ! -f "$REMOVE_LIST" ]] || [[ ! -s "$REMOVE_LIST" ]]; then
        log_info "No packages to remove"
        return
    fi

    log_info "Checking packages to remove..."
    local to_remove=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        pkg=$(parse_entry "$line") || continue

        if pacman -Qi "$pkg" &>/dev/null; then
            to_remove+=("$pkg")
        fi
    done < "$REMOVE_LIST"

    if [[ ${#to_remove[@]} -gt 0 ]]; then
        log_info "Removing packages: ${to_remove[*]}"
        for pkg in "${to_remove[@]}"; do
            if ! yay -Rns --noconfirm "$pkg"; then
                log_warn "Failed to remove $pkg (may already be removed or not found), skipping..."
            fi
        done
    else
        log_info "No packages need to be removed"
    fi
}

remove_packages

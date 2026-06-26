#!/bin/bash
set -e
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# Sync mirrorlist
sync_mirrors() {
    log_info "Syncing mirrorlist..."
    if [[ -f "$MIRROR_LIST" ]]; then
        sudo cp "$MIRROR_LIST" /etc/pacman.d/mirrorlist
        log_info "Mirrorlist updated"
    else
        log_warn "Mirrorlist file not found: $MIRROR_LIST"
    fi
}

sync_mirrors

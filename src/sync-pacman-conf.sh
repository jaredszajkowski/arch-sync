#!/bin/bash
set -e
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# Sync pacman.conf
sync_pacman_conf() {
    log_info "Syncing pacman.conf..."
    if [[ -f "$PACMAN_CONF" ]]; then
        sudo cp "$PACMAN_CONF" /etc/pacman.conf
        log_info "pacman.conf updated"
    else
        log_warn "pacman.conf file not found: $PACMAN_CONF"
    fi
}

sync_pacman_conf

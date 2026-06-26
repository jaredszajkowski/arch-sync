#!/bin/bash
# arch-sync.sh - Synchronize Arch Linux configuration across machines.
# Orchestrator: runs each step script under scripts/ in order. Individual
# steps can also be run on their own (e.g. ./scripts/sort-package-lists.sh).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STEPS="${SCRIPT_DIR}/scripts"

# Shared logging + root check
source "${STEPS}/common.sh"

main() {
    log_info "Starting Arch Linux sync..."

    # Update package databases (yay updates both official and AUR)
    "${STEPS}/update-databases.sh"

    # Sync mirrorlist first
    "${STEPS}/sync-mirrors.sh"

    # Sync pacman.conf
    "${STEPS}/sync-pacman-conf.sh"

    # Deduplicate package lists before acting on them
    "${STEPS}/dedupe-package-lists.sh"

    # Remove unwanted packages
    "${STEPS}/remove-packages.sh"

    # Remove directories
    "${STEPS}/remove-directories.sh"

    # Link home directories to sync folder
    "${STEPS}/link-home-directories.sh"

    # Link home files to sync folder
    "${STEPS}/link-home-files.sh"

    # Install official packages
    "${STEPS}/install-packages.sh"

    # Install AUR packages
    "${STEPS}/install-aur-packages.sh"

    # Sort package lists alphabetically
    "${STEPS}/sort-package-lists.sh"

    log_info "Sync complete!"
}

main "$@"

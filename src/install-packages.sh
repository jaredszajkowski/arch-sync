#!/bin/bash
set -e
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# Install official repository packages
install_packages() {
    if [[ ! -f "$PACKAGE_LIST" ]]; then
        log_error "Package list not found: $PACKAGE_LIST"
        exit 1
    fi

    log_info "Checking official packages to install..."
    local to_install=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        pkg=$(parse_entry "$line") || continue

        if ! pacman -Qq "$pkg" &>/dev/null; then
            to_install+=("$pkg")
        fi
    done < "$PACKAGE_LIST"

    if [[ ${#to_install[@]} -gt 0 ]]; then
        log_info "Installing official packages: ${to_install[*]}"
        sudo pacman -S --needed --noconfirm "${to_install[@]}"
    else
        log_info "All official packages already installed"
    fi
}

install_packages

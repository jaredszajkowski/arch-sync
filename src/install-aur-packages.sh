#!/bin/bash
set -e
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# Install AUR packages
install_aur_packages() {
    if [[ ! -f "$AUR_PACKAGE_LIST" ]] || [[ ! -s "$AUR_PACKAGE_LIST" ]]; then
        log_info "No AUR packages to install"
        return
    fi

    if ! command -v yay &>/dev/null; then
        log_error "yay is not installed. Please install yay first."
        exit 1
    fi

    log_info "Checking AUR packages to install..."
    local to_install=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        pkg=$(parse_entry "$line") || continue

        if ! yay -Qq "$pkg" &>/dev/null; then
            to_install+=("$pkg")
        fi
    done < "$AUR_PACKAGE_LIST"

    if [[ ${#to_install[@]} -gt 0 ]]; then
        log_info "Installing AUR packages: ${to_install[*]}"
        yay -S --needed --noconfirm "${to_install[@]}"
    else
        log_info "All AUR packages already installed"
    fi
}

install_aur_packages

#!/bin/bash
# arch-sync.sh - Synchronize Arch Linux configuration across machines

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_LIST="${SCRIPT_DIR}/packages.txt"
AUR_PACKAGE_LIST="${SCRIPT_DIR}/packages-aur.txt"
REMOVE_LIST="${SCRIPT_DIR}/packages-remove.txt"
MIRROR_LIST="${SCRIPT_DIR}/mirrorlist"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   log_error "This script should not be run as root. It will use sudo when needed."
   exit 1
fi

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

# Remove unwanted packages
remove_packages() {
    if [[ ! -f "$REMOVE_LIST" ]] || [[ ! -s "$REMOVE_LIST" ]]; then
        log_info "No packages to remove"
        return
    fi
    
    log_info "Checking packages to remove..."
    local to_remove=()
    while IFS= read -r pkg || [[ -n "$pkg" ]]; do
        # Skip comments and empty lines
        if [[ "$pkg" =~ ^#.*$ ]] || [[ -z "$pkg" ]]; then
            continue
        fi
        
        # Check with yay (works for both official and AUR)
        if yay -Qq "$pkg" &>/dev/null; then
            to_remove+=("$pkg")
        fi
    done < "$REMOVE_LIST"
    
    if [[ ${#to_remove[@]} -gt 0 ]]; then
        log_info "Removing packages: ${to_remove[*]}"
        yay -Rns --noconfirm "${to_remove[@]}"
    else
        log_info "No packages need to be removed"
    fi
}

# Install official repository packages
install_packages() {
    if [[ ! -f "$PACKAGE_LIST" ]]; then
        log_error "Package list not found: $PACKAGE_LIST"
        exit 1
    fi
    
    log_info "Checking official packages to install..."
    local to_install=()
    while IFS= read -r pkg || [[ -n "$pkg" ]]; do
        # Skip comments and empty lines
        if [[ "$pkg" =~ ^#.*$ ]] || [[ -z "$pkg" ]]; then
            continue
        fi
        
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
    while IFS= read -r pkg || [[ -n "$pkg" ]]; do
        # Skip comments and empty lines
        if [[ "$pkg" =~ ^#.*$ ]] || [[ -z "$pkg" ]]; then
            continue
        fi
        
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

# Main execution
main() {
    log_info "Starting Arch Linux sync..."
    
    # Update package database (yay updates both official and AUR)
    log_info "Updating package databases..."
    yay -Sy
    
    # Sync mirrorlist first
    sync_mirrors
    
    # Remove unwanted packages
    remove_packages
    
    # Install official packages
    install_packages
    
    # Install AUR packages
    install_aur_packages
    
    log_info "Sync complete!"
}

# Run main function
main "$@"

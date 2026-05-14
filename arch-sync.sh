#!/bin/bash
# arch-sync.sh - Synchronize Arch Linux configuration across machines

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_HOST=$HOSTNAME
PACKAGE_LIST="${SCRIPT_DIR}/packages-install.txt"
AUR_PACKAGE_LIST="${SCRIPT_DIR}/packages-aur-install.txt"
REMOVE_LIST="${SCRIPT_DIR}/packages-remove.txt"
REMOVE_DIRS="${SCRIPT_DIR}/directories-remove.txt"
HOME_DIRS="${SCRIPT_DIR}/home-directories.txt"
MIRROR_LIST="${SCRIPT_DIR}/mirrorlist"
SYNC_DIR="$HOME/Cloud_Storage/Dropbox"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_prompt() { echo -e "${BLUE}[PROMPT]${NC} $1"; }

# Outputs the entry (package name or path) if the line applies to this host.
# Lines with no @hostname tags apply to all hosts.
# Returns 1 for blank lines, comments, and entries filtered by hostname.
# Note: paths with embedded spaces are not supported when using @hostname tags.
parse_entry() {
    local line="$1"

    # Skip blank lines and full-line comments
    [[ -z "${line// }" || "$line" =~ ^[[:space:]]*# ]] && return 1

    # Strip inline comment
    local content="${line%%#*}"

    # Split into entry words and @hostname tags
    local entry="" tags=()
    local word
    for word in $content; do
        if [[ "$word" == @* ]]; then
            tags+=("${word:1}")
        else
            entry="$entry $word"
        fi
    done
    entry="${entry# }"

    [[ -z "$entry" ]] && return 1

    # No tags → applies to all hosts
    if [[ ${#tags[@]} -eq 0 ]]; then
        echo "$entry"
        return 0
    fi

    # Check if current host matches any tag
    local tag
    for tag in "${tags[@]}"; do
        if [[ "$tag" == "$CURRENT_HOST" ]]; then
            echo "$entry"
            return 0
        fi
    done

    return 1
}

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

# Remove directories
remove_directories() {
    if [[ ! -f "$REMOVE_DIRS" ]] || [[ ! -s "$REMOVE_DIRS" ]]; then
        log_info "No directories to remove"
        return
    fi
    
    log_info "Checking directories to remove..."
    local to_remove=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        dir=$(parse_entry "$line") || continue

        # Expand tilde to home directory
        dir="${dir/#\~/$HOME}"

        if [[ -d "$dir" ]] || [[ -f "$dir" ]]; then
            to_remove+=("$dir")
        fi
    done < "$REMOVE_DIRS"
    
    if [[ ${#to_remove[@]} -gt 0 ]]; then
        log_warn "The following directories/files will be removed:"
        for dir in "${to_remove[@]}"; do
            echo "  - $dir"
        done
        
        log_prompt "Do you want to proceed? (y/N): "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            for dir in "${to_remove[@]}"; do
                log_info "Removing: $dir"
                rm -rf "$dir"
            done
            log_info "Directory removal complete"
        else
            log_info "Directory removal skipped"
        fi
    else
        log_info "No directories need to be removed"
    fi
}

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

    # Remove directories
    remove_directories

    # Link home directories to sync folder
    link_home_directories

    # Install official packages
    install_packages
    
    # Install AUR packages
    install_aur_packages
    
    log_info "Sync complete!"
}

# Run main function
main "$@"

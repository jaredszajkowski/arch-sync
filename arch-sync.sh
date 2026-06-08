#!/bin/bash
# arch-sync.sh - Synchronize Arch Linux configuration across machines

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_HOST=$HOSTNAME
CONFIG_DIR="${SCRIPT_DIR}/config"
PACKAGE_LIST="${CONFIG_DIR}/packages-install.txt"
AUR_PACKAGE_LIST="${CONFIG_DIR}/packages-aur-install.txt"
REMOVE_LIST="${CONFIG_DIR}/packages-remove.txt"
REMOVE_DIRS="${CONFIG_DIR}/directories-remove.txt"
HOME_DIRS="${CONFIG_DIR}/home-directories.txt"
HOME_FILES="${CONFIG_DIR}/home-files.txt"
MIRROR_LIST="${CONFIG_DIR}/mirrorlist"
PACMAN_CONF="${CONFIG_DIR}/pacman.conf"
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

# Host-agnostic variant of parse_entry used for deduplication.
# Echoes "<flag> <name>" where <flag> is 1 if the line carried any @hostname
# tag (else 0) and <name> is the bare package name (inline comment and @tags
# stripped), regardless of host. Output is captured via command substitution,
# so the tag flag travels through stdout rather than a global.
# Returns 1 for blank lines and full-line comments.
entry_name() {
    local line="$1"

    # Skip blank lines and full-line comments
    [[ -z "${line// }" || "$line" =~ ^[[:space:]]*# ]] && return 1

    # Strip inline comment
    local content="${line%%#*}"

    local entry="" has_tags=0 word
    for word in $content; do
        if [[ "$word" == @* ]]; then
            has_tags=1
        else
            entry="$entry $word"
        fi
    done
    entry="${entry# }"

    [[ -z "$entry" ]] && return 1

    echo "$has_tags $entry"
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

# Remove within-file duplicate package names from a list file. Only untagged
# entries are considered: the first occurrence of a name is kept (with its
# inline comment), later untagged duplicates are dropped. Entries carrying an
# @hostname tag, comments, and blank lines are preserved verbatim.
dedupe_internal() {
    local file="$1"
    [[ -f "$file" ]] || return 0

    local out=() seen=" "
    local line parsed name
    while IFS= read -r line || [[ -n "$line" ]]; do
        if parsed=$(entry_name "$line") && [[ "${parsed%% *}" == 0 ]]; then
            name="${parsed#* }"
            if [[ "$seen" == *" $name "* ]]; then
                log_warn "Removing duplicate '$name' from $(basename "$file")"
                continue
            fi
            seen="$seen$name "
        fi
        out+=("$line")
    done < "$file"

    if [[ ${#out[@]} -gt 0 ]]; then
        printf '%s\n' "${out[@]}" > "$file"
    fi
}

# Drop untagged package names from the install lists if the same name appears
# untagged in the remove list. The package is kept only in the remove list.
# Tagged entries on either side are left untouched.
dedupe_install_against_remove() {
    [[ -f "$REMOVE_LIST" ]] || return 0

    # Collect untagged names present in the remove list
    local remove_names=" " line parsed name
    while IFS= read -r line || [[ -n "$line" ]]; do
        if parsed=$(entry_name "$line") && [[ "${parsed%% *}" == 0 ]]; then
            remove_names="$remove_names${parsed#* } "
        fi
    done < "$REMOVE_LIST"

    local file out=()
    for file in "$PACKAGE_LIST" "$AUR_PACKAGE_LIST"; do
        [[ -f "$file" ]] || continue
        out=()
        while IFS= read -r line || [[ -n "$line" ]]; do
            if parsed=$(entry_name "$line") && [[ "${parsed%% *}" == 0 ]]; then
                name="${parsed#* }"
                if [[ "$remove_names" == *" $name "* ]]; then
                    log_warn "'$name' is in the remove list — dropping from $(basename "$file")"
                    continue
                fi
            fi
            out+=("$line")
        done < "$file"
        if [[ ${#out[@]} -gt 0 ]]; then
            printf '%s\n' "${out[@]}" > "$file"
        fi
    done
}

# Deduplicate package names within and across the list files
dedupe_package_lists() {
    log_info "Deduplicating package lists..."
    dedupe_internal "$PACKAGE_LIST"
    dedupe_internal "$AUR_PACKAGE_LIST"
    dedupe_internal "$REMOVE_LIST"
    dedupe_install_against_remove
    log_info "Package lists deduplicated"
}

# Sort package names alphabetically in a list file, preserving the leading
# comment/blank header block. Inline comments and @hostname tags stay
# attached to their entry. Blank lines within the body are dropped.
sort_list_file() {
    local file="$1"
    [[ -f "$file" ]] || return 0

    local header=() entries=()
    local in_header=1 line
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ $in_header -eq 1 && ( -z "${line// }" || "$line" =~ ^[[:space:]]*# ) ]]; then
            header+=("$line")
        else
            in_header=0
            [[ -z "${line// }" ]] && continue
            entries+=("$line")
        fi
    done < "$file"

    {
        if [[ ${#header[@]} -gt 0 ]]; then
            printf '%s\n' "${header[@]}"
        fi
        if [[ ${#entries[@]} -gt 0 ]]; then
            printf '%s\n' "${entries[@]}" | sort -f
        fi
    } > "$file"
}

# Sort the package list files alphabetically
sort_package_lists() {
    log_info "Sorting package lists alphabetically..."
    sort_list_file "$PACKAGE_LIST"
    sort_list_file "$AUR_PACKAGE_LIST"
    sort_list_file "$REMOVE_LIST"
    log_info "Package lists sorted"
}

# Main execution
main() {
    log_info "Starting Arch Linux sync..."
    
    # Update package database (yay updates both official and AUR)
    log_info "Updating package databases..."
    yay -Sy
    
    # Sync mirrorlist first
    sync_mirrors

    # Sync pacman.conf
    sync_pacman_conf

    # Deduplicate package lists before acting on them
    dedupe_package_lists

    # Remove unwanted packages
    remove_packages

    # Remove directories
    remove_directories

    # Link home directories to sync folder
    link_home_directories

    # Link home files to sync folder
    link_home_files

    # Install official packages
    install_packages
    
    # Install AUR packages
    install_aur_packages

    # Sort package lists alphabetically
    sort_package_lists

    log_info "Sync complete!"
}

# Run main function
main "$@"

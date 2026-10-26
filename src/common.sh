#!/bin/bash
# common.sh - Shared configuration and helpers for the arch-sync step scripts.
# This file is meant to be sourced, not executed directly.

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$LIB_DIR")"
CONFIG_DIR="${REPO_DIR}/config"
CURRENT_HOST=$HOSTNAME
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

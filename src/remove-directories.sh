#!/bin/bash
set -e
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

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

remove_directories

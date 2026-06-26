#!/bin/bash
set -e
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

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

sort_package_lists

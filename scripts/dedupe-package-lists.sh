#!/bin/bash
set -e
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

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

dedupe_package_lists

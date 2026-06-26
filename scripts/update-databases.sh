#!/bin/bash
set -e
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# Update package databases (yay updates both official and AUR)
update_databases() {
    log_info "Updating package databases..."
    yay -Sy
}

update_databases

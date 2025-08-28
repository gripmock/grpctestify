#!/bin/bash

# update.sh - Update command implementation
# Handles updating grpctestify to the latest version

# All modules are automatically loaded by bashly

# Update command implementation
update_command() {
    local force_update
    force_update=$(get_config "force_update" "false")
    
    log section "$APP_NAME $version - Update"
    
    # Initialize application
    initialize_app
    
    log info "Checking for updates..."
    
    # Check for updates
    if check_for_updates; then
        local latest_version=$(get_latest_version)
        log info "New version available: $latest_version"
        
        if [[ "$force_update" == "true" ]] || confirm_update; then
            perform_update
        else
            log info "Update cancelled by user"
        fi
    else
        log info "Already up to date (current: $version)"
    fi
}

# Check for updates
check_for_updates() {
    local latest_version
    latest_version=$(get_latest_version)
    
    if [[ $? -ne 0 ]]; then
        log error "Failed to check for updates"
        return 1
    fi
    
    # Compare versions
    if [[ "$latest_version" != "$version" ]]; then
        return 0  # Update available
    else
        return 1  # No update available
    fi
}

# Get latest version from GitHub API
get_latest_version() {
    local api_url="https://api.github.com/repos/gripmock/grpctestify/releases/latest"
    local latest_version
    
    if ! command -v curl >/dev/null 2>&1; then
        log error "curl is required for update checking"
        return 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        log error "jq is required for update checking"
        return 1
    fi
    
    # Query GitHub API with timeout
    local response
    if ! response=$(curl -s --connect-timeout 10 --max-time 30 "$api_url" 2>&1); then
        handle_network_error "$api_url" $?
        return 1
    fi
    
    # Extract version from response
    if ! latest_version=$(echo "$response" | jq -r '.tag_name // empty' 2>/dev/null); then
        log error "Failed to parse GitHub API response"
        return 1
    fi
    
    if [[ -z "$latest_version" || "$latest_version" == "null" ]]; then
        log error "No version information found in API response"
        return 1
    fi
    
    echo "$latest_version"
    return 0
}

# Download latest version
download_latest() {
    local download_url="$1"
    local output_file="$2"
    
    log info "Downloading latest version from: $download_url"
    
    if ! command -v curl >/dev/null 2>&1; then
        log error "curl is required for downloading updates"
        return 1
    fi
    
    # Download with progress
    if ! curl -L --connect-timeout 10 --max-time 300 -o "$output_file" "$download_url" 2>&1; then
        handle_network_error "$download_url" $?
        return 1
    fi
    
    # Verify file was downloaded
    if [[ ! -f "$output_file" || ! -s "$output_file" ]]; then
        log error "Downloaded file is empty or missing"
        return 1
    fi
    
    log success "Download completed"
    return 0
}

# Verify checksum
verify_checksum() {
    local file="$1"
    local expected_checksum="$2"
    
    if [[ -z "$expected_checksum" ]]; then
        log warning "No checksum provided, skipping verification"
        return 0
    fi
    
    log info "Verifying checksum..."
    
    if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
        log warning "No SHA-256 tool available, skipping checksum verification"
        return 0
    fi
    
    # Calculate checksum
    local actual_checksum
    if command -v sha256sum >/dev/null 2>&1; then
        actual_checksum=$(sha256sum "$file" | cut -d' ' -f1)
    else
        actual_checksum=$(shasum -a 256 "$file" | cut -d' ' -f1)
    fi
    
    if [[ "$actual_checksum" == "$expected_checksum" ]]; then
        log success "Checksum verification passed"
        return 0
    else
        log error "Checksum verification failed"
        log error "Expected: $expected_checksum"
        log error "Actual: $actual_checksum"
        return 1
    fi
}

# Install update
install_update() {
    local update_file="$1"
    local target_file="$2"
    
    log info "Installing update..."
    
    # Create backup
    local backup_file="${target_file}.backup.$(date +%Y%m%d_%H%M%S)"
    if ! cp "$target_file" "$backup_file"; then
        log error "Failed to create backup"
        return 1
    fi
    
    log info "Backup created: $backup_file"
    
    # Replace with new version
    if ! cp "$update_file" "$target_file"; then
        log error "Failed to install update"
        # Restore backup
        cp "$backup_file" "$target_file"
        return 1
    fi
    
    # Set executable permissions
    if ! chmod +x "$target_file"; then
        log error "Failed to set executable permissions"
        return 1
    fi
    
    log success "Update installed successfully"
    log info "Backup available at: $backup_file"
    return 0
}

# Confirm update with user
confirm_update() {
    local latest_version="$1"
    
    echo ""
    log info "Update available: $version -> $latest_version"
    echo -n "Do you want to update? [y/N]: "
    read -r response
    
    case "$response" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Perform the complete update process
perform_update() {
    local latest_version=$(get_latest_version)
    local download_url="https://github.com/gripmock/grpctestify/releases/download/${latest_version}/grpctestify.sh"
    local temp_file=$(mktemp)
    local current_script="$0"
    
    # Download latest version
    if ! download_latest "$download_url" "$temp_file"; then
        rm -f "$temp_file"
        return 1
    fi
    
    # Verify checksum using checksums.txt file (like in original version)
    local checksum_url="https://github.com/gripmock/grpctestify/releases/download/${latest_version}/checksums.txt"
    local expected_checksum
    if expected_checksum=$(curl -s --connect-timeout 10 --max-time 30 "$checksum_url" 2>/dev/null | grep "grpctestify.sh" | awk '{print $1}'); then
        if [[ -n "$expected_checksum" ]]; then
            if ! verify_checksum "$temp_file" "$expected_checksum"; then
                rm -f "$temp_file"
                return 1
            fi
        else
            log warning "Could not find grpctestify.sh checksum in checksums.txt"
        fi
    else
        log warning "Could not fetch checksums.txt, proceeding without verification"
    fi
    
    # Install update
    if ! install_update "$temp_file" "$current_script"; then
        rm -f "$temp_file"
        return 1
    fi
    
    # Clean up
    rm -f "$temp_file"
    
    log success "Update completed successfully!"
    log info "New version: $latest_version"
    return 0
}

# Show update help
show_update_help() {
    echo "Update functionality:"
    echo ""
    echo "  $APP_NAME --update"
    echo ""
    echo "This command will:"
    echo "  1. Check for newer versions"
    echo "  2. Download the latest version"
    echo "  3. Verify checksum"
    echo "  4. Replace current script"
    echo ""
    echo "Current version: $version"
}

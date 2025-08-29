#!/bin/bash

# help.sh - Help command implementation
# shellcheck disable=SC2155,SC2221,SC2222 # Pattern matching and variable assignments
# Shows help information and usage examples

# Dependencies are loaded by loader.sh in root_command.sh

# Show help information
show_help() {
    echo "$APP_NAME - $APP_DESCRIPTION"
    echo ""
    echo "Usage:"
    echo "  $APP_NAME [TEST_PATH] [OPTIONS]"
    echo "  $APP_NAME --help"
    echo "  $APP_NAME --version"
    echo ""
    echo "Options:"
    echo "  --no-color, -c"
    echo "    Disable colored output"
    echo ""
    echo "  --verbose, -v"
    echo "    Enable verbose debug output"
    echo ""

    echo "  --parallel JOBS"
    echo "    Run N tests in parallel"
    echo "    Default: 1"
    echo ""
    echo "  --version"
    echo "    Show version information"
    echo ""
    echo "  --update"
    echo "    Check for updates and update the script"
    echo ""
    echo "  --help, -h"
    echo "    Show this help message"
    echo ""
    echo "Arguments:"
    echo "  TEST_PATH"
    echo "    Test file or directory"
    echo ""
    echo "Examples:"
    echo "  # Run single test file"
    echo "  $APP_NAME test.gctf"
    echo ""
    echo "  # Run all tests in directory"
    echo "  $APP_NAME examples/"
    echo ""
    echo "  # Run tests with verbose output"
    echo "  $APP_NAME --verbose examples/"
    echo ""
    echo "  # Run tests in parallel with progress"
    echo "  $APP_NAME examples/ --parallel 4"
    echo ""
    echo "  # Disable colors"
    echo "  $APP_NAME --no-color test.gctf"
    echo ""
    echo "  # Generate JUnit XML report"
    echo "  $APP_NAME tests/ --log-format junit --log-output results.xml"
    echo ""
    echo "  # Check for updates"
    echo "  $APP_NAME --update"
    echo ""
    echo "  # Show version"
    echo "  $APP_NAME --version"
    echo ""
    echo "Test File Format (.gctf):"
    echo "  --- ADDRESS ---"
    echo "  localhost:4770"
    echo ""
    echo "  --- ENDPOINT ---"
    echo "  package.service/Method"
    echo ""
    echo "  --- REQUEST ---"
    echo "  {"
    echo "    \"key\": \"value\""
    echo "  }"
    echo ""
    echo "  --- RESPONSE ---"
    echo "  {"
    echo "    \"status\": \"OK\""
    echo "  }"
    echo ""
    echo "For more information, visit: https://github.com/gripmock/grpctestify"
}

# Show version information
show_version() {
    # shellcheck disable=SC2154  # version is provided by bashly framework
    echo "$APP_NAME $version"
}

# Show update information
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
    # shellcheck disable=SC2154  # version is provided by bashly framework
    echo "Current version: $version"
}

# Show completion installation information
show_completion_help() {
    echo "Shell completion:"
    echo ""
    echo "  $APP_NAME --completion [bash|zsh|all]"
    echo ""
    echo "This command will:"
    echo "  1. Generate completion script for specified shell"
    echo "  2. Install completion to appropriate location"
    echo "  3. Provide instructions for activation"
    echo ""
    echo "Supported shells: bash, zsh, all (both)"
    echo "Default: all"
}

# Show current configuration
show_configuration() {
    echo "Current configuration:"
    echo ""
    # shellcheck disable=SC2154  # version is provided by bashly framework
    echo "  Version: $version"
    echo "  Script: $(basename "$0")"
    echo "  Working directory: $(pwd)"
    echo ""
    echo "Dependencies:"
    if command_exists grpcurl; then
        echo "  ✅ grpcurl: $(grpcurl --version 2>&1 | head -n1 | awk '{print $2}' || echo "installed")"
    else
        echo "  ❌ grpcurl: not installed"
    fi
    
    if command_exists jq; then
        echo "  ✅ jq: $(jq --version 2>/dev/null | sed 's/jq-//' || echo "installed")"
    else
        echo "  ❌ jq: not installed"
    fi
    
    if command_exists bc; then
        echo "  ✅ bc: $(bc --version 2>/dev/null | head -n1 | awk '{print $2}' || echo "installed")"
    else
        echo "  ❌ bc: not installed"
    fi
    echo ""
    echo "Configuration: Command line flags only"
}

# Create default configuration file
create_default_config() {
    local config_file="$1"
    
    if [[ -z "$config_file" ]]; then
        log error "Config file path is required"
        return 1
    fi
    
    # Configuration is handled via command line flags only
    
    if [[ -f "$config_file" ]]; then
        log warning "Configuration file already exists: $config_file"
        log info "Use --init-config with a different filename to create a new config file"
        return 0
    fi
    
    cat > "$config_file" << 'EOF'
# gRPC Testify Configuration File
# This file contains default settings for gRPC Testify

# Test execution settings
parallel_jobs=1
test_timeout=30


# Retry settings
retry_attempts=3
retry_delay=1
no_retry=false

# Output settings
verbose=false
no_color=false

# Plugin settings
plugin_path=./plugins

# Service settings
default_address=localhost:4770
EOF
    
    log success "Configuration file created: $config_file"
    log info "You can edit this file to customize your settings"
}

# Install shell completion
install_completion() {
    local shell_type="${1:-all}"
    
    case "$shell_type" in
        "bash"|"all")
            install_bash_completion
            ;;
        "zsh"|"all")
            install_zsh_completion
            ;;
        *)
            log error "Unsupported shell type: $shell_type"
            log info "Supported shells: bash, zsh, all"
            return 1
            ;;
    esac
}

# Install bash completion
install_bash_completion() {
    local completion_dir="$HOME/.local/share/bash-completion/completions"
    local completion_file="$completion_dir/grpctestify"
    
    ensure_directory "$completion_dir"
    
    cat > "$completion_file" << 'EOF'
# Bash completion for grpctestify
_grpctestify() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    opts="--help --version --update --completion --config --init-config --list-plugins --create-plugin --no-color --verbose --parallel --timeout --retry --retry-delay --no-retry"
    
    case "${prev}" in

        --completion)
            COMPREPLY=( $(compgen -W "bash zsh all" -- ${cur}) )
            return 0
            ;;

    esac
    
    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi
    
    # Complete with .gctf files
    COMPREPLY=( $(compgen -f -X '!*.gctf' -- ${cur}) )
}

complete -F _grpctestify grpctestify
EOF
    
    log success "Bash completion installed for user"
    log info "Add 'source ~/.local/share/bash-completion/completions/grpctestify' to your ~/.bashrc"
}

# Install zsh completion
install_zsh_completion() {
    local completion_dir="$HOME/.local/share/zsh/site-functions"
    local completion_file="$completion_dir/_grpctestify"
    
    ensure_directory "$completion_dir"
    
    cat > "$completion_file" << 'EOF'
#compdef grpctestify

_grpctestify() {
    local context state line
    typeset -A opt_args
    
    _arguments -C \
        '1: :->command' \
        '*::arg:->args' \
        '--help[Show help message]' \
        '--version[Show version information]' \
        '--update[Check for updates]' \
        '--completion[Install shell completion]:shell:(bash zsh all)' \
        '--config[Show current configuration]' \
        '--init-config[Create default configuration file]:config_file:_files' \
        '--list-plugins[List available plugins]' \
        '--create-plugin[Create a new plugin template]:plugin_name:' \
        '--no-color[Disable colored output]' \
        '--verbose[Enable verbose debug output]' \

        '--parallel[Run N tests in parallel]:jobs:' \
        '--timeout[Timeout for individual tests in seconds]:seconds:' \

        '--retry[Number of retries for failed network calls]:attempts:' \
        '--retry-delay[Initial delay between retries in seconds]:delay:' \
        '--no-retry[Disable retry mechanisms for network failures]' \

        '*:test_file:_files -g "*.gctf"'
}

_grpctestify "$@"
EOF
    
    log success "Zsh completion installed to fpath"
    log info "Add '/Users/babichev/.local/share/zsh/site-functions' to your fpath in ~/.zshrc"
}

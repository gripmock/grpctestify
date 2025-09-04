#!/bin/bash

# app.sh - Application initialization
# This file contains the initialize_app function used by the bashly-generated script

# Initialize application
initialize_app() {
	# Load configuration file first (highest priority)
	if declare -f load_configuration >/dev/null 2>&1; then
		load_configuration
	fi

	# Colors are now handled by the colors plugin automatically
	# Dependencies are automatically checked by bashly
	# Don't show initialization message to match original behavior
}

# All other functions have been moved to their respective command files
# - Test execution functions are in src/lib/commands/test.sh
# - Main command logic is handled by bashly-generated root_command()

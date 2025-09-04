#!/bin/bash

# plugin_api.sh - Official Plugin Development API
# Provides standardized interface for developing gRPC Testify plugins
# shellcheck disable=SC2155,SC1083,SC2086,SC2034,SC2317,SC2231 # Variable assignments, brace expansions, unreachable code

# Plugin API version
# PLUGIN_API_VERSION is defined in config.sh

# Plugin development utilities
PLUGIN_DEV_MODE="${GRPCTESTIFY_PLUGIN_DEV:-false}"

# Enhanced plugin registry with modular support
declare -A REGISTERED_PLUGINS
declare -A PLUGIN_DEPENDENCIES
declare -A PLUGIN_LOAD_ORDER

# Register a plugin in the system with dependency support
register_plugin() {
	local plugin_name="$1"
	local plugin_function="$2"
	local description="$3"
	local plugin_type="${4:-internal}"
	local dependencies="${5:-}"

	# Store plugin information
	REGISTERED_PLUGINS["$plugin_name"]="$plugin_function:$description:$plugin_type"
	PLUGIN_DEPENDENCIES["$plugin_name"]="$dependencies"

	# Debug output in dev mode
	if [[ "$PLUGIN_DEV_MODE" == "true" ]]; then
		log_debug "Registered plugin: $plugin_name -> $plugin_function ($plugin_type)"
		if [[ -n "$dependencies" ]]; then
			log_debug "  Dependencies: $dependencies"
		fi
	fi
}

#######################################
# Auto-load execution plugins in correct order
# Loads specialized execution plugins:
# - grpc_client.sh
# - failure_reporter.sh
# - json_comparator.sh
# - test_orchestrator.sh
#######################################
auto_load_execution_plugins() {
	local execution_plugins=(
		"grpc_client:gRPC client functionality:execution"
		"failure_reporter:Test failure reporting:execution"
		"json_comparator:JSON comparison utilities:execution"
		"test_orchestrator:Test orchestration:execution:grpc_client,failure_reporter,json_comparator"
	)

	log_debug "Auto-loading execution plugins..."

	for plugin_info in "${execution_plugins[@]}"; do
		IFS=':' read -r name desc type deps <<<"$plugin_info"

		# Register plugin with dependencies
		register_plugin "$name" "auto_loaded" "$desc" "$type" "$deps"

		# The actual loading is handled by bashly plugin system
		log_debug "  Registered: $name (deps: ${deps:-none})"
	done

	log_debug "Execution plugins auto-loading completed"
}

# Plugin template generation
create_plugin_template() {
	local plugin_name="$1"
	local plugin_type="${2:-assertion}" # assertion, validation, utility
	local output_dir="${3:-plugins}"

	# Load configuration if not already loaded
	if [[ -z "${PLUGIN_API_VERSION:-}" ]]; then
		if [[ -f "${BASH_SOURCE[0]%/*}/../../kernel/config.sh" ]]; then
			source "${BASH_SOURCE[0]%/*}/../../kernel/config.sh"
		fi
	fi

	if [[ -z "$plugin_name" ]]; then
		log_error "Plugin name is required"
		return 1
	fi

	# Validate plugin name
	if [[ ! "$plugin_name" =~ ^[a-z][a-z0-9_]*$ ]]; then
		log_error "Plugin name must start with lowercase letter and contain only lowercase letters, numbers, and underscores"
		return 1
	fi

	local plugin_file="${output_dir}/grpc_${plugin_name}.sh"
	local test_file="${output_dir}/grpc_${plugin_name}.bats"
	local docs_file="${output_dir}/grpc_${plugin_name}.md"

	# Create output directory
	mkdir -p "$output_dir"

	log_debug "Creating plugin template: $plugin_name"

	# Generate main plugin file
	generate_plugin_source "$plugin_name" "$plugin_type" >"$plugin_file"

	# Generate test file
	generate_plugin_tests "$plugin_name" "$plugin_type" >"$test_file"

	# Generate documentation
	generate_plugin_docs "$plugin_name" "$plugin_type" >"$docs_file"

	# Make plugin executable
	chmod +x "$plugin_file"
	chmod +x "$test_file"

	log_debug "Plugin template created successfully:"
	log_debug "  Source: $plugin_file"
	log_debug "  Tests:  $test_file"
	log_debug "  Docs:   $docs_file"

	log_debug ""
	log_debug "Next steps:"
	log_debug "1. Edit $plugin_file to implement your plugin logic"
	log_debug "2. Update tests in $test_file"
	log_debug "3. Run tests: bats $test_file"
	log_debug "4. Update documentation in $docs_file"
	log_debug "5. Register plugin in plugin_system_enhanced.sh"
}

# Generate plugin source template
generate_plugin_source() {
	local plugin_name="$1"
	local plugin_type="$2"

	cat <<EOF
#!/bin/bash

# grpc_${plugin_name}.sh - ${plugin_name^} plugin for gRPC Testify
# Plugin Type: $plugin_type
# API Version: $PLUGIN_API_VERSION

# Plugin metadata
PLUGIN_${plugin_name^^}_VERSION="$CONFIG_VERSION"
PLUGIN_${plugin_name^^}_DESCRIPTION="Description of ${plugin_name} plugin"
PLUGIN_${plugin_name^^}_AUTHOR="Your Name <info@example.com>"

# Plugin configuration (using centralized config)
declare -A PLUGIN_${plugin_name^^}_CONFIG=(
    ["timeout"]="\$PLUGIN_TIMEOUT"
    ["strict_mode"]="\$PLUGIN_STRICT_MODE"
    ["debug"]="\$PLUGIN_DEBUG"
    ["max_retries"]="\$PLUGIN_MAX_RETRIES"
)

# Main plugin assertion function
assert_${plugin_name}() {
    local response="\$1"
    local parameter="\$2"
    local expected_value="\$3"
    local operation_type="\${4:-equals}"
    
    # Validate inputs
    if [[ -z "\$response" ]]; then
    log_error "${plugin_name^} plugin: Empty response"
        return 1
    fi
    
    if [[ -z "\$parameter" ]]; then
    log_error "${plugin_name^} plugin: Parameter is required"
        return 1
    fi
    
    # Validate parameter name (security check)
    if [[ ! "\$parameter" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    log_error "${plugin_name^} plugin: Invalid parameter name '\$parameter'"
        return 1
    fi
    
    # Validate response is valid JSON (basic check)
    if [[ "\$response" != "{}" ]] && ! echo "\$response" | jq empty >/dev/null 2>&1; then
    log_error "${plugin_name^} plugin: Invalid JSON response"
        return 1
    fi
    
    # Debug logging
    if [[ "\${PLUGIN_${plugin_name^^}_CONFIG[debug]}" == "true" ]]; then
    log_debug "${plugin_name^} plugin: Processing parameter '\$parameter'"
    log_debug "${plugin_name^} plugin: Expected value '\$expected_value'"
    log_debug "${plugin_name^} plugin: Operation type '\$operation_type'"
    fi
    
    # Extract value from response
    local actual_value
    case "\$operation_type" in
        "equals"|"legacy")
            actual_value=\$(extract_${plugin_name}_value "\$response" "\$parameter")
            ;;
        "test")
            actual_value=\$(extract_${plugin_name}_value "\$response" "\$parameter")
            ;;
        *)
    log_error "${plugin_name^} plugin: Unknown operation type '\$operation_type'"
            return 1
            ;;
    esac
    
    if [[ -z "\$actual_value" ]]; then
    log_error "${plugin_name^} plugin: Could not extract value for parameter '\$parameter'"
        return 1
    fi
    
    # Perform assertion based on operation type
    case "\$operation_type" in
        "equals"|"legacy")
            if [[ "\$actual_value" == "\$expected_value" ]]; then
    log_debug "${plugin_name^} assertion passed: '\$parameter' == '\$expected_value'"
                return 0
            else
    log_error "${plugin_name^} assertion failed: '\$parameter' expected '\$expected_value', got '\$actual_value'"
                return 1
            fi
            ;;
        "test")
            if echo "\$actual_value" | grep -qE "\$expected_value"; then
    log_debug "${plugin_name^} test assertion passed: '\$parameter' matches pattern '\$expected_value'"
                return 0
            else
    log_error "${plugin_name^} test assertion failed: '\$parameter' value '\$actual_value' does not match pattern '\$expected_value'"
                return 1
            fi
            ;;
    esac
}

# Value extraction function (customize based on your plugin's needs)
extract_${plugin_name}_value() {
    local response="\$1"
    local parameter="\$2"
    
    # Generic value extraction - customize based on your plugin's needs
    # Common patterns:
    # - Headers: echo "\$response" | jq -r ".headers[\"\$parameter\"] // empty"
    # - Fields: echo "\$response" | jq -r ".\$parameter // empty"  
    # - Nested: echo "\$response" | jq -r ".data.\$parameter // empty"
    
    # Default implementation extracts field directly
    echo "\$response" | jq -r ".\$parameter // empty" 2>/dev/null || echo ""
}

# Test function for @${plugin_name}(...) | test(...) syntax
test_${plugin_name}() {
    local response="\$1"
    local parameter="\$2"
    local pattern="\$3"
    
    assert_${plugin_name} "\$response" "\$parameter" "\$pattern" "test"
}

# Plugin configuration functions
set_${plugin_name}_config() {
    local key="\$1"
    local value="\$2"
    
    if [[ -z "\$key" ]]; then
    log_error "${plugin_name^} plugin: Configuration key is required"
        return 1
    fi
    
    PLUGIN_${plugin_name^^}_CONFIG["\$key"]="\$value"
    log_debug "${plugin_name^} plugin: Configuration '\$key' set to '\$value'"
}

get_${plugin_name}_config() {
    local key="\$1"
    
    if [[ -z "\$key" ]]; then
    log_error "${plugin_name^} plugin: Configuration key is required"
        return 1
    fi
    
    echo "\${PLUGIN_${plugin_name^^}_CONFIG[\$key]}"
}

# Plugin validation function
validate_${plugin_name}_plugin() {
    local issues=()
    
    # Check required functions
    if ! declare -f extract_${plugin_name}_value >/dev/null; then
        issues+=("Missing extract_${plugin_name}_value function")
    fi
    
    if ! declare -f assert_${plugin_name} >/dev/null; then
        issues+=("Missing assert_${plugin_name} function")
    fi
    
    # Check configuration
    if [[ -z "\${PLUGIN_${plugin_name^^}_VERSION}" ]]; then
        issues+=("Missing plugin version")
    fi
    
    if [[ -z "\${PLUGIN_${plugin_name^^}_DESCRIPTION}" ]]; then
        issues+=("Missing plugin description")
    fi
    
    # Report issues
    if [[ \${#issues[@]} -gt 0 ]]; then
    log_error "${plugin_name^} plugin validation failed:"
        for issue in "\${issues[@]}"; do
    log_error "  - \$issue"
        done
        return 1
    fi
    
    log_debug "${plugin_name^} plugin validation passed"
    return 0
}

# Plugin registration function
register_${plugin_name}_plugin() {
    # Validate plugin before registration
    if ! validate_${plugin_name}_plugin; then
    log_error "Cannot register ${plugin_name} plugin: validation failed"
        return 1
    fi
    
    # Register with plugin system
    register_plugin "${plugin_name}" "assert_${plugin_name}" "\${PLUGIN_${plugin_name^^}_DESCRIPTION}" "external"
    
    log_debug "${plugin_name^} plugin registered successfully (version \${PLUGIN_${plugin_name^^}_VERSION})"
}

# Plugin help function
show_${plugin_name}_help() {
    cat << 'HELP_EOF'
${plugin_name^} Plugin Help
=======================

Usage in test files:
  @${plugin_name}("parameter") == "expected_value"
  @${plugin_name}("parameter") | test("regex_pattern")

Configuration:
  Set configuration: set_${plugin_name}_config "key" "value"
  Get configuration: get_${plugin_name}_config "key"

Available configuration options:
$(for key in \${!PLUGIN_${plugin_name^^}_CONFIG[@]}; do
		printf "  %-20s %s\n" "\$key:" "\${PLUGIN_${plugin_name^^}_CONFIG[\$key]}"
	done)

Examples:
  # Basic assertion
  @${plugin_name}("field") == "expected"
  
  # Pattern matching
  @${plugin_name}("field") | test("^[0-9]+\$")
  
  # Combined with jq
  @${plugin_name}("field") == "value" and .other_field == "test"

For more information, see the plugin documentation.
HELP_EOF
}

# Export plugin functions
export -f assert_${plugin_name}
export -f test_${plugin_name}
export -f extract_${plugin_name}_value
export -f set_${plugin_name}_config
export -f get_${plugin_name}_config
export -f validate_${plugin_name}_plugin
export -f register_${plugin_name}_plugin
export -f show_${plugin_name}_help
EOF
}

# Generate plugin test template
generate_plugin_tests() {
	local plugin_name="$1"
	local plugin_type="$2"

	cat <<EOF
#!/usr/bin/env bats

# grpc_${plugin_name}.bats - Tests for ${plugin_name} plugin

# Load the plugin
load './grpc_${plugin_name}.sh'
load '../ui/colors.sh'

setup() {
    # Initialize colors for testing
    # Colors are now handled by the colors plugin
}

@test "${plugin_name} plugin loads without errors" {
    # Test plugin loading
    run validate_${plugin_name}_plugin
    [ \$status -eq 0 ]
}

@test "${plugin_name} plugin has required metadata" {
    # Test version
    [ -n "\${PLUGIN_${plugin_name^^}_VERSION}" ]
    
    # Test description
    [ -n "\${PLUGIN_${plugin_name^^}_DESCRIPTION}" ]
    
    # Test author
    [ -n "\${PLUGIN_${plugin_name^^}_AUTHOR}" ]
}

@test "${plugin_name} plugin configuration works" {
    # Set configuration
    run set_${plugin_name}_config "test_key" "test_value"
    [ \$status -eq 0 ]
    
    # Get configuration
    run get_${plugin_name}_config "test_key"
    [ \$status -eq 0 ]
    [ "\$output" = "test_value" ]
}

@test "${plugin_name} plugin validation catches errors" {
    # Add specific validation tests based on plugin requirements
    # run assert_${plugin_name} "" "parameter" "expected"
    # [ \$status -ne 0 ]
    
    # Plugin-specific validation tests not implemented yet
}

@test "${plugin_name} plugin assertion works with valid input" {
    # Add positive test cases for plugin functionality
    # local test_response='{"field": "value"}'
    # run assert_${plugin_name} "\$test_response" "field" "value"
    # [ \$status -eq 0 ]
    
    # Positive test cases not implemented yet
}

@test "${plugin_name} plugin assertion fails with invalid input" {
    # Add negative test cases for error handling
    # local test_response='{"field": "wrong_value"}'
    # run assert_${plugin_name} "\$test_response" "field" "expected_value"
    # [ \$status -ne 0 ]
    
    # Negative test cases not implemented yet
}

@test "${plugin_name} plugin supports pattern testing" {
    # Add pattern testing for regex functionality
    # local test_response='{"field": "test123"}'
    # run test_${plugin_name} "\$test_response" "field" "^test[0-9]+\$"
    # [ \$status -eq 0 ]
    
    # Pattern testing not implemented yet
}

@test "${plugin_name} plugin handles edge cases" {
    # Test empty response
    run assert_${plugin_name} "" "field" "value"
    [ \$status -ne 0 ]
    
    # Test missing parameter
    run assert_${plugin_name} '{"field": "value"}' "" "value"
    [ \$status -ne 0 ]
    
    # Test missing field
    run assert_${plugin_name} '{"other": "value"}' "field" "value"
    [ \$status -ne 0 ]
}

@test "${plugin_name} plugin registration works" {
    # Test plugin registration
    run register_${plugin_name}_plugin
    [ \$status -eq 0 ]
}

@test "${plugin_name} plugin help is available" {
    # Test help function
    run show_${plugin_name}_help
    [ \$status -eq 0 ]
    [[ "\$output" =~ "${plugin_name^} Plugin Help" ]]
}

# Add more specific tests based on your plugin's functionality
# Examples:
# - Test different data types
# - Test complex JSON structures
# - Test error conditions
# - Test performance with large responses
# - Test integration with other plugins
EOF
}

# Generate plugin documentation template
generate_plugin_docs() {
	local plugin_name="$1"
	local plugin_type="$2"

	cat <<EOF
# ${plugin_name^} Plugin

Plugin for gRPC Testify that provides ${plugin_name} validation functionality.

## Overview

**Type**: $plugin_type  
**API Version**: $PLUGIN_API_VERSION  
**Status**: Development  

Custom plugin template generated by grpctestify.

## Usage

### Basic Syntax

\`\`\`php
--- ASSERTS ---
@${plugin_name}("parameter") == "expected_value"
@${plugin_name}("parameter") | test("regex_pattern")
\`\`\`

### Examples

\`\`\`php
# Basic assertion
@${plugin_name}("field") == "expected"

# Pattern matching
@${plugin_name}("field") | test("^[0-9]+\$")

# Combined with jq
@${plugin_name}("field") == "value" and .other_field == "test"
\`\`\`

## Configuration

The plugin supports the following configuration options:

| Option | Default | Description |
|--------|---------|-------------|
| \`timeout\` | \`30\` | Plugin operation timeout in seconds |
| \`strict_mode\` | \`false\` | Enable strict validation mode |
| \`debug\` | \`false\` | Enable debug logging |

### Setting Configuration

\`\`\`bash
# Set configuration
set_${plugin_name}_config "timeout" "60"
set_${plugin_name}_config "strict_mode" "true"

# Get configuration
timeout=\$(get_${plugin_name}_config "timeout")
\`\`\`

## API Reference

### Functions

#### \`assert_${plugin_name}(response, parameter, expected_value, operation_type)\`

Main assertion function for the plugin.

**Parameters:**
- \`response\` - gRPC response JSON
- \`parameter\` - Parameter to extract/validate
- \`expected_value\` - Expected value or pattern
- \`operation_type\` - Type of operation (equals, test)

**Returns:**
- \`0\` - Assertion passed
- \`1\` - Assertion failed

#### \`test_${plugin_name}(response, parameter, pattern)\`

Pattern testing function for regex validation.

#### \`extract_${plugin_name}_value(response, parameter)\`

Extracts value from response for the given parameter.

### Configuration Functions

#### \`set_${plugin_name}_config(key, value)\`

Sets plugin configuration.

#### \`get_${plugin_name}_config(key)\`

Gets plugin configuration value.

## Implementation Details

Implementation details to document:
- How the plugin extracts values from responses
- What data formats are supported
- Error handling approach and recovery strategies
- Performance considerations and optimizations

## Testing

Run the plugin tests:

\`\`\`bash
bats grpc_${plugin_name}.bats
\`\`\`

## Development

Development guidelines:
- How to extend the plugin functionality
- Adding new features and capabilities
- Contributing guidelines and best practices

## Examples

### Real-World Usage

Examples showing the plugin in production scenarios:
- Integration with CI/CD pipelines
- Complex assertion patterns
- Performance optimization techniques

## Troubleshooting

### Common Issues

Common issues and their solutions:
- Configuration problems and fixes
- Performance issues and optimization
- Integration challenges and workarounds

### Debug Mode

Enable debug mode for detailed logging:

\`\`\`bash
set_${plugin_name}_config "debug" "true"
\`\`\`

## Changelog

### Version 1.0.0
- Initial plugin template

## License

This plugin is part of gRPC Testify and follows the same license terms.
EOF
}

# Plugin validation API
validate_plugin_api() {
	local plugin_file="$1"

	if [[ ! -f "$plugin_file" ]]; then
		log_error "Plugin file not found: $plugin_file"
		return 1
	fi

	local plugin_name
	plugin_name=$(basename "$plugin_file" .sh | sed 's/^grpc_//')

	log_debug "Validating plugin: $plugin_name"

	# Source the plugin
	if ! source "$plugin_file"; then
		log_error "Failed to source plugin file: $plugin_file"
		return 1
	fi

	# Check required functions
	local required_functions=(
		"assert_${plugin_name}"
		"register_${plugin_name}_plugin"
	)

	local validation_errors=()

	for func in "${required_functions[@]}"; do
		if ! declare -f "$func" >/dev/null; then
			validation_errors+=("Missing required function: $func")
		fi
	done

	# Check metadata variables
	local version_var="PLUGIN_${plugin_name^^}_VERSION"
	local desc_var="PLUGIN_${plugin_name^^}_DESCRIPTION"

	if [[ -z "${!version_var}" ]]; then
		validation_errors+=("Missing version variable: $version_var")
	fi

	if [[ -z "${!desc_var}" ]]; then
		validation_errors+=("Missing description variable: $desc_var")
	fi

	# Report validation results
	if [[ ${#validation_errors[@]} -gt 0 ]]; then
		log_error "Plugin validation failed:"
		for error in "${validation_errors[@]}"; do
			log_error "  - $error"
		done
		return 1
	fi

	log_debug "Plugin validation passed: $plugin_name"
	return 0
}

# Plugin testing API
test_plugin_api() {
	local plugin_file="$1"

	if [[ ! -f "$plugin_file" ]]; then
		log_error "Plugin file not found: $plugin_file"
		return 1
	fi

	local test_file="${plugin_file%.sh}.bats"

	if [[ ! -f "$test_file" ]]; then
		log_warn "No test file found: $test_file"
		return 1
	fi

	log_debug "Running plugin tests: $test_file"

	if command -v bats >/dev/null 2>&1; then
		bats "$test_file"
	else
		log_error "bats not found. Install bats to run plugin tests."
		return 1
	fi
}

# Plugin installation API
install_plugin_api() {
	local plugin_file="$1"
	local install_dir="${2:-~/.grpctestify/plugins}"

	if [[ ! -f "$plugin_file" ]]; then
		log_error "Plugin file not found: $plugin_file"
		return 1
	fi

	# Validate plugin first
	if ! validate_plugin_api "$plugin_file"; then
		log_error "Plugin validation failed. Cannot install."
		return 1
	fi

	# Copy to installation directory
	local plugin_name
	plugin_name=$(basename "$plugin_file")
	local dest_file="$install_dir/$plugin_name"

	mkdir -p "$install_dir"

	if cp "$plugin_file" "$dest_file"; then
		chmod +x "$dest_file"
		log_debug "Plugin installed: $dest_file"
	else
		log_error "Failed to install plugin: $plugin_file"
		return 1
	fi

	# Copy tests if they exist
	local test_file="${plugin_file%.sh}.bats"
	if [[ -f "$test_file" ]]; then
		local dest_test="$install_dir/$(basename "$test_file")"
		if cp "$test_file" "$dest_test"; then
			chmod +x "$dest_test"
			log_debug "Plugin tests installed: $dest_test"
		fi
	fi

	return 0
}

# Plugin development help
show_plugin_api_help() {
	cat <<'EOF'
gRPC Testify Plugin Development API
==================================

COMMANDS:
  create-plugin <name> [type] [dir]  Create new plugin template
  validate-plugin <file>             Validate plugin compliance
  test-plugin <file>                 Run plugin tests
  install-plugin <file> [dir]        Install plugin to system
  
PLUGIN TYPES:
  assertion    - Custom assertion plugins (default)
  validation   - Type validation plugins  
  utility      - Utility and helper plugins

EXAMPLES:
  # Create a new assertion plugin
  create_plugin_template "custom_auth" "assertion" "my_plugins"
  
  # Validate plugin compliance
  validate_plugin_api "my_plugins/grpc_custom_auth.sh"
  
  # Run plugin tests
  test_plugin_api "my_plugins/grpc_custom_auth.sh"
  
  # Install plugin
  install_plugin_api "my_plugins/grpc_custom_auth.sh"

PLUGIN STRUCTURE:
  grpc_plugin_name.sh     - Main plugin source
  grpc_plugin_name.bats   - Plugin tests
  grpc_plugin_name.md     - Plugin documentation

REQUIRED FUNCTIONS:
  assert_<name>()           - Main assertion function
  register_<name>_plugin()  - Plugin registration
  validate_<name>_plugin()  - Plugin validation

OPTIONAL FUNCTIONS:
  test_<name>()            - Pattern testing function
  extract_<name>_value()   - Value extraction
  set_<name>_config()      - Configuration setter
  get_<name>_config()      - Configuration getter

METADATA VARIABLES:
  PLUGIN_<NAME>_VERSION     - Plugin version
  PLUGIN_<NAME>_DESCRIPTION - Plugin description
  PLUGIN_<NAME>_AUTHOR      - Plugin author

For detailed documentation, see: docs/api-reference/plugin-development.md
EOF
}

# Export API functions
export -f create_plugin_template
export -f generate_plugin_source
export -f generate_plugin_tests
export -f generate_plugin_docs
export -f validate_plugin_api
export -f test_plugin_api
export -f install_plugin_api
export -f show_plugin_api_help

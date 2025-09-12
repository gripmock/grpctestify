# Plugin Development Guide

Learn how to create powerful plugins for gRPC Testify. This comprehensive guide covers everything from basic plugin structure to advanced state management.

## 🎯 Quick Start

### 1. Generate Plugin Template
```bash
# Create a new plugin
grpctestify --create-plugin my_awesome_plugin

# Generated files:
# - grpc_my_awesome_plugin.sh    (main plugin code)
# - grpc_my_awesome_plugin.bats  (test suite)
# - grpc_my_awesome_plugin.md    (documentation)
```

### 2. Basic Plugin Structure
```bash
#!/bin/bash
# grpc_my_awesome_plugin.sh

# Plugin metadata
PLUGIN_MY_AWESOME_PLUGIN_VERSION="1.0.0"
PLUGIN_MY_AWESOME_PLUGIN_DESCRIPTION="Description of what the plugin does"
PLUGIN_MY_AWESOME_PLUGIN_AUTHOR="Your Name <info@example.com>"

# Main plugin function
assert_my_awesome_condition() {
    local expected="$1"
    local actual="$2"
    
    # Plugin logic here
    if [[ "$actual" == "$expected" ]]; then
        return 0  # Success
    else
        return 1  # Failure
    fi
}

# Plugin registration (required)
register_my_awesome_plugin() {
    log debug "My Awesome Plugin v$PLUGIN_MY_AWESOME_PLUGIN_VERSION loaded"
}

# Export functions
export -f assert_my_awesome_condition register_my_awesome_plugin
```

### 3. Test Your Plugin
```bash
# Validate plugin structure
grpctestify --validate-plugin grpc_my_awesome_plugin.sh

# Run plugin tests
grpctestify --test-plugin grpc_my_awesome_plugin.sh

# Install locally for testing
grpctestify --install-plugin grpc_my_awesome_plugin.sh
```

## 📚 Development Guides

### Core Concepts
- **[State API](state-api.md)** - Centralized test state management

## 🛠️ Plugin Types

### Assertion Plugins
Create custom test assertions:
```bash
assert_custom_header() {
    local header_name="$1"
    local expected_value="$2"
    local actual_response="$3"
    
    local actual_value
    actual_value=$(echo "$actual_response" | jq -r ".headers[\"$header_name\"]")
    
    if [[ "$actual_value" == "$expected_value" ]]; then
        plugin_io_test_success "Header $header_name matches expected value"
        return 0
    else
        plugin_io_test_failure "Header $header_name: expected '$expected_value', got '$actual_value'"
        return 1
    fi
}
```

### Validation Plugins
Add data validation capabilities:
```bash
validate_email_format() {
    local email="$1"
    local email_regex="^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"
    
    if [[ "$email" =~ $email_regex ]]; then
        return 0
    else
        plugin_io_error "Invalid email format: $email"
        return 1
    fi
}
```

### Report Plugins
Create custom report formats:
```bash
generate_custom_report() {
    local output_file="$1"
    
    # Get test data from state
    local total_tests=$(test_state_get "total_tests")
    local passed_tests=$(test_state_get "passed_tests")
    local failed_tests=$(test_state_get "failed_tests")
    
    # Generate custom report
    cat > "$output_file" << EOF
Custom Test Report
==================
Total Tests: $total_tests
Passed: $passed_tests
Failed: $failed_tests
Success Rate: $(test_state_get_success_rate)%
EOF
}
```

## 🔗 Integration with Test State

### Reading Test Data
```bash
# Get execution metrics
total_tests=$(test_state_get "total_tests")
success_rate=$(test_state_get_success_rate)
duration=$(test_state_get_duration)

# Get all test results
readarray -t all_results < <(test_state_get_all_results)

# Get failed tests only
readarray -t failed_tests < <(test_state_get_failed_results)
```

### Writing Plugin Data
```bash
# Store global plugin metadata
test_state_set_plugin_metadata "my_plugin" "initialization_time" "$(date +%s%3N)"
test_state_set_plugin_metadata "my_plugin" "config_version" "2.1.0"

# Store per-test metadata
test_state_set_test_metadata "$test_path" "my_plugin" "processing_time" "45ms"
test_state_set_test_metadata "$test_path" "my_plugin" "complexity_score" "7.2"
```

## 🔌 Plugin Lifecycle

### Registration Phase
```bash
register_my_plugin() {
    # Plugin initialization
    test_state_set_plugin_metadata "my_plugin" "loaded_at" "$(date -Iseconds)"
    log debug "My Plugin loaded successfully"
}
```

### Execution Phase
```bash
# Plugins are called during test execution
# Use appropriate hooks and APIs
```

### Cleanup Phase
```bash
cleanup_my_plugin() {
    # Cleanup resources if needed
    test_state_set_plugin_metadata "my_plugin" "cleanup_completed" "true"
}

# Register cleanup function
trap cleanup_my_plugin EXIT
```

## 🎨 Best Practices

### 1. Naming Conventions
```bash
# Plugin file: grpc_my_plugin_name.sh
# Functions: my_plugin_function_name()
# Variables: MY_PLUGIN_VARIABLE_NAME
# Metadata keys: my_plugin_namespace
```

### 2. Error Handling
```bash
my_plugin_function() {
    local param="$1"
    
    # Validate parameters
    if [[ -z "$param" ]]; then
        plugin_io_error "Parameter required for my_plugin_function"
        return 1
    fi
    
    # Handle errors gracefully
    if ! some_operation "$param"; then
        plugin_io_error "Operation failed: $param"
        return 1
    fi
    
    return 0
}
```

### 3. Resource Management
```bash
my_plugin_with_resources() {
    local temp_file
    temp_file=$(mktemp)
    
    # Ensure cleanup
    trap "rm -f '$temp_file'" RETURN
    
    # Use resources
    process_data > "$temp_file"
    
    # Cleanup happens automatically
}
```

### 4. State Management
```bash
# Use consistent metadata namespacing
PLUGIN_NAMESPACE="my_awesome_plugin"

store_plugin_data() {
    local key="$1"
    local value="$2"
    
    test_state_set_plugin_metadata "$PLUGIN_NAMESPACE" "$key" "$value"
}

get_plugin_data() {
    local key="$1"
    
    test_state_get_plugin_metadata "$PLUGIN_NAMESPACE" "$key"
}
```

## 🧪 Testing Your Plugin

### Unit Tests with Bats
```bash
#!/usr/bin/env bats
# grpc_my_plugin.bats

setup() {
    # Load plugin
    source grpc_my_plugin.sh
}

@test "plugin function works correctly" {
    run my_plugin_function "test_input"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "expected_output" ]]
}

@test "plugin handles invalid input" {
    run my_plugin_function ""
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Parameter required" ]]
}
```

### Integration Tests
```bash
# Create test .gctf file that uses your plugin
cat > test_my_plugin.gctf << 'EOF'
--- ADDRESS ---
localhost:50051

--- ENDPOINT ---
test.Service/TestMethod

--- REQUEST ---
{"test": "data"}

--- RESPONSE ---
{"result": "success"}

--- ASSERTS ---
assert_my_plugin_condition "expected_value"
EOF

# Run test with plugin
grpctestify test_my_plugin.gctf
```

## 📦 Distribution

### Plugin Package Structure
```
my-awesome-plugin/
├── grpc_my_awesome_plugin.sh      # Main plugin
├── grpc_my_awesome_plugin.bats    # Tests
├── grpc_my_awesome_plugin.md      # Documentation
├── README.md                      # Installation guide
├── LICENSE                        # License file
└── examples/                      # Usage examples
    ├── basic_usage.gctf
    └── advanced_usage.gctf
```

### Installation Script
```bash
#!/bin/bash
# install.sh

set -euo pipefail

PLUGIN_NAME="grpc_my_awesome_plugin"
INSTALL_DIR="${GRPCTESTIFY_PLUGIN_DIR:-$HOME/.grpctestify/plugins}"

# Create plugin directory
mkdir -p "$INSTALL_DIR"

# Copy plugin files
cp "$PLUGIN_NAME.sh" "$INSTALL_DIR/"
cp "$PLUGIN_NAME.md" "$INSTALL_DIR/"

# Make executable
chmod +x "$INSTALL_DIR/$PLUGIN_NAME.sh"

echo "Plugin $PLUGIN_NAME installed successfully!"
echo "Location: $INSTALL_DIR/$PLUGIN_NAME.sh"
```

## 🔗 Next Steps

1. **[Explore State Management](state-api.md)** - Understand test state
2. **[Study Plugin Development](state-api.md)** - Learn the interfaces

Ready to build? Check out our [Plugin Examples](../../guides/examples/basic/real-time-chat) for inspiration!



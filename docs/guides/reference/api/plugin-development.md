# Plugin Development

gRPC Testify supports an extensible plugin system that allows you to create custom assertions and validation logic. The system supports both embedded internal plugins and external plugins loaded from directory.

## Plugin Architecture

The enhanced plugin system provides:

- **Internal Plugins**: Embedded in the main script for core functionality
- **External Plugins**: Loaded from `~/.grpctestify/plugins/` directory
- **Plugin IO API**: Controlled interface for IO operations and synchronization
- **Unified API**: Common interface for all plugin types
- **Registration System**: Dynamic plugin discovery and loading

## Plugin IO API

**Important**: All plugin output and IO operations must use the Plugin IO API to ensure proper synchronization in parallel execution.

### Basic IO Functions
```bash
# Progress reporting
plugin_io_progress "test_name" "running" "."
plugin_io_progress "test_name" "passed" "."
plugin_io_progress "test_name" "failed" "F"

# Result reporting
plugin_io_result "test_name" "PASSED" "250" "optional details"
plugin_io_result "test_name" "FAILED" "300" "error details"

# Error reporting
plugin_io_error "test_name" "Error description"

# Safe output (mutex-protected)
plugin_io_print "Message: %s\n" "value"
plugin_io_error_print "Error message"
plugin_io_newline
```

### Convenience Functions
```bash
# Complete test lifecycle management
plugin_io_test_start "test_name"
plugin_io_test_success "test_name" "250" "Test passed successfully"
plugin_io_test_failure "test_name" "300" "Validation failed"
plugin_io_test_error "test_name" "100" "Connection timeout"
plugin_io_test_skip "test_name" "Prerequisites not met"
```

### Validation Helpers
```bash
# Validate inputs before using API
plugin_io_validate_test_name "test_name"
plugin_io_validate_status "PASSED" "result"
plugin_io_validate_status "running" "progress"

# Check API availability
if plugin_io_available; then
    plugin_io_test_success "$test_name" "$duration" "$details"
else
    # Fallback behavior
    echo "Test passed: $test_name"
fi
```

## Plugin Types

### Internal Plugins

Built-in plugins that are always available:

- `asserts` - Enhanced assertions with indexed support
- `proto` - Protocol buffer validation
- `tls` - TLS/SSL certificate validation  
- `headers_trailers` - gRPC headers and trailers validation
- `response_time` - Performance assertions
- `type_validation` - Advanced type checking

### External Plugins

Custom plugins loaded from external files for specialized use cases.

## Creating a Plugin

### 1. Plugin File Structure

Create a `.sh` file in `~/.grpctestify/plugins/`:

```bash
#!/bin/bash

# grpc_custom_auth.sh - Custom authentication plugin

# Register the plugin
register_custom_auth_plugin() {
    register_plugin "custom_auth" "assert_custom_auth" "Custom authentication validation" "external"
}

# Main assertion function
assert_custom_auth() {
    local response="$1"
    local header_name="$2"
    local expected_value="$3"
    local operation_type="$4"
    
    # Extract token from response
    local token
    token=$(echo "$response" | jq -r ".auth.token // empty")
    
    if [[ -z "$token" ]]; then
        return 1
    fi
    
    case "$operation_type" in
        "equals")
            [[ "$token" == "$expected_value" ]]
            ;;
        "test")
            echo "$token" | grep -qE "$expected_value"
            ;;
        *)
            return 1
            ;;
    esac
}

# Auto-register when sourced
register_custom_auth_plugin
```

### 2. Plugin Registration

Every plugin must register itself using the `register_plugin` function:

```bash
register_plugin "plugin_name" "assertion_function" "description" "type"
```

**Parameters:**
- `plugin_name` - Unique identifier for the plugin
- `assertion_function` - Function that performs the assertion
- `description` - Human-readable description
- `type` - Either "internal" or "external"

### 3. Assertion Function

The main assertion function must follow this signature:

```bash
assert_plugin_name() {
    local response="$1"        # gRPC response as JSON
    local parameter="$2"       # Parameter from test assertion
    local expected_value="$3"  # Expected value or pattern
    local operation_type="$4"  # "equals" or "test"
    
    # Your validation logic here
    # Return 0 for success, 1 for failure
}
```

### 4. Using Plugins in Tests

```
--- ASSERTS ---
@custom_auth("token") == "valid-jwt-token"
@custom_auth("token") | test("^eyJ[A-Za-z0-9-_]*")
```

## Plugin Function Reference

### Core Functions

#### `register_plugin(name, function, description, type)`

Registers a plugin with the system.

```bash
register_plugin "jwt" "assert_jwt_token" "JWT token validation" "external"
```

#### `execute_plugin_assertion(plugin, response, param, expected, operation)`

Executes a plugin assertion (used internally).

### Helper Functions

#### `extract_from_response(response, path)`

Extract data from JSON response using jq path.

```bash
local value
value=$(extract_from_response "$response" ".user.email")
```

#### `validate_pattern(value, pattern)`

Validate value against regex pattern.

```bash
if validate_pattern "$email" "^[^@]+@[^@]+\.[^@]+$"; then
    echo "Valid email"
fi
```

## Built-in Plugin Examples

### JWT Authentication Plugin

```bash
#!/bin/bash

register_jwt_plugin() {
    register_plugin "jwt" "assert_jwt_token" "JWT token validation" "external"
}

assert_jwt_token() {
    local response="$1"
    local parameter="$2"
    local expected_value="$3"
    local operation_type="$4"
    
    local token
    case "$parameter" in
        "authorization")
            token=$(echo "$response" | jq -r '.headers["authorization"] // empty' | sed 's/Bearer //')
            ;;
        "access_token")
            token=$(echo "$response" | jq -r '.auth.access_token // empty')
            ;;
        *)
            return 1
            ;;
    esac
    
    if [[ -z "$token" ]]; then
        return 1
    fi
    
    case "$operation_type" in
        "equals")
            [[ "$token" == "$expected_value" ]]
            ;;
        "test")
            echo "$token" | grep -qE "$expected_value"
            ;;
        *)
            return 1
            ;;
    esac
}

register_jwt_plugin
```

**Usage:**
```
--- ASSERTS ---
@jwt("authorization") | test("^eyJ")
@jwt("access_token") == "expected-jwt-token"
```

### Rate Limiting Plugin

```bash
#!/bin/bash

register_rate_limit_plugin() {
    register_plugin "rate_limit" "assert_rate_limit" "Rate limiting validation" "external"
}

assert_rate_limit() {
    local response="$1"
    local parameter="$2"
    local expected_value="$3"
    local operation_type="$4"
    
    local header_value
    header_value=$(echo "$response" | jq -r ".headers[\"x-rate-limit-$parameter\"] // empty")
    
    if [[ -z "$header_value" ]]; then
        return 1
    fi
    
    case "$operation_type" in
        "equals")
            [[ "$header_value" == "$expected_value" ]]
            ;;
        "test")
            echo "$header_value" | grep -qE "$expected_value"
            ;;
        *)
            return 1
            ;;
    esac
}

register_rate_limit_plugin
```

**Usage:**
```
--- ASSERTS ---
@rate_limit("remaining") | test("^[0-9]+$")
@rate_limit("limit") == "1000"
```

### Custom Business Logic Plugin

```bash
#!/bin/bash

register_business_plugin() {
    register_plugin "business" "assert_business_logic" "Business logic validation" "external"
}

assert_business_logic() {
    local response="$1"
    local parameter="$2"
    local expected_value="$3"
    local operation_type="$4"
    
    local result
    case "$parameter" in
        "order_total_valid")
            local subtotal quantity price
            subtotal=$(echo "$response" | jq -r '.order.subtotal // 0')
            quantity=$(echo "$response" | jq -r '.order.quantity // 0')
            price=$(echo "$response" | jq -r '.order.price // 0')
            
            # Business rule: subtotal = quantity * price
            if (( $(echo "$subtotal == $quantity * $price" | bc -l) )); then
                result="true"
            else
                result="false"
            fi
            ;;
        "user_permissions")
            result=$(echo "$response" | jq -r '.user.role // "guest"')
            ;;
        *)
            return 1
            ;;
    esac
    
    case "$operation_type" in
        "equals")
            [[ "$result" == "$expected_value" ]]
            ;;
        "test")
            echo "$result" | grep -qE "$expected_value"
            ;;
        *)
            return 1
            ;;
    esac
}

register_business_plugin
```

**Usage:**
```
--- ASSERTS ---
@business("order_total_valid") == "true"
@business("user_permissions") == "admin"
```

## Best Practices

### 1. **Naming Conventions**

- Plugin names: `snake_case` (e.g., `custom_auth`, `rate_limit`)
- Function names: `assert_<plugin_name>` (e.g., `assert_custom_auth`)
- File names: `grpc_<plugin_name>.sh` (e.g., `grpc_custom_auth.sh`)

### 2. **Error Handling**

```bash
assert_my_plugin() {
    local response="$1"
    local parameter="$2"
    local expected_value="$3"
    local operation_type="$4"
    
    # Validate inputs
    if [[ -z "$response" || -z "$parameter" ]]; then
        log error "Missing required parameters"
        return 1
    fi
    
    # Extract value with error checking
    local value
    value=$(echo "$response" | jq -r ".path.to.value // empty")
    
    if [[ -z "$value" ]]; then
        log debug "Value not found at path"
        return 1
    fi
    
    # Perform assertion
    case "$operation_type" in
        "equals")
            [[ "$value" == "$expected_value" ]]
            ;;
        "test")
            echo "$value" | grep -qE "$expected_value"
            ;;
        *)
            log error "Unsupported operation: $operation_type"
            return 1
            ;;
    esac
}
```

### 3. **Performance**

- Minimize external command calls
- Cache expensive operations
- Use built-in bash features when possible
- Avoid unnecessary string manipulation

### 4. **Documentation**

```bash
#!/bin/bash

# grpc_custom_auth.sh - Custom authentication plugin
# 
# This plugin validates custom authentication tokens and claims.
# 
# Supported parameters:
# - "token": Validates JWT token format
# - "claims": Validates token claims
# - "expiry": Checks token expiration
#
# Examples:
# @custom_auth("token") | test("^eyJ")
# @custom_auth("claims") == "admin"
```

### 5. **Testing**

Create test files for your plugins:

```bash
# test_custom_auth.bats

@test "custom_auth validates JWT token" {
    source grpc_custom_auth.sh
    
    local response='{"auth": {"token": "eyJhbGciOiJIUzI1NiJ9"}}'
    
    run assert_custom_auth "$response" "token" "eyJ.*" "test"
    [ "$status" -eq 0 ]
}
```

## Plugin Configuration

### Environment Variables

- `EXTERNAL_PLUGIN_DIR` - Custom plugin directory (default: `~/.grpctestify/plugins`)
- `PLUGIN_DEBUG` - Enable plugin debug logging

### Plugin Directory Structure

```
~/.grpctestify/plugins/
├── grpc_custom_auth.sh
├── grpc_rate_limit.sh
└── grpc_business_logic.sh
```

## Debugging Plugins

### Enable Debug Logging

```bash
export PLUGIN_DEBUG=1
grpctestify run tests/
```

### Validate Plugin

```bash
# Check if plugin loads correctly
grpctestify plugins list

# Test specific plugin
grpctestify plugins test custom_auth
```

### Common Issues

1. **Plugin not loading**: Check file permissions and syntax
2. **Function not found**: Ensure registration function is called
3. **Assertion failing**: Add debug logging to assertion function

## Advanced Features

### Plugin Dependencies

```bash
register_advanced_plugin() {
    # Check for required tools
    if ! command -v jq >/dev/null; then
        log error "jq is required for this plugin"
        return 1
    fi
    
    register_plugin "advanced" "assert_advanced" "Advanced validation" "external"
}
```

### Dynamic Plugin Loading

```bash
# Load plugins from custom directory
export EXTERNAL_PLUGIN_DIR="/path/to/custom/plugins"
grpctestify run tests/
```

### Plugin Hooks

```bash
# Pre-test hook
pre_test_hook() {
    log info "Preparing custom validation"
}

# Post-test hook  
post_test_hook() {
    log info "Cleaning up custom resources"
}
```

## Migration from Old System

If you have plugins using the old system, update them:

**Old System:**
```bash
# Legacy plugin structure
assert_old_plugin() {
    # operation_type included "legacy"
    case "$operation_type" in
        "legacy"|"equals")
            # ...
    esac
}
```

**New System:**
```bash
# New plugin structure
register_new_plugin() {
    register_plugin "new_plugin" "assert_new_plugin" "Description" "external"
}

assert_new_plugin() {
    # Only "equals" and "test" operations
    case "$operation_type" in
        "equals"|"test")
            # ...
    esac
}

register_new_plugin
```

## Contributing Plugins

To contribute a plugin to the official collection:

1. Follow the best practices above
2. Include comprehensive tests
3. Add documentation and examples
4. Submit via GitHub pull request

For questions about plugin development, please [open an issue](https://github.com/gripmock/grpctestify/issues) on GitHub.
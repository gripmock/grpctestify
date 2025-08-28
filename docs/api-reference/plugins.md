# Plugin System

Comprehensive guide to the extensible plugin system for custom assertions in gRPC Testify.

## Overview

The plugin system allows you to extend gRPC Testify with specialized assertion types using a simple `@plugin()` syntax. This provides more powerful and domain-specific validation capabilities beyond standard jq expressions.

## Built-in Plugins

### Header Plugin (`@header`)
Validates gRPC response headers with flexible matching options.

#### Basic Syntax
```php
--- ASSERTS ---
@header("header-name") == "expected-value"
@header("header-name") | test("regex-pattern")
```

#### Examples
```php
# Exact value matching
@header("content-type") == "application/grpc"
@header("x-api-version") == "1.0.0"
@header("authorization") == "Bearer token123"

# Pattern matching
@header("x-response-time") | test("[0-9]+ms")
@header("x-request-id") | test("^req-[a-f0-9-]+$")
@header("server") | test("grpc-go")

# Existence checking
@header("x-trace-id") != null
@header("content-encoding") | type == "string"
```

#### Common Header Patterns
```php
# API versioning
@header("x-api-version") | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")

# Response timing
@header("x-response-time") | test("^[0-9]+ms$")

# Request tracking
@header("x-request-id") | test("^[a-f0-9-]+$")

# Authentication
@header("authorization") | test("^Bearer [A-Za-z0-9._-]+$")

# Content type validation
@header("content-type") | test("application/(grpc|json)")
```

### Trailer Plugin (`@trailer`)
Validates gRPC response trailers for post-processing metadata.

#### Basic Syntax
```php
--- ASSERTS ---
@trailer("trailer-name") == "expected-value"
@trailer("trailer-name") | test("regex-pattern")
```

#### Examples
```php
# Processing metadata
@trailer("x-processing-time") == "45ms"
@trailer("x-cache-hit") == "true"
@trailer("x-db-queries") == "3"

# Performance metrics
@trailer("x-processing-time") | test("[0-9]+ms")
@trailer("x-memory-usage") | test("[0-9]+MB")

# Rate limiting
@trailer("x-rate-limit-remaining") | tonumber >= 0
@trailer("x-rate-limit-reset") | test("[0-9]+")

# Custom business logic
@trailer("x-feature-flags") | contains("new-algorithm")
@trailer("x-shard-id") | test("shard-[0-9]+")
```

#### Common Trailer Patterns
```php
# Timing validation
@trailer("x-processing-time") | test("^[0-9]+ms$")

# Boolean flags
@trailer("x-cache-hit") | test("^(true|false)$")

# Numeric values
@trailer("x-rate-limit") | tonumber <= 1000

# Resource usage
@trailer("x-memory-used") | test("^[0-9]+(\.[0-9]+)?MB$")

# Request correlation
@trailer("x-correlation-id") | test("^[a-f0-9-]{36}$")
```

### gRPC Response Time Plugin (`@grpc_response_time`)
Validates gRPC response times with support for both maximum limits and ranges.

#### Basic Syntax
```php
--- ASSERTS ---
@grpc_response_time(1000)        # Max 1000ms
@grpc_response_time(500-2000)    # Range 500-2000ms
```

#### Examples
```php
# Performance SLA validation
@grpc_response_time(500)         # Must complete within 500ms
@grpc_response_time(100-1000)    # Between 100-1000ms is acceptable

# Service tier validation
@grpc_response_time(50)          # Premium tier - 50ms max
@grpc_response_time(200)         # Standard tier - 200ms max
@grpc_response_time(1000)        # Basic tier - 1000ms max
```

**Note**: The response time is measured by grpctestify and included in the response metadata as `.processing_time_ms`. This plugin validates against that measured value.

#### Common Response Time Patterns
```php
# API performance tiers
@grpc_response_time(50)          # Real-time APIs
@grpc_response_time(200)         # Interactive APIs
@grpc_response_time(1000)        # Background APIs

# Load testing validation
@grpc_response_time(100-500)     # Normal load range
@grpc_response_time(1000)        # Peak load maximum
```

## Plugin Syntax Reference

### Function-Style Syntax
Plugins use a function-style syntax within assertions:

```php
@plugin_name("parameter") operator expression
```

**Components**:
- `@` - Plugin prefix (required)
- `plugin_name` - Name of the plugin
- `("parameter")` - Plugin parameter in quotes
- `operator` - Comparison or pipe operator
- `expression` - Value or test expression

### Supported Operators

#### Equality Operators
```php
@header("name") == "value"     # Exact match
@header("name") != "value"     # Not equal
@trailer("name") == "value"    # Exact match
```

#### Pattern Testing
```php
@header("name") | test("pattern")     # Regex test
@trailer("name") | test("pattern")    # Regex test
```

#### Type and Existence
```php
@header("name") | type == "string"    # Type checking
@header("name") != null               # Existence check
@trailer("name") | length > 5         # Length validation
```

#### Numeric Operations
```php
@trailer("x-count") | tonumber > 10   # Convert to number and compare
@trailer("x-rate") | tonumber <= 100  # Numeric comparison
```

## Advanced Plugin Usage

### Combining with jq Expressions
Mix plugin assertions with standard jq for comprehensive validation:

```php
--- ASSERTS ---
# Standard response validation
.success == true
.data | type == "object"

# Plugin-based metadata validation
@header("x-api-version") == "1.0.0"
@trailer("x-processing-time") | test("[0-9]+ms")

# Combined validation
(.data | length > 0) and @header("content-type") == "application/grpc"
```

### Complex Pattern Validation
```php
# Multi-part header validation
@header("authorization") | test("^Bearer [A-Za-z0-9._-]+$")

# Timestamp validation in trailers
@trailer("x-processed-at") | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}")

# URL validation in headers
@header("x-callback-url") | test("^https://[a-zA-Z0-9.-]+/[a-zA-Z0-9/_-]*$")

# JSON in trailers (if applicable)
@trailer("x-metadata") | fromjson | .version == "1.0"
```

### Error Handling
```php
# Validate error headers
@header("x-error-code") | tonumber == 404
@header("x-error-type") == "not_found"

# Error trailers
@trailer("x-retry-after") | tonumber > 0
@trailer("x-error-details") | test("user_id=[0-9]+")
```

## Plugin Development

### Creating Custom Plugins
While the built-in plugins cover most use cases, you can extend the system by:

1. **Adding plugin functions** in `src/lib/plugins/`
2. **Registering plugins** in the plugin system
3. **Following naming conventions** for consistency

#### Plugin Function Structure
```bash
# Custom plugin example
assert_custom_plugin() {
    local response="$1"
    local parameter="$2"
    local expected_value="$3"
    
    # Extract custom data from response
    local actual_value=$(echo "$response" | jq -r ".custom_field")
    
    # Perform validation
    if [[ "$actual_value" == "$expected_value" ]]; then
        return 0  # Success
    else
        log error "Custom assertion failed: expected '$expected_value', got '$actual_value'"
        return 1  # Failure
    fi
}
```

#### Plugin Registration
```bash
register_custom_plugin() {
    register_plugin "custom" "assert_custom_plugin" "Custom assertion plugin" "internal"
}
```

### Plugin Best Practices

#### 1. **Specific Parameters**
```php
# ✅ Good - specific header name
@header("x-api-version") == "1.0.0"

# ❌ Avoid - generic parameter
@header("header") == "value"
```

#### 2. **Meaningful Patterns**
```php
# ✅ Good - validates actual format
@trailer("x-processing-time") | test("^[0-9]+ms$")

# ❌ Avoid - too permissive
@trailer("x-processing-time") | test(".*")
```

#### 3. **Error Context**
Provide clear error messages when assertions fail:

```php
# Plugin should output helpful error messages
@header("x-rate-limit") | tonumber <= 1000
# Error: "Header 'x-rate-limit' value '1500' exceeds limit '1000'"
```

## Use Cases

### API Versioning
```php
--- ASSERTS ---
# Ensure API version compatibility
@header("x-api-version") | test("^2\\.[0-9]+\\.[0-9]+$")
@header("x-deprecated") != "true"

# Version-specific features
@trailer("x-features") | contains("v2-auth")
```

### Performance Monitoring
```php
--- ASSERTS ---
# Response time SLA
@trailer("x-processing-time") | test("^[0-9]+ms$")
@trailer("x-processing-time") | .[:-2] | tonumber < 500

# Resource usage
@trailer("x-memory-usage") | test("^[0-9]+MB$")
@trailer("x-db-queries") | tonumber <= 10
```

### Security Validation
```php
--- ASSERTS ---
# Security headers
@header("x-content-type-options") == "nosniff"
@header("x-frame-options") == "DENY"
@header("strict-transport-security") | test("max-age=[0-9]+")

# Authentication metadata
@trailer("x-user-id") | test("^user-[0-9]+$")
@trailer("x-session-valid") == "true"
```

### Request Tracing
```php
--- ASSERTS ---
# Distributed tracing
@header("x-trace-id") | test("^[a-f0-9]{32}$")
@header("x-span-id") | test("^[a-f0-9]{16}$")

# Request correlation
@trailer("x-request-path") | startswith("/api/v1/")
@trailer("x-upstream-duration") | test("[0-9]+ms")
```

### Feature Flags
```php
--- ASSERTS ---
# Feature flag validation
@trailer("x-feature-flags") | contains("new-algorithm")
@trailer("x-experiment-group") | test("(control|treatment)")

# A/B testing
@trailer("x-variant") | test("^(a|b)$")
@trailer("x-experiment-id") | test("^exp-[0-9]+$")
```

## Debugging Plugins

### Verbose Mode
Enable verbose logging to see plugin execution:

```bash
./grpctestify.sh test.gctf --verbose
```

### Plugin Listing
Check available plugins:

```bash
./grpctestify.sh --list-plugins
```

### Testing Plugin Assertions
Test individual plugin assertions:

```bash
# Create a minimal test file
cat > test_plugin.gctf << 'EOF'
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
test.Service/Method

--- REQUEST ---
{}

--- ASSERTS ---
@header("content-type") | test("grpc")
EOF

./grpctestify.sh test_plugin.gctf --verbose
```

## Error Messages

### Common Plugin Errors

#### Plugin Not Found
```
Error: Plugin not found: unknown_plugin
Available plugins: header, trailer
```

**Solution**: Check plugin name spelling and availability.

#### Invalid Syntax
```
Error: Invalid plugin syntax: @header(missing-quotes)
```

**Solution**: Ensure parameter is quoted: `@header("name")`

#### Assertion Failure
```
Error: Header 'x-api-version' assertion failed: expected '1.0.0', actual '2.0.0'
```

**Solution**: Check expected vs actual values.

## Integration Examples

### Complete Test with Plugins
```php
--- ADDRESS ---
api.example.com:443

--- TLS ---
enabled: true

--- ENDPOINT ---
user.UserService/GetProfile

--- REQUEST ---
{
  "user_id": "12345"
}

--- ASSERTS ---
# Standard response validation
.success == true
.user.id == "12345"
.user.email | test("@")

# Header validation
@header("x-api-version") == "1.0.0"
@header("x-rate-limit-remaining") | tonumber > 0
@header("authorization") | test("Bearer")

# Trailer validation  
@trailer("x-processing-time") | test("[0-9]+ms")
@trailer("x-cache-hit") | test("(true|false)")
@trailer("x-user-tier") == "premium"

--- OPTIONS ---
timeout: 30
```

### Streaming with Plugins
```php
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
stream.Service/ServerStream

--- REQUEST ---
{"query": "search"}

# First response
--- ASSERTS ---
[0].id | type == "string"
@header("x-stream-id") | test("^stream-[0-9]+$")

# Second response
--- ASSERTS ---
[1].id | type == "string" 
@trailer("x-total-results") | tonumber > 0
```

The plugin system provides powerful, domain-specific assertion capabilities while maintaining the simplicity and readability of gRPC Testify test files. Use plugins for metadata validation while relying on standard jq expressions for response body validation.

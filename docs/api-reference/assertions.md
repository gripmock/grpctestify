# Assertions & Validation

Comprehensive guide to assertion syntax, jq expressions, and validation patterns in gRPC Testify.

## Overview

gRPC Testify supports powerful assertion capabilities through:
- **jq expressions** for flexible JSON validation
- **Plugin system** for specialized assertions
- **Type checking** and pattern matching
- **Array operations** and conditional logic

## Assertion Sections

### ASSERTS Section
Primary assertion mechanism using jq expressions:

```php
--- ASSERTS ---
.success == true
.data | type == "object"
.items | length > 0
.user.email | test("@.*\.com$")
```

**Key Features**:
- **Priority**: Takes precedence over RESPONSE section
- **Flexibility**: Supports complex jq expressions
- **Multiple assertions**: Each line is a separate test
- **Type safety**: Built-in type checking
- **Pattern matching**: Regex support via `test()`

## jq Expression Reference

### Basic Comparisons
```php
# Equality
.status == "success"
.code == 200
.active == true

# Inequality  
.error != null
.count != 0

# Numeric comparisons
.price > 100
.quantity >= 1
.discount <= 0.5
```

### Type Checking
```php
# Basic types
.id | type == "string"
.count | type == "number"
.active | type == "boolean"
.items | type == "array"
.user | type == "object"
.optional | type == "null"

# Compound checks
.id | type == "string" and length > 0
.price | type == "number" and . > 0
```

### String Operations

```php
# Contains substring
.message | contains("success")
.description | contains("gRPC")

# Starts/ends with
.url | startswith("https://")
.filename | endswith(".json")

# Length checking
.username | length >= 3
.password | length > 8

# Regex matching
.email | test("^[^@]+@[^@]+\.[^@]+$")
.phone | test("^\+?[0-9-()\\s]+$")
.uuid | test("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
```

### Array Operations

```php
# Length checking
.items | length == 3
.tags | length > 0
.users | length <= 100

# Element access
.items[0].id == "first"
.items[-1].status == "last"

# Contains element
.tags | index("production") != null
.roles | index("admin") != null

# All/any conditions
.items | all(.active == true)
.users | any(.role == "admin")

# Array filtering
.items | map(select(.active)) | length > 0
.users | map(.role) | unique | length >= 2
```

### Object Operations

```php
# Key existence
.user | has("id")
.config | has("database")
.metadata | has("version")

# Key counting
.user | keys | length == 3
.config | keys | contains(["host", "port"])

# Nested access
.user.profile.settings.theme == "dark"
.response.data.items[0].name | type == "string"

# Dynamic key access
.["content-type"] == "application/json"
.user["first-name"] | type == "string"
```

### Conditional Logic
```php
# If-then-else
if .status == "error" then .message != null else .data != null end

# Null coalescing
.optional_field // "default_value"

# Multiple conditions
.status == "ok" and .data != null and (.data | length > 0)
.error == null or .error == ""
```

### Advanced Patterns
```php
# Complex validation
(.user.age >= 18 and .user.age <= 120)
(.email | test("@")) and (.email | contains("."))

# Date validation (ISO format)
.created_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}")

# URL validation
.url | test("^https?://[^\\s/$.?#].[^\\s]*$")

# Number range validation
.rating >= 1 and .rating <= 5

# Array element validation
.items | all(.price > 0 and .name | type == "string")
```

## Plugin System

### Header Assertions
Validate gRPC response headers:

```php
--- ASSERTS ---
@header("content-type") == "application/grpc"
@header("x-api-version") == "1.0.0"
@header("x-response-time") | test("[0-9]+ms")
@header("authorization") != null
```

**Syntax**:
- `@header("name") == "value"` - Exact match
- `@header("name") | test("pattern")` - Regex pattern
- `@header("name") != null` - Existence check

### Trailer Assertions
Validate gRPC response trailers:

```php
--- ASSERTS ---
@trailer("x-processing-time") == "45ms"
@trailer("x-cache-hit") | test("(true|false)")
@trailer("x-rate-limit") | tonumber <= 1000
```

**Common Trailer Patterns**:

```php
# Processing time
@trailer("x-processing-time") | test("[0-9]+ms")

# Cache status
@trailer("x-cache-status") | test("(hit|miss)")

# Rate limiting
@trailer("x-rate-limit-remaining") | tonumber >= 0

# Custom metadata
@trailer("x-request-id") | test("^req-[a-f0-9]+$")
```

## Validation Patterns

### API Response Validation

```php
--- ASSERTS ---
# Standard API response
.success == true
.message | type == "string"
.data | type == "object"
.timestamp | test("^[0-9]{4}-")

# Error response
.success == false
.error | type == "object"
.error.code | type == "number"
.error.message | type == "string"
```

### Database Entity Validation

```php
--- ASSERTS ---
# User entity
.id | type == "string" and length > 0
.email | test("^[^@]+@[^@]+\.[^@]+$")
.created_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T")
.updated_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T")
.active | type == "boolean"

# Product entity
.sku | test("^[A-Z0-9-]+$")
.price | type == "number" and . > 0
.currency | test("^[A-Z]{3}$")
.categories | type == "array" and length > 0
```

### Pagination Validation
```php
--- ASSERTS ---
# Pagination metadata
.page | type == "number" and . >= 1
.per_page | type == "number" and . > 0
.total | type == "number" and . >= 0
.total_pages | type == "number" and . >= 0

# Data consistency
(.items | length) <= .per_page
(.page - 1) * .per_page < .total
```

### Security Validation
```php
--- ASSERTS ---
# Ensure sensitive data is not exposed
.password == null
.secret_key == null
.private_token == null

# Validate sanitized output
.user_input | test("^[a-zA-Z0-9\\s.,!?-]*$")
.html_content | contains("script") | not

# Check permissions
.permissions | type == "array"
.permissions | index("admin") == null  # No admin for regular users
```

## Error Assertion Patterns

### Expected Errors
```php
--- ERROR ---
{
  "code": 5,
  "message": "User not found",
  "details": []
}

--- ASSERTS ---
.code == 5
.message | contains("not found")
.details | type == "array"
```

### Validation Errors
```php
--- ASSERTS ---
# Field validation errors
.code == 3  # INVALID_ARGUMENT
.message | contains("validation")
.details | length > 0
.details[0] | has("field_violations")
```

## Performance Assertions

### Response Time
Using custom plugins or metadata:

```php
--- ASSERTS ---
# If server includes timing
.processing_time_ms | tonumber < 1000

# Using trailers
@trailer("x-processing-time") | tonumber < 500
```

### Resource Usage
```php
--- ASSERTS ---
# Memory usage (if exposed)
.memory_usage_mb | tonumber < 100

# Database queries (if tracked)
.db_queries | tonumber <= 5
```

## Testing Strategies

### Progressive Validation
```php
# Level 1: Basic structure
.success | type == "boolean"
.data | type == "object"

# Level 2: Required fields
.data.id | type == "string"
.data.name | type == "string"

# Level 3: Business logic
.data.id | test("^user-[0-9]+$")
.data.name | length >= 2
```

### Conditional Testing
```php
# Test based on response type
if .success == true then
  .data != null and (.data | type == "object")
else
  .error != null and (.error | type == "object")
end
```

### Bulk Validation
```php
# Validate all array elements
.items | all(
  .id | type == "string" and
  .name | type == "string" and
  .price | type == "number" and . > 0
)
```

## Best Practices

### 1. **Specific Assertions**
```php
# ✅ Good - specific
.user.email | test("^[^@]+@[^@]+\.[^@]+$")

# ❌ Avoid - too generic
.user.email | type == "string"
```

### 2. **Defensive Checks**
```php
# Check existence before validation
.user != null and .user.id | type == "string"

# Handle optional fields
.optional_field // null | . == null or type == "string"
```

### 3. **Clear Error Messages**
Use meaningful field names and specific patterns:

```php
# ✅ Clear intent
.order_status | test("^(pending|processing|completed|cancelled)$")

# ❌ Unclear
.status | type == "string"
```

### 4. **Reusable Patterns**
For complex validations, document patterns:

```php
# UUID validation pattern (reusable)
.id | test("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")

# ISO datetime pattern
.timestamp | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}")
```

## Debugging Assertions

### Test jq Expressions
```bash
# Test expressions separately
echo '{"status": "ok", "count": 5}' | jq '.status == "ok"'
echo '{"items": [1,2,3]}' | jq '.items | length > 2'
```

### Common Mistakes
```php
# ❌ Wrong: Missing quotes in comparison
.status == ok

# ✅ Correct: Quoted string value
.status == "ok"

# ❌ Wrong: Incorrect null check
.field == nil

# ✅ Correct: Proper null check  
.field == null
```

### Validation Tips
1. **Start simple**: Basic existence and type checks first
2. **Build incrementally**: Add complexity gradually
3. **Test expressions**: Validate jq syntax separately
4. **Use meaningful assertions**: Test business logic, not just structure
5. **Handle edge cases**: Null values, empty arrays, etc.

This comprehensive guide covers assertion patterns for most gRPC testing scenarios. For more complex cases, refer to the [jq manual](https://stedolan.github.io/jq/manual/) and the [plugin system documentation](./plugins).

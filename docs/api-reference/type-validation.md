# Type Validation

Advanced type validation system for gRPC responses with support for UUID, timestamps, URLs, emails, and more specialized data types.

## Overview

The type validation plugin extends gRPC Testify with powerful validation capabilities beyond basic jq type checking. It provides specialized validators for common data formats used in modern APIs.

## Available Type Validators

### UUID Validation (`@uuid`)

Validates RFC 4122 compliant UUIDs with optional version checking.

```php
--- ASSERTS ---
@uuid(.user.id) == true
@uuid(.product.id, "v4") == true
@uuid(.session.token, "v1") == true
```

**Supported Versions:**
- `any` (default) - Any valid UUID format
- `v1` - Time-based UUID
- `v4` - Random UUID
- `v5` - Name-based UUID

**Examples:**
```php
# Basic UUID validation
@uuid(.id) == true

# Version-specific validation  
@uuid(.user_id, "v4") == true
@uuid(.timestamp_id, "v1") == true

# Combined with jq expressions
@uuid(.session.token) == true and (.session.expires_at | tonumber > now)
```

### Timestamp Validation (`@timestamp`)

Validates various timestamp formats including ISO 8601, RFC 3339, and Unix timestamps.

```php
--- ASSERTS ---
@timestamp(.created_at, "iso8601") == true
@timestamp(.updated_at, "rfc3339") == true  
@timestamp(.unix_time, "unix") == true
@timestamp(.event_time, "unix_ms") == true
```

**Supported Formats:**
- `iso8601` or `iso` - ISO 8601 format (2024-01-15T10:30:00Z)
- `rfc3339` or `rfc` - RFC 3339 format (stricter than ISO 8601)
- `unix` or `epoch` - Unix timestamp in seconds (10 digits)
- `unix_ms` or `epoch_ms` - Unix timestamp in milliseconds (13 digits)

**Examples:**
```php
# ISO 8601 timestamps
@timestamp(.created_at, "iso8601") == true
@timestamp(.published_at, "iso") == true

# Unix timestamps
@timestamp(.timestamp, "unix") == true
@timestamp(.event_timestamp, "unix_ms") == true

# Validate timestamp is recent (within last hour)
@timestamp(.created_at, "iso8601") == true and 
  ((.created_at | fromdateiso8601) > (now - 3600))
```

### URL Validation (`@url`)

Validates URLs with optional scheme restrictions.

```php
--- ASSERTS ---
@url(.website) == true
@url(.api_endpoint, "https") == true
@url(.websocket_url, "wss") == true
```

**Supported Schemes:**
- `any` (default) - Any valid URL scheme
- `http` - HTTP URLs only
- `https` - HTTPS URLs only  
- `ftp` - FTP URLs only
- `ws` - WebSocket URLs only
- `wss` - Secure WebSocket URLs only

**Examples:**
```php
# Basic URL validation
@url(.homepage) == true

# Scheme-specific validation
@url(.api_url, "https") == true
@url(.websocket, "wss") == true

# Validate URL accessibility
@url(.image_url, "https") == true and 
  (.image_url | test("\\.(jpg|png|gif|webp)$"))
```

### Email Validation (`@email`)

Validates email addresses with optional strict mode.

```php
--- ASSERTS ---
@email(.user.email) == true
@email(.contact.email, "strict") == true
```

**Validation Modes:**
- `false` (default) - Basic email format validation
- `true` or `strict` - Strict RFC 5322 compliance

**Examples:**
```php
# Basic email validation
@email(.email) == true

# Strict validation
@email(.primary_email, "strict") == true

# Domain-specific validation
@email(.work_email) == true and (.work_email | test("@company\\.com$"))
```

### IP Address Validation (`@ip`)

Validates IPv4 and IPv6 addresses.

```php
--- ASSERTS ---
@ip(.client_ip, "v4") == true
@ip(.server_ip, "v6") == true
@ip(.proxy_ip) == true
```

**Supported Versions:**
- `any` (default) - IPv4 or IPv6
- `v4` or `4` - IPv4 only
- `v6` or `6` - IPv6 only

**Examples:**
```php
# IPv4 validation
@ip(.client_ip, "v4") == true

# IPv6 validation  
@ip(.server_ipv6, "v6") == true

# Any IP version
@ip(.load_balancer_ip) == true

# Private IP range validation
@ip(.internal_ip, "v4") == true and 
  (.internal_ip | test("^(10\\.|192\\.168\\.|172\\.(1[6-9]|2[0-9]|3[0-1])\\.)"))
```

## Advanced Type Validation

### Semantic Version Validation

```bash
# Using jq patterns for semantic versions
.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$")
```

### Credit Card Validation

```bash
# Basic credit card number pattern
.card_number | test("^[0-9]{13,19}$")

# Visa card pattern
.card_number | test("^4[0-9]{12,18}$")

# Mastercard pattern
.card_number | test("^5[1-5][0-9]{14}$")
```

### Phone Number Validation

```bash
# International format
.phone | test("^\\+[1-9][0-9]{4,14}$")

# US format
.phone | test("^\\([0-9]{3}\\) [0-9]{3}-[0-9]{4}$")
```

### MAC Address Validation

```bash
# Colon-separated MAC address
.mac_address | test("^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$")

# Dash-separated MAC address
.mac_address | test("^([0-9a-fA-F]{2}-){5}[0-9a-fA-F]{2}$")
```

### JSON Web Token (JWT) Validation

```bash
# Basic JWT structure
.token | test("^[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+$")

# Validate JWT header contains expected algorithm
.token | split(".")[0] | @base64d | fromjson | .alg == "HS256"
```

### Color Code Validation

```bash
# Hex color codes
.color | test("^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$")

# RGB color codes
.color | test("^rgb\\([[:space:]]*([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])[[:space:]]*,[[:space:]]*([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])[[:space:]]*,[[:space:]]*([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])[[:space:]]*\\)$")
```

## Real-World Examples

### User Profile Validation

```php
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
user.UserService/GetProfile

--- REQUEST ---
{"user_id": "550e8400-e29b-41d4-a716-446655440000"}

--- ASSERTS ---
# Basic structure
.success == true
.user | type == "object"

# Type validations
@uuid(.user.id) == true
@email(.user.email) == true
@timestamp(.user.created_at, "iso8601") == true
@url(.user.avatar_url, "https") == true

# Business logic
.user.email_verified == true
.user.status | test("^(active|inactive|suspended)$")
.user.role | test("^(user|admin|moderator)$")

# Security validations
.user.password == null
.user | has("social_security_number") | not
```

### E-commerce Product Validation

```php
--- ASSERTS ---
# Product structure
@uuid(.product.id, "v4") == true
@timestamp(.product.created_at, "iso8601") == true
@timestamp(.product.updated_at, "rfc3339") == true

# Pricing validation
.product.price | type == "number" and . > 0
.product.currency | test("^[A-Z]{3}$")  # ISO currency code

# Media validation
.product.images | type == "array" and length > 0
.product.images | all(@url(., "https"))
.product.thumbnail | @url(., "https")

# Vendor validation
@email(.product.vendor.contact_email) == true
@url(.product.vendor.website, "https") == true

# Inventory validation
.product.stock | type == "number" and . >= 0
.product.sku | test("^[A-Z0-9-]{6,20}$")
```

### API Response Metadata

```php
--- ASSERTS ---
# Request tracking
@uuid(.metadata.request_id, "v4") == true
@timestamp(.metadata.timestamp, "rfc3339") == true
@ip(.metadata.client_ip, "v4") == true

# Performance metrics
.metadata.processing_time_ms | type == "number" and . > 0 and . < 5000
.metadata.cache_hit | type == "boolean"

# API versioning
.metadata.api_version | test("^v[0-9]+$")
.metadata.schema_version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")

# Rate limiting
.metadata.rate_limit.remaining | type == "number" and . >= 0
.metadata.rate_limit.reset_at | @timestamp(., "unix")
```

## Custom Type Validators

### Creating Custom Validators

You can extend the type validation system by adding custom functions:

```bash
# Custom validator function
validate_custom_id() {
    local value="$1"
    # Custom ID: PREFIX-YYYYMMDD-NNNN
    [[ "$value" =~ ^[A-Z]{2,4}-[0-9]{8}-[0-9]{4}$ ]]
}

# Plugin integration
assert_custom_id() {
    local response="$1"
    local field_path="$2"
    
    local value
    value=$(echo "$response" | jq -r "$field_path" 2>/dev/null)
    
    if validate_custom_id "$value"; then
        return 0
    else
        log error "Custom ID validation failed: $value"
        return 1
    fi
}
```

### Complex Validation Patterns

```php
--- ASSERTS ---
# Validate nested object with multiple types
.order | type == "object"
@uuid(.order.id, "v4") == true
@timestamp(.order.created_at, "iso8601") == true
@email(.order.customer.email) == true

# Validate array elements
.order.items | type == "array" and length > 0
.order.items | all(
    @uuid(.product_id, "v4") and
    (.quantity | type == "number" and . > 0) and
    (.price | type == "number" and . > 0)
)

# Conditional validation
if .order.shipping_required == true then
    .order.shipping_address | type == "object" and
    (.order.shipping_address.postal_code | test("^[0-9]{5}(-[0-9]{4})?$"))
else
    true
end

# Cross-field validation
if .order.payment_method == "credit_card" then
    @uuid(.order.payment_token, "v4")
else
    .order.payment_token == null
end
```

## Performance Considerations

### Optimization Tips

1. **Order Validators by Performance**:
   ```php
   # Fast checks first
   .id | type == "string"
   .id | length > 0
   
   # Complex validation last
   @uuid(.id, "v4") == true
   ```

2. **Use Conditional Validation**:
   ```php
   # Only validate if field exists
   if .optional_field then @email(.optional_field) else true end
   
   # Skip validation for null values
   (.email // null) | if . != null then @email(.) else true end
   ```

3. **Combine Validations**:
   ```php
   # Combine related checks
   @uuid(.id, "v4") == true and (.id | length == 36)
   
   # Use jq for simple patterns when possible
   .version | test("^[0-9]+\\.[0-9]+$")  # Instead of custom validator
   ```

## Error Handling

### Common Validation Errors

```bash
# UUID validation failed
Field '.user.id' UUID validation failed: invalid-uuid-format

# Timestamp validation failed  
Field '.created_at' timestamp validation failed: 2024/01/15 10:30:00 (format: iso8601)

# URL validation failed
Field '.website' URL validation failed: not-a-url (scheme: https)

# Email validation failed
Field '.email' email validation failed: invalid-email-format
```

### Debugging Type Validation

```bash
# Enable verbose mode for detailed validation logs
./grpctestify.sh test.gctf --verbose

# Check specific field types
echo '{"field": "value"}' | jq '.field | type'

# Test validation functions directly
source src/lib/plugins/grpc_type_validation.sh
validate_uuid "550e8400-e29b-41d4-a716-446655440000"
echo $?  # 0 for success, 1 for failure
```

## Integration with CI/CD

### GitHub Actions Example

```yaml
- name: Run Type Validation Tests
  run: |
    ./grpctestify.sh tests/type-validation/ --log-format json --log-output validation-results.json
    
    # Check for specific validation failures
    if jq -e '.tests[] | select(.error | contains("validation failed"))' validation-results.json; then
      echo "Type validation failures detected"
      exit 1
    fi
```

### Custom Validation Rules

```bash
# Create project-specific validation rules
validate_project_id() {
    local value="$1"
    # Project ID: PROJ-YYYY-NNNN
    [[ "$value" =~ ^PROJ-[0-9]{4}-[0-9]{4}$ ]]
}

# Use in test files
.project.id | test("^PROJ-[0-9]{4}-[0-9]{4}$")
```

The type validation system provides robust validation capabilities for modern API testing, ensuring data integrity and format compliance across your gRPC services.

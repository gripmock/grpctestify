# Assertion Patterns

Assertions in gRPC Testify use jq expressions to validate response data, headers, and trailers.

## What's Supported

gRPC Testify supports these assertion features:
- ✅ **jq-based Assertions** - Use jq expressions for validation
- ✅ **Type Validation** - Check data types (string, number, boolean)
- ✅ **Array Validation** - Validate arrays and their contents
- ✅ **Nested Object Validation** - Test complex nested structures
- ✅ **Header/Trailer Validation** - Test gRPC metadata
- ✅ **String Operations** - Contains, starts with, ends with, regex
- ✅ **Mathematical Operations** - Comparisons, calculations
- ✅ **Conditional Logic** - if/then/else statements

## Basic Assertions

### Simple Value Validation

```gctf
--- ENDPOINT ---
user.UserService/GetUser

--- REQUEST ---
{ "user_id": "123" }

--- ASSERTS ---
.user.id == "123"
.user.name == "John Doe"
.user.age == 30
.user.active == true
```

### Type Validation

```gctf
--- ENDPOINT ---
product.ProductService/GetProduct

--- REQUEST ---
{ "product_id": "prod_001" }

--- ASSERTS ---
.product.id | type == "string"
.product.price | type == "number"
.product.in_stock | type == "boolean"
.product.tags | type == "array"
```

## String Validation

### Basic String Operations

```gctf
--- ASSERTS ---
# Exact match
.name == "John Doe"

# Contains substring
.description | contains("important")

# Starts with
.email | startswith("john")

# Ends with
.filename | endswith(".pdf")

# Length validation
.password | length >= 8
.username | length <= 20
```

### Regular Expression Testing

```gctf
--- ASSERTS ---
# Email validation
.email | test("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")

# Phone number validation
.phone | test("^\\+?[1-9]\\d{1,14}$")

# URL validation
.url | test("^https?://[^\\s/$.?#].[^\\s]*$")

# Date format validation
.created_at | test("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$")
```

## Number Validation

### Basic Number Operations

```gctf
--- ASSERTS ---
# Exact value
.count == 42

# Range validation
.age >= 18
.age <= 120
.price > 0
.price <= 9999.99

# Type checking
.score | type == "number"
.rating | type == "number"
```

### Mathematical Operations

```gctf
--- ASSERTS ---
# Basic arithmetic
.total == (.subtotal + .tax)
.discount_amount == (.original_price - .final_price)

# Percentage calculations
.discount_percent >= 0
.discount_percent <= 100

# Rounding
.rounded_price == (.price | round)
.ceiling_price == (.price | ceil)
.floor_price == (.price | floor)
```

## Boolean Validation

### Boolean Operations

```gctf
--- ASSERTS ---
# Exact boolean values
.is_active == true
.is_deleted == false

# Type checking
.verified | type == "boolean"
.premium | type == "boolean"

# Logical combinations
.is_active and .verified
not .is_deleted
(.is_active or .is_admin) and .verified
```

## Array Validation

### Basic Array Operations

```gctf
--- ASSERTS ---
# Array length
.items | length > 0
.items | length <= 100

# Array element access
.items[0].id | length > 0
.items[1].name == "Second Item"

# Array type checking
.tags | type == "array"
.numbers | type == "array"
```

### Array Content Validation

```gctf
--- ASSERTS ---
# All items have required fields
.items[] | has("id")
.items[] | has("name")
.items[] | has("price")

# All items meet criteria
.items[].price > 0
.items[].name | length > 0

# Array contains specific item
.items[] | .name == "Special Item"

# Array doesn't contain specific item
(.items[] | .name == "Forbidden Item") | not
```

### Array Filtering and Mapping

```gctf
--- ASSERTS ---
# Count items matching criteria
(.items[] | select(.active == true)) | length == 3

# All active items have valid names
.items[] | select(.active == true) | .name | length > 0

# Sum of all prices
(.items[] | .price) | add == 299.97

# Average price
(.items[] | .price) | add / length == 99.99
```

## Object Validation

### Nested Object Validation

```gctf
--- ASSERTS ---
# Top-level validation
.id == "order_001"
.status | type == "string"

# Nested object validation
.customer.name == "John Doe"
.customer.email | contains("@")
.customer.address.city == "Moscow"

# Deep nesting
.order.items[0].product.category.name == "Electronics"
```

### Object Field Validation

```gctf
--- ASSERTS ---
# Check if field exists
.user | has("id")
.user | has("name")
.user | has("email")

# Check if field doesn't exist
.user | has("password") | not

# Check multiple fields
.user | has("id") and has("name") and has("email")
```

## Null and Optional Values

### Handling Null Values

```gctf
--- ASSERTS ---
# Check for null
.middle_name == null
.optional_field == null

# Check for non-null
.first_name != null
.last_name != null

# Conditional validation
if .type == "premium" then .premium_features | length > 0 else true
```

### Optional Field Validation

```gctf
--- ASSERTS ---
# Validate if field exists
if has("optional_field") then .optional_field | length > 0 else true

# Validate based on condition
if .status == "completed" then .completion_date != null else true

# Complex conditional
if .user_type == "admin" then 
  .admin_permissions | length > 0
else 
  .admin_permissions == null
end
```

## Header and Trailer Validation

### gRPC Metadata Validation

```gctf
--- ASSERTS ---
# Response header validation
@header("x-response-time") < 1000
@header("x-request-id") | length > 0
@header("content-type") | contains("application/json")

# Response trailer validation
@trailer("x-processing-time") > 0
@trailer("x-cache-hit") == "true"

# Header type validation
@header("x-count") | type == "number"
@header("x-status") | type == "string"
```

## Complex Validation Patterns

### Multi-Condition Validation

```gctf
--- ASSERTS ---
# Multiple conditions
.user.id | length > 0 and .user.name | length > 0 and .user.email | contains("@")

# Complex business logic
if .order.total > 1000 then
  .order.requires_approval == true and .order.approval_status != null
else
  .order.requires_approval == false
end
```

### Data Transformation Validation

```gctf
--- ASSERTS ---
# Validate transformed data
.uppercase_name == (.name | ascii_upcase)
.lowercase_email == (.email | ascii_downcase)

# Validate calculated fields
.formatted_price == ("$" + (.price | tostring))
.full_name == (.first_name + " " + .last_name)
```

### Error Response Validation

```gctf
--- ASSERTS ---
# Validate error structure
.code == 3
.message | contains("Invalid")
.details | length > 0

# Validate specific error types
if .code == 5 then
  .message | contains("not found")
elif .code == 3 then
  .message | contains("Invalid")
else
  .code >= 0 and .code <= 16
end
```

## Real Examples

### User Data Validation

```gctf
--- ENDPOINT ---
user.UserService/GetUser

--- REQUEST ---
{ "user_id": "123" }

--- ASSERTS ---
.user.id | length > 0
.user.name | type == "string"
.user.name | length > 0
.user.email | contains("@")
.user.email | contains(".")
.user.created_at | length > 0
.user.active | type == "boolean"
```

### Product Data Validation

```gctf
--- ENDPOINT ---
product.ProductService/GetProduct

--- REQUEST ---
{ "product_id": "prod_001" }

--- ASSERTS ---
.product.id | length > 0
.product.name | type == "string"
.product.name | length > 0
.product.price | type == "number"
.product.price > 0
.product.category | type == "string"
.product.in_stock | type == "boolean"
.product.tags | type == "array"
.product.tags | length > 0
```

### Order Data Validation

```gctf
--- ENDPOINT ---
order.OrderService/GetOrder

--- REQUEST ---
{ "order_id": "order_001" }

--- ASSERTS ---
.order.id | length > 0
.order.status | type == "string"
.order.total | type == "number"
.order.total > 0
.order.items | length > 0
.order.items[] | has("id")
.order.items[].quantity > 0
.order.items[].price > 0
.order.customer.name | length > 0
.order.customer.email | contains("@")
```

## Best Practices

### ✅ Do This:

1. **Validate Critical Fields**
   ```gctf
   --- ASSERTS ---
   .id | length > 0
   .name | type == "string"
   .created_at | length > 0
   ```

2. **Use Type Validation**
   ```gctf
   --- ASSERTS ---
   .price | type == "number"
   .price > 0
   ```

3. **Validate Arrays Comprehensively**
   ```gctf
   --- ASSERTS ---
   .items | length > 0
   .items[] | has("id")
   .items[].price > 0
   ```

4. **Test Nested Objects**
   ```gctf
   --- ASSERTS ---
   .user.name | length > 0
   .user.email | contains("@")
   ```

### ❌ Avoid This:

1. **Hard-coded Values**
   ```gctf
   # Bad
   .created_at == "2024-01-15T10:30:00Z"
   
   # Good
   .created_at | length > 0
   .created_at | contains("T")
   ```

2. **Incomplete Validation**
   ```gctf
   # Bad - only checking one field
   .user.name == "John"
   
   # Good - comprehensive validation
   .user.name == "John"
   .user.id | length > 0
   .user.email | contains("@")
   ```

3. **Ignoring Type Safety**
   ```gctf
   # Bad - no type checking
   .count > 0
   
   # Good - type validation first
   .count | type == "number"
   .count > 0
   ```

## Common Patterns

### Pattern 1: Required Field Validation

```gctf
--- ASSERTS ---
# All required fields exist and are valid
.id | length > 0
.name | type == "string" and length > 0
.email | contains("@") and contains(".")
.created_at | length > 0
```

### Pattern 2: Conditional Validation

```gctf
--- ASSERTS ---
# Validate based on status
if .status == "active" then
  .last_login != null and .login_count > 0
else
  .deactivated_at != null
end
```

### Pattern 3: Array Validation

```gctf
--- ASSERTS ---
# Validate array structure
.items | length > 0
.items[] | has("id") and has("name") and has("price")
.items[].price > 0
.items[].name | length > 0
```

## Next Steps

- **[Data Validation](data-validation)** - Learn basic testing patterns
- **[Error Testing](error-testing)** - Test error conditions
- **[Real Examples](../guides/examples/basic/real-time-chat)** - See assertion patterns in action

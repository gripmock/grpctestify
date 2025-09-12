# Data Validation

Data validation is the foundation of gRPC testing. Learn how to validate response data, test different data types, and handle complex nested structures.

## Basic Data Validation

### Simple Response Validation

Test basic response data:

```gctf
--- ENDPOINT ---
user.UserService/GetUser

--- REQUEST ---
{ "user_id": "123" }

--- RESPONSE ---
{
  "user": {
    "id": "123",
    "name": "John Doe",
    "email": "john@example.com"
  }
}
```

### Using Assertions for Flexible Validation

For more dynamic validation, use assertions:

```gctf
--- ENDPOINT ---
user.UserService/GetUser

--- REQUEST ---
{ "user_id": "123" }

--- ASSERTS ---
.user.id == "123"
.user.name == "John Doe"
.user.email | contains("@")
```

## Type Validation

Ensure response fields have correct types:

```gctf
--- ENDPOINT ---
product.ProductService/GetProduct

--- REQUEST ---
{ "product_id": "prod_001" }

--- ASSERTS ---
# String validation
.product.id | type == "string"
.product.name | type == "string"

# Number validation
.product.price | type == "number"
.product.price > 0
.product.stock_count | type == "number"
.product.stock_count >= 0

# Boolean validation
.product.in_stock | type == "boolean"
.product.featured | type == "boolean"
```

## Array Validation

Testing responses with arrays:

```gctf
--- ENDPOINT ---
product.ProductService/ListProducts

--- REQUEST ---
{ "category": "electronics" }

--- ASSERTS ---
# Array length
.products | length > 0
.products | length <= 100

# Array element validation
.products[0].id | length > 0
.products[0].name | type == "string"
.products[0].price > 0

# All products have required fields
.products[] | has("id")
.products[] | has("name")
.products[] | has("price")

# Price validation for all products
.products[].price > 0
```

## Nested Object Validation

Testing complex nested structures:

```gctf
--- ENDPOINT ---
order.OrderService/GetOrderDetails

--- REQUEST ---
{ "order_id": "order_001" }

--- ASSERTS ---
# Top-level validation
.order.id == "order_001"
.order.status | type == "string"

# Nested customer validation
.order.customer.name == "John Doe"
.order.customer.email | contains("@")
.order.customer.id | length > 0

# Array of items validation
.order.items | length > 0
.order.items[0].quantity > 0
.order.items[0].price > 0
.order.items[0].product_id | length > 0

# Nested shipping validation
.order.shipping.city == "Moscow"
.order.shipping.country == "Russia"
.order.shipping.zip_code | length > 0
```

## String Validation

Advanced string validation techniques:

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

# Pattern matching (regex)
.email | test("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")
.phone | test("^\\+?[1-9]\\d{1,14}$")
```

## Number Validation

Comprehensive number validation:

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

# Mathematical operations
.total == (.subtotal + .tax)
.discount_percent >= 0
.discount_percent <= 100
```

## Boolean Validation

Testing boolean fields:

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
```

## Null and Optional Fields

Handling null values and optional fields:

```gctf
--- ASSERTS ---
# Check for null
.middle_name == null

# Check for non-null
.first_name != null
.last_name != null

# Optional field validation
if has("optional_field") then .optional_field | length > 0 else true

# Conditional validation
if .type == "premium" then .premium_features | length > 0 else true
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

### User Data Validation
```gctf
--- ASSERTS ---
.user.id | length > 0
.user.name | type == "string"
.user.name | length > 0
.user.email | contains("@")
.user.email | contains(".")
.user.created_at | length > 0
```

### Product Data Validation
```gctf
--- ASSERTS ---
.product.id | length > 0
.product.name | type == "string"
.product.name | length > 0
.product.price | type == "number"
.product.price > 0
.product.category | type == "string"
.product.in_stock | type == "boolean"
```

### Order Data Validation
```gctf
--- ASSERTS ---
.order.id | length > 0
.order.status | type == "string"
.order.total | type == "number"
.order.total > 0
.order.items | length > 0
.order.items[] | has("id")
.order.items[].quantity > 0
.order.items[].price > 0
```

## Next Steps

- **[Error Testing](error-testing)** - Learn to test error conditions
- **[Assertion Patterns](assertion-patterns)** - Master advanced validation techniques
- **[Real Examples](../guides/examples/basic/real-time-chat)** - See data validation in action

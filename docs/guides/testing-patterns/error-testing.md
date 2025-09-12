# Error Testing

Error testing is crucial for robust gRPC applications. Learn how to test error conditions, validation failures, and expected error scenarios.

## Why Test Errors?

Testing error conditions ensures your application:
- ✅ Handles failures gracefully
- ✅ Returns meaningful error messages
- ✅ Maintains security under invalid input
- ✅ Provides helpful debugging information

## Basic Error Testing

### Testing Expected Errors

When errors are expected and should occur:

```gctf
--- ENDPOINT ---
user.UserService/GetUser

--- REQUEST ---
{ "user_id": "nonexistent" }

--- ERROR ---
{
  "code": 5,
  "message": "User not found",
  "details": "User with ID 'nonexistent' does not exist"
}
```

### Validating Error Responses

Use assertions to validate error details:

```gctf
--- ENDPOINT ---
user.UserService/GetUser

--- REQUEST ---
{ "user_id": "nonexistent" }

--- ASSERTS ---
.code == 5
.message | contains("not found")
.details | contains("does not exist")
```

## Input Validation Testing

### Testing Invalid Input

Test when users provide invalid data:

```gctf
--- ENDPOINT ---
user.UserService/CreateUser

--- REQUEST ---
{
  "name": "",
  "email": "invalid-email",
  "age": -5
}

--- ERROR ---
{
  "code": 3,
  "message": "Invalid input",
  "details": "Name cannot be empty, email format is invalid, age must be positive"
}
```

### Comprehensive Validation Testing

```gctf
--- ENDPOINT ---
user.UserService/CreateUser

--- REQUEST ---
{
  "name": "",
  "email": "not-an-email",
  "age": -1
}

--- ASSERTS ---
.code == 3
.message == "Invalid input"
.details | contains("Name cannot be empty")
.details | contains("email format is invalid")
.details | contains("age must be positive")
```

## Authentication Error Testing

### Testing Missing Authentication

```gctf
--- ENDPOINT ---
secure.UserService/GetProfile

--- REQUEST ---
{ "user_id": "123" }

--- ERROR ---
{
  "code": 16,
  "message": "Unauthenticated",
  "details": "Missing or invalid authentication token"
}
```

### Testing Invalid Tokens

```gctf
--- ENDPOINT ---
secure.UserService/GetProfile

--- REQUEST_HEADERS ---
authorization: Bearer invalid-token

--- REQUEST ---
{ "user_id": "123" }

--- ERROR ---
{
  "code": 16,
  "message": "Unauthenticated",
  "details": "Invalid authentication token"
}
```

## Authorization Error Testing

### Testing Insufficient Permissions

```gctf
--- ENDPOINT ---
admin.UserService/DeleteUser

--- REQUEST_HEADERS ---
authorization: Bearer user-token

--- REQUEST ---
{ "user_id": "123" }

--- ERROR ---
{
  "code": 7,
  "message": "Permission denied",
  "details": "Insufficient permissions to delete users"
}
```

## Resource Not Found Testing

### Testing Missing Resources

```gctf
--- ENDPOINT ---
product.ProductService/GetProduct

--- REQUEST ---
{ "product_id": "nonexistent" }

--- ERROR ---
{
  "code": 5,
  "message": "Product not found",
  "details": "Product with ID 'nonexistent' does not exist"
}
```

### Testing Deleted Resources

```gctf
--- ENDPOINT ---
order.OrderService/GetOrder

--- REQUEST ---
{ "order_id": "deleted_order" }

--- ERROR ---
{
  "code": 5,
  "message": "Order not found",
  "details": "Order has been deleted or does not exist"
}
```

## Rate Limiting Testing

### Testing Rate Limit Exceeded

```gctf
--- ENDPOINT ---
api.SearchService/Search

--- REQUEST ---
{ "query": "test" }

--- ERROR ---
{
  "code": 8,
  "message": "Resource exhausted",
  "details": "Rate limit exceeded. Try again in 60 seconds."
}
```

## Server Error Testing

### Testing Internal Server Errors

```gctf
--- ENDPOINT ---
service.ServiceName/MethodName

--- REQUEST ---
{ "data": "trigger_error" }

--- ERROR ---
{
  "code": 13,
  "message": "Internal server error",
  "details": "An unexpected error occurred"
}
```

## Common Error Codes

### gRPC Status Codes

| Code | Name | Description | Use Case |
|------|------|-------------|----------|
| 0 | OK | Success | Normal operation |
| 1 | CANCELLED | Operation cancelled | Client cancelled request |
| 2 | UNKNOWN | Unknown error | Unexpected server error |
| 3 | INVALID_ARGUMENT | Invalid input | Bad request data |
| 4 | DEADLINE_EXCEEDED | Timeout | Request took too long |
| 5 | NOT_FOUND | Resource not found | Missing data |
| 6 | ALREADY_EXISTS | Resource exists | Duplicate creation |
| 7 | PERMISSION_DENIED | Insufficient permissions | Authorization failure |
| 8 | RESOURCE_EXHAUSTED | Resource limits | Rate limiting, quotas |
| 9 | FAILED_PRECONDITION | Invalid state | Business logic error |
| 10 | ABORTED | Operation aborted | Concurrency conflict |
| 11 | OUT_OF_RANGE | Value out of range | Invalid parameter value |
| 12 | UNIMPLEMENTED | Not implemented | Missing functionality |
| 13 | INTERNAL | Internal error | Server error |
| 14 | UNAVAILABLE | Service unavailable | Service down |
| 15 | DATA_LOSS | Data corruption | Data integrity issue |
| 16 | UNAUTHENTICATED | Not authenticated | Missing/invalid auth |

## Error Testing Patterns

### Pattern 1: Expected Business Logic Errors

```gctf
--- ENDPOINT ---
order.OrderService/CancelOrder

--- REQUEST ---
{ "order_id": "shipped_order" }

--- ERROR ---
{
  "code": 9,
  "message": "Order cannot be cancelled",
  "details": "Order has already been shipped"
}
```

### Pattern 2: Validation Chain Testing

```gctf
--- ENDPOINT ---
user.UserService/UpdateProfile

--- REQUEST ---
{
  "user_id": "123",
  "email": "invalid-email",
  "phone": "not-a-phone"
}

--- ASSERTS ---
.code == 3
.message == "Validation failed"
.details | contains("Invalid email format")
.details | contains("Invalid phone format")
```

### Pattern 3: Conditional Error Testing

```gctf
--- ENDPOINT ---
payment.PaymentService/ProcessPayment

--- REQUEST ---
{
  "amount": 1000,
  "currency": "USD",
  "card_number": "4111111111111111"
}

--- ASSERTS ---
# Test for either success or specific error
if .code == 0 then
  .transaction_id | length > 0
else
  .code == 3 and .message | contains("Invalid")
end
```

## Best Practices

### ✅ Do This:

1. **Test All Error Scenarios**
   ```gctf
   # Test missing required fields
   # Test invalid data types
   # Test out-of-range values
   # Test authentication failures
   # Test authorization failures
   ```

2. **Validate Error Details**
   ```gctf
   --- ASSERTS ---
   .code == 3
   .message | contains("Invalid")
   .details | contains("specific error")
   ```

3. **Test Edge Cases**
   ```gctf
   # Empty strings
   # Null values
   # Very large numbers
   # Special characters
   # Unicode strings
   ```

4. **Use Meaningful Error Messages**
   ```gctf
   # Good
   "Invalid email format: missing @ symbol"
   
   # Bad
   "Validation failed"
   ```

### ❌ Avoid This:

1. **Testing Only Happy Path**
   ```gctf
   # Don't only test success cases
   # Always test error conditions
   ```

2. **Generic Error Messages**
   ```gctf
   # Bad
   .message == "Error occurred"
   
   # Good
   .message | contains("specific error")
   ```

3. **Ignoring Error Codes**
   ```gctf
   # Bad - not checking error code
   .message | contains("error")
   
   # Good - validate specific code
   .code == 3
   .message | contains("Invalid input")
   ```

## Common Error Testing Scenarios

### User Registration Errors
```gctf
--- ENDPOINT ---
auth.AuthService/Register

--- REQUEST ---
{
  "email": "invalid-email",
  "password": "123"
}

--- ASSERTS ---
.code == 3
.message | contains("Invalid email")
.details | contains("password too short")
```

### Payment Processing Errors
```gctf
--- ENDPOINT ---
payment.PaymentService/Charge

--- REQUEST ---
{
  "amount": -100,
  "card_number": "invalid"
}

--- ASSERTS ---
.code == 3
.message | contains("Invalid amount")
.details | contains("Invalid card")
```

### File Upload Errors
```gctf
--- ENDPOINT ---
file.FileService/Upload

--- REQUEST ---
{
  "filename": "",
  "size": 1000000000
}

--- ASSERTS ---
.code == 3
.message | contains("Invalid filename")
.details | contains("File too large")
```

## Next Steps

- **[Security Testing](security-testing)** - Test authentication and authorization
- **[Assertion Patterns](assertion-patterns)** - Master advanced validation techniques
- **[Real Examples](../guides/examples/basic/real-time-chat)** - See error testing in action

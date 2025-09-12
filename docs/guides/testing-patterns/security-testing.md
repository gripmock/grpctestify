# Security Testing

Security testing ensures your gRPC services are protected against unauthorized access, data breaches, and malicious attacks.

## Why Security Testing Matters

Security testing validates:
- ✅ Authentication mechanisms work correctly
- ✅ Authorization rules are enforced
- ✅ Sensitive data is protected
- ✅ TLS encryption is properly configured
- ✅ Input validation prevents attacks

## Authentication Testing

### Testing with Bearer Tokens

```gctf
--- ENDPOINT ---
secure.UserService/GetProfile

--- REQUEST_HEADERS ---
authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

--- REQUEST ---
{ "user_id": "123" }

--- RESPONSE ---
{
  "profile": {
    "id": "123",
    "name": "John Doe",
    "email": "john@example.com"
  }
}
```

### Testing API Key Authentication

```gctf
--- ENDPOINT ---
api.DataService/GetData

--- REQUEST_HEADERS ---
x-api-key: your-secret-api-key-here
x-client-id: client-123

--- REQUEST ---
{ "data_id": "456" }

--- RESPONSE ---
{
  "data": {
    "id": "456",
    "content": "sensitive information"
  }
}
```

### Testing Multiple Authentication Methods

```gctf
--- ENDPOINT ---
secure.AdminService/GetSystemInfo

--- REQUEST_HEADERS ---
authorization: Bearer admin-token
x-api-key: admin-api-key
x-client-version: 1.0.0

--- REQUEST ---
{}

--- RESPONSE ---
{
  "system": {
    "version": "1.0.0",
    "status": "healthy",
    "users_count": 1500
  }
}
```

## Authorization Testing

### Testing Role-Based Access Control (RBAC)

```gctf
--- ENDPOINT ---
admin.UserService/DeleteUser

--- REQUEST_HEADERS ---
authorization: Bearer admin-token
x-role: admin

--- REQUEST ---
{ "user_id": "123" }

--- RESPONSE ---
{
  "status": "deleted",
  "message": "User deleted successfully"
}
```

### Testing Permission Denied Scenarios

```gctf
--- ENDPOINT ---
admin.UserService/DeleteUser

--- REQUEST_HEADERS ---
authorization: Bearer user-token
x-role: user

--- REQUEST ---
{ "user_id": "123" }

--- ERROR ---
{
  "code": 7,
  "message": "Permission denied",
  "details": "Insufficient permissions to delete users"
}
```

### Testing Resource-Level Permissions

```gctf
--- ENDPOINT ---
secure.DocumentService/GetDocument

--- REQUEST_HEADERS ---
authorization: Bearer user-token

--- REQUEST ---
{ "document_id": "private_doc_456" }

--- ERROR ---
{
  "code": 7,
  "message": "Permission denied",
  "details": "You don't have access to this document"
}
```

## TLS/SSL Testing

### Testing with Client Certificates

```gctf
--- TLS ---
ca_cert: ./certs/ca.pem
cert: ./certs/client.pem
key: ./certs/client.key

--- ENDPOINT ---
secure.ServiceName/MethodName

--- REQUEST ---
{ "data": "sensitive" }

--- RESPONSE ---
{
  "result": "authenticated_response"
}
```

### Testing Mutual TLS (mTLS)

```gctf
--- TLS ---
ca_cert: ./certs/ca.pem
cert: ./certs/client.pem
key: ./certs/client.key
insecure: false

--- ENDPOINT ---
secure.AdminService/GetSecrets

--- REQUEST ---
{}

--- RESPONSE ---
{
  "secrets": {
    "api_keys": ["key1", "key2"],
    "passwords": ["hash1", "hash2"]
  }
}
```

## Input Validation Security

### Testing SQL Injection Prevention

```gctf
--- ENDPOINT ---
user.UserService/SearchUsers

--- REQUEST ---
{
  "query": "'; DROP TABLE users; --"
}

--- ERROR ---
{
  "code": 3,
  "message": "Invalid input",
  "details": "Query contains invalid characters"
}
```

### Testing XSS Prevention

```gctf
--- ENDPOINT ---
user.UserService/UpdateProfile

--- REQUEST ---
{
  "user_id": "123",
  "bio": "<script>alert('xss')</script>"
}

--- ERROR ---
{
  "code": 3,
  "message": "Invalid input",
  "details": "Bio contains invalid HTML"
}
```

### Testing Path Traversal Prevention

```gctf
--- ENDPOINT ---
file.FileService/GetFile

--- REQUEST ---
{
  "path": "../../../etc/passwd"
}

--- ERROR ---
{
  "code": 3,
  "message": "Invalid input",
  "details": "Path contains invalid characters"
}
```

## Rate Limiting Testing

### Testing Rate Limit Enforcement

```gctf
--- ENDPOINT ---
api.SearchService/Search

--- REQUEST ---
{ "query": "test" }

--- RESPONSE ---
{
  "results": ["result1", "result2"]
}

# Run this test multiple times quickly to trigger rate limit
```

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

## Session Management Testing

### Testing Session Expiration

```gctf
--- ENDPOINT ---
secure.UserService/GetProfile

--- REQUEST_HEADERS ---
authorization: Bearer expired-token

--- REQUEST ---
{ "user_id": "123" }

--- ERROR ---
{
  "code": 16,
  "message": "Unauthenticated",
  "details": "Token has expired"
}
```

### Testing Session Hijacking Prevention

```gctf
--- ENDPOINT ---
secure.UserService/GetProfile

--- REQUEST_HEADERS ---
authorization: Bearer stolen-token
x-forwarded-for: 192.168.1.100

--- REQUEST ---
{ "user_id": "123" }

--- ERROR ---
{
  "code": 16,
  "message": "Unauthenticated",
  "details": "Suspicious activity detected"
}
```

## Data Protection Testing

### Testing Sensitive Data Masking

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
    "email": "j***@example.com",
    "phone": "***-***-1234"
  }
}
```

### Testing Data Encryption

```gctf
--- ENDPOINT ---
secure.PaymentService/ProcessPayment

--- REQUEST ---
{
  "card_number": "4111111111111111",
  "cvv": "123",
  "amount": 100
}

--- RESPONSE ---
{
  "transaction": {
    "id": "txn_123",
    "status": "success",
    "card_last4": "1111"
  }
}
```

## Security Headers Testing

### Testing Security Headers

```gctf
--- ENDPOINT ---
secure.ServiceName/MethodName

--- REQUEST_HEADERS ---
authorization: Bearer valid-token

--- REQUEST ---
{}

--- RESPONSE ---
{
  "result": "success"
}

# Verify response headers contain:
# - X-Content-Type-Options: nosniff
# - X-Frame-Options: DENY
# - X-XSS-Protection: 1; mode=block
# - Strict-Transport-Security: max-age=31536000
```

## Common Security Testing Patterns

### Pattern 1: Authentication Chain Testing

```gctf
# Test 1: No authentication
--- ENDPOINT ---
secure.ServiceName/MethodName
--- REQUEST --- {}
--- ERROR --- { "code": 16, "message": "Unauthenticated" }

# Test 2: Invalid token
--- ENDPOINT ---
secure.ServiceName/MethodName
--- REQUEST_HEADERS ---
authorization: Bearer invalid-token
--- REQUEST --- {}
--- ERROR --- { "code": 16, "message": "Invalid token" }

# Test 3: Valid authentication
--- ENDPOINT ---
secure.ServiceName/MethodName
--- REQUEST_HEADERS ---
authorization: Bearer valid-token
--- REQUEST --- {}
--- RESPONSE --- { "result": "success" }
```

### Pattern 2: Authorization Matrix Testing

```gctf
# Test different roles for the same endpoint
# Admin role
--- REQUEST_HEADERS ---
authorization: Bearer admin-token
x-role: admin
--- RESPONSE --- { "result": "full_access" }

# User role  
--- REQUEST_HEADERS ---
authorization: Bearer user-token
x-role: user
--- ERROR --- { "code": 7, "message": "Permission denied" }

# Guest role
--- REQUEST_HEADERS ---
authorization: Bearer guest-token
x-role: guest
--- ERROR --- { "code": 16, "message": "Unauthenticated" }
```

### Pattern 3: Input Sanitization Testing

```gctf
# Test various malicious inputs
--- REQUEST ---
{ "input": "<script>alert('xss')</script>" }
--- ERROR --- { "code": 3, "message": "Invalid input" }

--- REQUEST ---
{ "input": "'; DROP TABLE users; --" }
--- ERROR --- { "code": 3, "message": "Invalid input" }

--- REQUEST ---
{ "input": "../../../etc/passwd" }
--- ERROR --- { "code": 3, "message": "Invalid input" }
```

## Best Practices

### ✅ Do This:

1. **Test All Authentication Methods**
   ```gctf
   # Test Bearer tokens
   # Test API keys
   # Test client certificates
   # Test session tokens
   ```

2. **Test Authorization Thoroughly**
   ```gctf
   # Test all user roles
   # Test resource-level permissions
   # Test cross-user access
   ```

3. **Validate Security Headers**
   ```gctf
   # Check for security headers
   # Verify TLS configuration
   # Test certificate validation
   ```

4. **Test Input Validation**
   ```gctf
   # Test SQL injection attempts
   # Test XSS attempts
   # Test path traversal
   # Test buffer overflow attempts
   ```

### ❌ Avoid This:

1. **Testing Only Happy Path**
   ```gctf
   # Don't only test successful authentication
   # Always test failure scenarios
   ```

2. **Using Real Credentials**
   ```gctf
   # Bad - using real tokens
   authorization: Bearer real-production-token
   
   # Good - using test tokens
   authorization: Bearer test-token-123
   ```

3. **Ignoring Error Details**
   ```gctf
   # Bad - generic error checking
   .code == 16
   
   # Good - specific error validation
   .code == 16
   .message | contains("Invalid token")
   .details | contains("expired")
   ```

## Security Testing Checklist

- [ ] **Authentication Testing**
  - [ ] Valid credentials work
  - [ ] Invalid credentials fail
  - [ ] Expired tokens fail
  - [ ] Missing tokens fail

- [ ] **Authorization Testing**
  - [ ] Role-based access works
  - [ ] Resource-level permissions work
  - [ ] Cross-user access is blocked
  - [ ] Admin privileges work

- [ ] **TLS/SSL Testing**
  - [ ] Client certificates work
  - [ ] Certificate validation works
  - [ ] Invalid certificates fail
  - [ ] TLS version is secure

- [ ] **Input Validation**
  - [ ] SQL injection is blocked
  - [ ] XSS is blocked
  - [ ] Path traversal is blocked
  - [ ] Buffer overflow is prevented

- [ ] **Rate Limiting**
  - [ ] Rate limits are enforced
  - [ ] Rate limit exceeded errors work
  - [ ] Rate limit reset works

- [ ] **Data Protection**
  - [ ] Sensitive data is masked
  - [ ] Data is encrypted
  - [ ] Audit logs are created

## Next Steps

- **[Performance Testing](performance-testing)** - Test security under load
- **[Assertion Patterns](assertion-patterns)** - Master security validation techniques
- **[Real Examples](../guides/examples/basic/real-time-chat)** - See security testing in action

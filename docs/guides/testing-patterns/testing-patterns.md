# Testing Patterns

gRPC Testify uses a universal `.gctf` format that works with all gRPC communication patterns. The same testing principles apply regardless of whether you're testing unary, streaming, or bidirectional services.

## Universal Testing Principles

The `.gctf` format handles all gRPC patterns consistently across different types:

- **Request-Response Validation** - Verify correct data exchange
- **Error Handling** - Test both success and failure scenarios  
- **Performance Monitoring** - Ensure acceptable response times
- **Security Validation** - Test authentication and authorization
- **Data Integrity** - Validate response structure and content

## Core Testing Categories

### 🔍 [Data Validation](data-validation)
Learn how to validate response data, test different data types, and handle complex nested structures.

### ❌ [Error Testing](error-testing) 
Master testing error conditions, validation failures, and expected error scenarios.

### 🔐 [Security Testing](security-testing)
Test authentication, authorization, TLS certificates, and secure endpoints.

### ⚡ [Performance Testing](performance-testing)
Validate response times, test under load, and optimize test execution.

### 🎯 [Assertion Patterns](assertion-patterns)
Master universal assertion techniques for all gRPC types and data structures.

## gRPC Type-Specific Considerations

### Unary RPC
- One request → One response
- Use `RESPONSE` OR `ASSERTS` (not both)
- Simple validation patterns

### Server Streaming  
- One request → Multiple responses
- Use multiple `ASSERTS` sections
- Validate each response in sequence

### Client Streaming
- Multiple requests → One response  
- Use multiple `REQUEST` sections
- Validate final response

### Bidirectional Streaming
- Multiple requests ↔ Multiple responses
- Use multiple `REQUEST` and `ASSERTS` sections
- Complex validation patterns

## Quick Reference

### Basic Test Structure
```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
service.ServiceName/MethodName

--- REQUEST ---
{ "input": "test_data" }

--- RESPONSE ---
{
  "result": "expected_response",
  "status": "success"
}
```

### Common OPTIONS
```gctf
--- OPTIONS ---
timeout: 30          # Test timeout in seconds
timeout: 30  # Test timeout in seconds
retry: 3             # Number of retry attempts
```

## Next Steps

Explore the detailed guides above to master each testing category:

- **[Data Validation](data-validation)** - Start here for basic testing
- **[Error Testing](error-testing)** - Handle failure scenarios  
- **[Security Testing](security-testing)** - Test secure endpoints
- **[Performance Testing](performance-testing)** - Optimize and monitor
- **[Assertion Patterns](assertion-patterns)** - Master validation techniques

Ready to test your gRPC services? Start with [Data Validation](data-validation) or explore [Real Examples](../guides/examples/basic/user-management)!

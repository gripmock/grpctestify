# Performance Testing

Performance testing in gRPC Testify focuses on validating response times and handling timeouts for individual tests.

## What's Supported

gRPC Testify supports these performance testing features:
- ✅ **Timeout Configuration** - Set maximum time for individual tests
- ✅ **Retry Mechanism** - Configure retries for failed network calls
- ✅ **Response Time Validation** - Basic timeout enforcement

## Timeout Testing

### Setting Test Timeout

Configure timeout for individual tests:

```gctf
--- ENDPOINT ---
service.ServiceName/MethodName

--- REQUEST ---
{ "data": "test" }

--- RESPONSE ---
{
  "result": "success"
}

--- OPTIONS ---
timeout: 5
```

### Testing Slow Responses

Test that slow responses are properly handled:

```gctf
--- ENDPOINT ---
service.ServiceName/SlowMethod

--- REQUEST ---
{ "delay": 3000 }

--- ERROR ---
{
  "code": 4,
  "message": "Deadline exceeded",
  "details": "Request timed out"
}

--- OPTIONS ---
timeout: 2
```

## Retry Configuration

### Basic Retry Setup

Configure retry attempts for network failures:

```gctf
--- ENDPOINT ---
service.ServiceName/MethodName

--- REQUEST ---
{ "data": "test" }

--- RESPONSE ---
{
  "result": "success"
}

--- OPTIONS ---
timeout: 10
retry: 3
retry_delay: 1
```

### Disabling Retries

For tests that should fail immediately:

```gctf
--- ENDPOINT ---
service.ServiceName/MethodName

--- REQUEST ---
{ "data": "test" }

--- RESPONSE ---
{
  "result": "success"
}

--- OPTIONS ---
timeout: 5
retry: 0
```

## CLI Performance Options

### Global Timeout

Set timeout for all tests via command line:

```bash
# Set 30 second timeout for all tests
grpctestify.sh tests/ --timeout 30

# Set 60 second timeout for specific test
grpctestify.sh test.gctf --timeout 60
```

### Global Retry Configuration

Configure retry behavior globally:

```bash
# Set 5 retries with 2 second delay
grpctestify.sh tests/ --retry 5 --retry-delay 2

# Disable retries completely
grpctestify.sh tests/ --no-retry
```

### Parallel Execution

Run multiple test files in parallel:

```bash
# Auto-detect optimal parallel jobs
grpctestify.sh tests/ --parallel auto

# Use 4 parallel workers
grpctestify.sh tests/ --parallel 4
```

## Real Examples

### Timeout Test

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
shopflow.ShopFlowService/HealthCheck

--- REQUEST ---
{
    "service": "shopflow-ecommerce"
}

--- ASSERTS ---
.status == "healthy"
.message | test("ShopFlow")

--- OPTIONS ---
timeout: 2
```

### Retry Test

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
shopflow.ShopFlowService/GetProduct

--- REQUEST ---
{
    "product_id": "prod_001"
}

--- ASSERTS ---
.found == true
.product.id == "prod_001"
.product.name == "Wireless Bluetooth Headphones"

--- OPTIONS ---
timeout: 10
retry: 3
retry_delay: 1
```

## Best Practices

### ✅ Do This:

1. **Set Reasonable Timeouts**
   ```gctf
   --- OPTIONS ---
   timeout: 30  # 30 seconds for normal operations
   ```

2. **Configure Retries for Network Tests**
   ```gctf
   --- OPTIONS ---
   timeout: 10
   retry: 3
   retry_delay: 1
   ```

3. **Use Global Options for Consistency**
   ```bash
   grpctestify.sh tests/ --timeout 30 --retry 3
   ```

### ❌ Avoid This:

1. **Setting Unrealistic Timeouts**
   ```gctf
   # Bad - too short
   timeout: 1
   
   # Bad - too long
   timeout: 3600
   ```

2. **Excessive Retries**
   ```gctf
   # Bad - too many retries
   retry: 100
   
   # Good - reasonable retries
   retry: 3
   ```

## Limitations

### What's NOT Supported

- ❌ **Response Time Assertions** - Cannot validate specific response times
- ❌ **Load Testing** - No built-in load testing capabilities
- ❌ **Performance Metrics** - No detailed performance reporting
- ❌ **Concurrent Test Execution** - Tests run sequentially within files

### Workarounds

For advanced performance testing:

1. **Use External Tools**
   ```bash
   # Use Apache Bench or similar for load testing
   ab -n 1000 -c 10 http://localhost:8080/
   ```

2. **Custom Performance Scripts**
   ```bash
   # Create custom performance test scripts
   for i in {1..100}; do
     grpctestify.sh test.gctf
   done
   ```

## Next Steps

- **[Data Validation](data-validation)** - Learn basic testing patterns
- **[Error Testing](error-testing)** - Test error conditions
- **[Real Examples](../guides/examples/basic/real-time-chat)** - See performance testing in action

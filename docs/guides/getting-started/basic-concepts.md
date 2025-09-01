# Basic Concepts

Understand the fundamental concepts of gRPC testing with gRPC Testify.

## 🎯 What is gRPC Testify?

gRPC Testify is a testing framework designed specifically for gRPC services. It allows you to:

- **Write tests** using simple `.gctf` files
- **Validate responses** with powerful jq-based assertions
- **Test all gRPC patterns** - unary, streaming, and bidirectional
- **Integrate with CI/CD** for automated testing
- **Extend functionality** with custom plugins

## 📋 Core Concepts

### Test Files (.gctf)

gRPC Testify uses `.gctf` (gRPC Test File) format for defining tests:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
service.Method

--- REQUEST ---
{
  "key": "value"
}

--- RESPONSE ---
{
  "result": "success"
}

--- ASSERTS ---
.result == "success"
```

### Test Sections

Each test file consists of several sections:

#### Required Sections
- **ADDRESS** - gRPC server location
- **ENDPOINT** - Service and method to call

#### Optional Sections
- **REQUEST** - Data to send to the server
- **RESPONSE** - Expected response from server
- **ERROR** - Expected error response
- **ASSERTS** - Validation rules
- **OPTIONS** - Test configuration
- **TLS** - Security settings
- **REQUEST_HEADERS** - Custom headers

## 🔄 gRPC Patterns

### Unary RPC
Simple request-response pattern:

```gctf
--- ENDPOINT ---
user.UserService/GetUser

--- REQUEST ---
{
  "user_id": "123"
}

--- RESPONSE ---
{
  "user": {
    "id": "123",
    "name": "John Doe"
  }
}
```

### Client Streaming
Multiple requests, single response:

```gctf
--- ENDPOINT ---
file.FileService/UploadFile

--- REQUEST ---
{
  "chunk": 1,
  "data": "chunk1"
}

--- REQUEST ---
{
  "chunk": 2,
  "data": "chunk2"
}

--- RESPONSE ---
{
  "uploaded": true
}
```

### Server Streaming
Single request, multiple responses:

```gctf
--- ENDPOINT ---
monitor.MonitorService/StreamMetrics

--- REQUEST ---
{
  "duration": 60
}

--- ASSERTS ---
.metric > 0

--- ASSERTS ---
.metric > 0
```

### Bidirectional Streaming
Multiple requests and responses:

```gctf
--- ENDPOINT ---
chat.ChatService/Chat

--- REQUEST ---
{
  "message": "Hello"
}

--- ASSERTS ---
.response | contains("Hello")

--- REQUEST ---
{
  "message": "How are you?"
}

--- ASSERTS ---
.response | contains("fine")
```

## 🎯 Assertions

### Basic Assertions
Validate response data using jq expressions:

```gctf
--- ASSERTS ---
.status == "success"                    # String equality
.count > 0                              # Numeric comparison
.active == true                         # Boolean check
.items | length == 3                    # Array length
.user.name | type == "string"           # Type validation
```

### Advanced Assertions
Use jq functions for complex validation:

```gctf
--- ASSERTS ---
.message | contains("success")          # Contains substring
.email | test("@.*\\.")                 # Regex pattern
.timestamp | strptime("%Y-%m-%d")      # Date parsing
.values | map(. > 0) | all              # Array validation
```

### Header and Trailer Assertions
Validate gRPC metadata:

```gctf
--- ASSERTS ---
@header("x-response-time") < 1000       # Response header
@trailer("x-processing-time") > 0       # Response trailer
```

## ⚙️ Configuration

### Environment Variables
Set global configuration:

```bash
export GRPCTESTIFY_ADDRESS="localhost:4770"
# Use CLI flags instead of environment variables for these options:
# --parallel 4
# --timeout 30
export GRPCTESTIFY_LOG_LEVEL="info"
```

### Test Options
Configure individual tests:

```gctf
--- OPTIONS ---
timeout: 60
parallel: 2
retry: 3
```

## 🔒 Security

### TLS Configuration
Secure connections with certificates:

```gctf
--- TLS ---
ca_cert: ./certs/ca.pem
cert: ./certs/client.pem
key: ./certs/client-key.pem
server_name: api.example.com
```

### Authentication Headers
Add custom headers for authentication:

```gctf
--- REQUEST_HEADERS ---
authorization: Bearer token123
x-api-key: key456
```

## 📊 Test Execution

### Running Tests
Execute tests with various options:

```bash
# Run single test
./grpctestify.sh test.gctf

# Run multiple tests
./grpctestify.sh tests/*.gctf

# Run with options
./grpctestify.sh --parallel 4 tests/*.gctf

# Run with verbose output
./grpctestify.sh --verbose tests/*.gctf
```

### Test Results
Understand test output:

```
✓ TEST PASSED: user_test.gctf (45ms)
✗ TEST FAILED: auth_test.gctf (23ms)
⚠ TEST SKIPPED: maintenance_test.gctf
```

## 🔌 Plugin System

### Built-in Plugins
gRPC Testify includes several built-in plugins:

- **Validation** - Data validation helpers
- **Reporting** - Custom report formats
- **Utilities** - Common testing utilities

### Custom Plugins
Extend functionality with custom plugins:

```gctf
--- ASSERTS ---
@plugin("custom", "validate_email", .user.email) == "VALID"
@plugin("business", "check_balance", .account.balance) > 0
```

## 📈 Performance

### Parallel Execution
Run tests concurrently:

```bash
./grpctestify.sh --parallel 8 tests/*.gctf
```

### Performance Assertions
Validate response times:

```gctf
--- ASSERTS ---
@header("x-response-time") | tonumber < 1000
```

## 🚀 Best Practices

### 1. Test Organization
Organize tests logically:

```
tests/
├── unit/           # Unit tests
├── integration/    # Integration tests
├── e2e/           # End-to-end tests
└── performance/   # Performance tests
```

### 2. Naming Conventions
Use descriptive names:

```
user_creation_success_test.gctf
user_creation_validation_error_test.gctf
payment_processing_timeout_test.gctf
```

### 3. Assertion Strategy
Write meaningful assertions:

```gctf
# Good - specific validation
.user.id | type == "string"
.user.email | test("@.*\\.")
.user.age >= 18

# Avoid - too generic
.success == true
```

### 4. Error Handling
Test error conditions:

```gctf
--- ERROR ---
{
  "code": 3,
  "message": "Invalid input"
}

--- ASSERTS ---
.code == 3
.message | contains("Invalid")
```

## 🔗 Related Topics

- **[Installation](installation.md)** - Set up gRPC Testify
- **[First Test](first-test.md)** - Write your first test
- **[Testing Patterns](../testing-patterns/testing-patterns)** - Learn different test patterns
- **[Advanced Features](../testing-patterns/testing-patterns)** - Master advanced features
- **[API Reference](../reference/)** - Complete technical documentation

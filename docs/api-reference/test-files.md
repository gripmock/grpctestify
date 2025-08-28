# Test File Format

Complete specification of the `.gctf` (gRPC Testify Configuration File) format.

## File Structure

A `.gctf` file consists of sections separated by `--- SECTION_NAME ---` markers:

```php
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
service.Method

--- REQUEST ---
{
  "field": "value"
}

--- RESPONSE ---
{
  "result": "*"
}

--- ASSERTS ---
.result | length > 0
```

## Core Sections

### ADDRESS
**Required**: Server address for gRPC connection.

```php
--- ADDRESS ---
localhost:4770
```

- **Format**: `host:port`
- **Examples**: `api.example.com:443`, `127.0.0.1:9090`
- **Environment Override**: `GRPCTESTIFY_ADDRESS`

### ENDPOINT  
**Required**: gRPC service method to call.

```php
--- ENDPOINT ---
package.ServiceName/MethodName
```

- **Format**: `package.Service/Method`
- **Examples**: `user.UserService/CreateUser`, `chat.ChatService/SendMessage`

### REQUEST
**Required**: JSON request payload.

```php
--- REQUEST ---
{
  "username": "alice",
  "email": "alice@example.com"
}
```

- **Format**: Valid JSON object
- **Wildcards**: Use `"*"` for generated/dynamic values
- **Comments**: `// Comment` (stripped during processing)

### RESPONSE
**Optional**: Expected response structure for validation.

```php
--- RESPONSE ---
{
  "user": {
    "id": "*",
    "username": "alice"
  },
  "success": true
}
```

- **Wildcards**: `"*"` matches any value
- **Partial matching**: Only specified fields are validated
- **Type validation**: JSON types must match

#### RESPONSE Inline Modifiers

You can add inline modifiers to the RESPONSE section header for additional behavior:

```php
--- RESPONSE with_asserts ---
{"message": "Hello, test!"}

--- ASSERTS ---
.message | test("Hello.*test")
@header("content-type") == "application/grpc"
```

**Available modifiers:**

- **`with_asserts`** (or `with_asserts=true`): After validating the exact RESPONSE match, also run the ASSERTS section against the same response. This is useful when you want both exact JSON matching and additional header/metadata validation.

**Other supported inline options:**
- **`type=exact`** (default): Exact JSON comparison
- **`type=partial`**: Only validate specified fields
- **`tolerance[.path]=0.1`**: Numeric tolerance for specific paths
- **`redact=field1,field2`**: Remove sensitive fields before comparison
- **`unordered_arrays=true`**: Sort arrays before comparison
- **`unordered_arrays_paths=.field1,.field2`**: Sort specific array paths

Example with multiple modifiers:
```php
--- RESPONSE with_asserts type=exact tolerance[.metrics.value]=0.01 ---
{
  "message": "Success",
  "metrics": {
    "value": 42.5
  }
}

--- ASSERTS ---
@header("x-processing-time") | tonumber < 1000
```

## Advanced Sections

### ASSERTS
**Optional**: jq-based assertions for response validation.

**Note**: `--- ASSERT ---` (singular) has been removed. Use `--- ASSERTS ---` (plural) instead.

#### Multiple Response Assertions (Server Streaming)
```php
--- ASSERTS ---
.status == "VALIDATION"
.message | contains("Validating")
.progress >= 0

--- ASSERTS ---
.status == "PROCESSING"  
.message | contains("Processing")
.progress >= 50

--- ASSERTS ---
.status == "COMPLETED"
.message | contains("Completed")
.progress == 100
```

**Use Cases**:
- Server streaming with multiple status updates
- Payment processing stages
- File upload progress
- Alert escalation workflows
- Real-time monitoring updates

#### Assertion Operators
- **Equality**: `== "value"`, `!= "value"`
- **Comparison**: `> 10`, `>= 5`, `< 100`, `<= 50`
- **String operations**: `contains("text")`, `startswith("prefix")`, `endswith("suffix")`
- **Pattern matching**: `test("regex_pattern")`
- **Array operations**: `length`, `empty`, `.[0]`
- **Type checking**: `type == "string"`

### TLS
**Optional**: TLS/mTLS configuration for secure connections.

#### Basic TLS (Server Authentication Only)
```php
--- TLS ---
ca_cert: ./path/to/ca-cert.pem
server_name: api.example.com
insecure_skip_verify: false
```

#### Mutual TLS (mTLS with Client Authentication)
```php
--- TLS ---
ca_cert: ./../server/tls/ca-cert.pem
cert: ./../server/tls/client-cert.pem
key: ./../server/tls/client-key.pem
server_name: localhost
insecure_skip_verify: false
```

**Parameters**:
- **ca_cert**: Path to CA certificate file (relative to .gctf file)
- **cert**: Path to client certificate file
- **key**: Path to client private key file  
- **server_name**: Expected server name in certificate
- **insecure_skip_verify**: Skip certificate verification (testing only)

**Relative Paths**: All paths are relative to the `.gctf` file location:
- `./certs/ca.pem` - Same directory
- `./../server/tls/ca.pem` - Parent directory navigation
- `./../../shared/certs/ca.pem` - Multiple level navigation

### ERROR
**Optional**: Expected error response validation.

```php
--- ERROR ---
{
  "code": 5,
  "message": "User not found",
  "details": []
}
```

- **code**: gRPC status code (0-16)
- **message**: Error message pattern
- **details**: Additional error details

### HEADERS
**Optional**: Custom gRPC metadata/headers.

```php
--- HEADERS ---
{
  "authorization": "Bearer token123",
  "x-api-key": "secret",
  "x-request-id": "req_001"
}
```

### REQUEST_HEADERS
**Optional**: Custom request headers for gRPC calls.

```php
--- REQUEST_HEADERS ---
{
  "authorization": "Bearer token123",
  "x-api-key": "secret",
  "x-request-id": "req_001"
}
```

### Headers/Trailers Plugin System
**Modern approach**: Use plugin syntax for response header and trailer validation.

#### Header Validation
```php
--- ASSERTS ---
.success == true
@header("x-response-time") == "150ms"
@header("x-server-version") == "1.0.0"
@header("x-request-id") | test("req-.*")
```

#### Trailer Validation
```php
--- ASSERTS ---
.success == true
@trailer("x-processing-time") == "45ms"
@trailer("x-cache-hit") == "false"
@trailer("x-rate-limit-remaining") | test("[0-9]+")
```

**Plugin Syntax**:
- `@header("name") == "value"` - Exact header value match
- `@header("name") | test("pattern")` - Header value pattern matching
- `@trailer("name") == "value"` - Exact trailer value match  
- `@trailer("name") | test("pattern")` - Trailer value pattern matching

**Benefits**:
- More flexible than separate RESPONSE_HEADERS/RESPONSE_TRAILERS sections
- Integrated with plugin system for consistency
- Supports both exact matching and regex patterns
- Can be combined with other assertions in ASSERTS section

### Legacy Headers/Trailers (REMOVED)
**Note**: The following sections have been removed. Use `@header()` and `@trailer()` assertions instead.

```php
# ❌ REMOVED - Use @header()/@trailer() instead
--- RESPONSE_HEADERS ---
--- RESPONSE_TRAILERS ---

# ✅ Use this instead:
--- ASSERTS ---
@header("x-response-time") | test("\\d+ms")
@trailer("x-execution-time") | test("\\d+ms")
```

### OPTIONS
**Optional**: Test execution options.

```php
--- OPTIONS ---
timeout: 30
tolerance: 0.1
partial: true
redact: ["password", "token"]
```

## Advanced Examples

### Payment Processing with Multiple Status Updates
```php
--- ENDPOINT ---
payment.PaymentService/ProcessPayment

--- REQUEST ---
{
  "payment_id": "pay_12345"
}

--- ASSERTS ---
.status == "VALIDATION"
.progress_percentage <= 20

--- ASSERTS ---
.status == "PROCESSING"  
.progress_percentage >= 20
.progress_percentage <= 80

--- ASSERTS ---
.status == "COMPLETED"
.progress_percentage == 100
```

### Secure File Upload with TLS
```php
--- TLS ---
ca_cert: ./../server/tls/ca-cert.pem
cert: ./../server/tls/client-cert.pem
key: ./../server/tls/client-key.pem
server_name: localhost

--- ENDPOINT ---
files.FileService/SecureUpload

--- REQUEST ---
{
  "filename": "document.pdf",
  "encryption": "AES256"
}

--- ASSERTS ---
.status == "ENCRYPTED"
.file_id | test("secure_.*")
```

### Alert Escalation Workflow
```php
--- ENDPOINT ---
monitoring.AlertService/ProcessAlert

--- ASSERTS ---
.stage == "RECEIVED"
.processing_time < 1000

--- ASSERTS ---
.stage == "CORRELATION"
.related_alerts | length >= 0

--- ASSERTS ---
.stage == "ESCALATION"
.escalation_level == 2
```

### Headers/Trailers Validation with Plugin System
```php
--- ENDPOINT ---
shopflow.ShopFlowService/CreateProduct

--- REQUEST ---
{
  "name": "Test Product with Headers",
  "description": "Product to test response headers and trailers",
  "price": 99.99,
  "currency": "USD",
  "stock_quantity": 10,
  "categories": ["Test"],
  "sku": "TEST-001"
}

--- ASSERTS ---
.success == true
.product.id | type == "string"
.product.name == "Test Product with Headers"
.product.price == 99.99
@header("x-response-time") == "150ms"
@header("x-server-version") == "1.0.0"
@header("x-request-id") == "req-12345"
@trailer("x-processing-time") == "45ms"
@trailer("x-cache-hit") == "false"
@trailer("x-rate-limit-remaining") == "999"
```

## Validation Rules

### JSON Validation
- All JSON must be valid and parseable
- Comments are stripped before parsing
- Trailing commas are not allowed

### Path Resolution
- Relative paths start from `.gctf` file location
- Use forward slashes `/` for cross-platform compatibility
- Tilde `~` expansion not supported in relative paths

### Variable Substitution
- Environment variables: `${ENV_VAR}` or `$ENV_VAR`
- Built-in variables: `${TIMESTAMP}`, `${UUID}`, `${RANDOM}`

## Best Practices

### File Organization
```
tests/
├── auth/
│   ├── login.gctf
│   ├── logout.gctf
│   └── refresh_token.gctf
├── users/
│   ├── create_user.gctf
│   ├── get_user.gctf
│   └── update_user.gctf
└── shared/
    └── tls/
        ├── ca-cert.pem
        ├── client-cert.pem
        └── client-key.pem
```

### Naming Conventions
- Use descriptive filenames: `user_creation_success.gctf`
- Group related tests in directories
- Use consistent prefixes: `error_`, `success_`, `tls_`

### Security
- Never commit private keys to version control
- Use environment variables for sensitive data
- Rotate test certificates regularly
- Use `insecure_skip_verify: true` only for testing

## Common Patterns

### Error Testing
```php
--- REQUEST ---
{
  "invalid_field": "value"
}

--- ERROR ---
{
  "code": 3,
  "message": "invalid argument"
}
```

### Performance Testing
```php
--- OPTIONS ---
timeout: 5

--- ASSERTS ---
.processing_time_ms < 1000
```

### Authentication Testing
```php
--- HEADERS ---
{
  "authorization": "Bearer ${API_TOKEN}"
}

--- ASSERTS ---
.authenticated == true
```

## See Also

- [Command Line Interface](./command-line)
- [Assertions Guide](./assertions)
- [Examples](../examples/)

# Basic Concepts

This guide explains the fundamental concepts you need to understand to effectively use gRPC Testify.

## 🎯 Core Concepts

### Test Files (.gctf)

gRPC Testify uses `.gctf` (gRPC Test Format) files to define tests. These files are human-readable and contain all the information needed to test a gRPC service.

**Key Characteristics:**
- **Human-readable**: Easy to write and understand
- **Self-contained**: Each file contains all test information
- **Version-controlled**: Can be tracked in Git
- **Portable**: Work across different environments

### Test Structure

Every `.gctf` file follows a consistent structure:

```php
# Test Description
# Additional comments

--- ADDRESS ---
server:port

--- ENDPOINT ---
package.Service/Method

--- REQUEST ---
{
    "field": "value"
}

--- RESPONSE ---
{
    "field": "expected_value"
}

--- ASSERTS ---
.field == "expected_value"

--- OPTIONS ---
timeout: 30
```

## 🔧 Test Components

### ADDRESS Section

Specifies where the gRPC server is running.

```php
--- ADDRESS ---
localhost:4770
```

**Supported Formats:**
- `localhost:4770` - Local server
- `192.168.1.100:8080` - IP address
- `api.example.com:443` - Domain name
- `unix:///tmp/grpc.sock` - Unix socket

### ENDPOINT Section

Defines the gRPC service and method to call.

```php
--- ENDPOINT ---
helloworld.Greeter/SayHello
```

**Format:** `package.Service/Method`
- **package**: Protobuf package name
- **Service**: Service name from .proto file
- **Method**: Method name from .proto file

### REQUEST Section

Contains the request payload sent to the gRPC service.

```php
--- REQUEST ---
{
    "name": "Alice",
    "age": 30,
    "active": true
}
```

**Requirements:**
- Must be valid JSON
- Fields must match protobuf message definition
- Can include nested objects and arrays

### RESPONSE Section

Defines the expected response from the gRPC service.

```php
--- RESPONSE ---
{
    "message": "Hello Alice",
    "timestamp": "2024-01-15T10:00:00Z",
    "user": {
        "id": "12345",
        "name": "Alice"
    }
}
```

**Purpose:**
- Documents expected response structure
- Used for validation
- Helps with test maintenance

### ASSERTS Section

Contains validation rules for the response.

```php
--- ASSERTS ---
.message == "Hello Alice"
.user.id | type == "string"
.timestamp | test("\\d{4}-\\d{2}-\\d{2}")
```

**Features:**
- JSONPath expressions for field access
- Rich assertion functions
- Multiple assertions per test
- Flexible validation rules

### OPTIONS Section

Configures test execution behavior.

```php
--- OPTIONS ---
timeout: 30
tolerance: 0.1
partial: true
redact: ["password", "token"]
```

## 🎨 Assertion Language

### Basic Assertions

#### Equality
```php
.field == "value"
.number == 42
.boolean == true
```

#### Type Checking
```php
.field | type == "string"
.number | type == "number"
.array | type == "array"
```

#### Length Validation
```php
.string | length > 0
.array | length == 3
.object | length >= 1
```

### Advanced Assertions

#### Pattern Matching
```php
.email | test("@")
.phone | test("\\+1-\\d{3}-\\d{3}-\\d{4}")
.url | test("https://")
```

#### Array Operations
```php
.items[0].name == "First"
.users | length >= 1
.tags | contains("important")
```

#### Nested Object Access
```php
.user.profile.name == "John"
.response.data.items[0].id == "item_001"
.metadata["key"] == "value"
```

### Assertion Functions

| Function | Description | Example |
|----------|-------------|---------|
| `type` | Check data type | `.field \| type == "string"` |
| `length` | Get length/size | `.array \| length == 3` |
| `test` | Regex matching | `.email \| test("@")` |
| `contains` | Array contains value | `.tags \| contains("urgent")` |
| `keys` | Get object keys | `.object \| keys \| length == 2` |
| `values` | Get object values | `.object \| values \| length == 2` |

## 🔄 Test Execution

### Execution Flow

1. **Parse Test File**: Read and validate .gctf file
2. **Connect to Server**: Establish gRPC connection
3. **Send Request**: Execute the gRPC call
4. **Receive Response**: Get response from server
5. **Validate Response**: Run assertions
6. **Report Results**: Show pass/fail status

### Execution Modes

#### Single Test
```bash
./grpctestify.sh test.gctf
```

#### Directory of Tests
```bash
./grpctestify.sh tests/
```

#### Parallel Execution
```bash
./grpctestify.sh tests/ --parallel 4
```

## 📊 Test Results

### Result Types

#### ✅ PASSED
- All assertions passed
- Response matches expectations
- No errors occurred

#### ❌ FAILED
- One or more assertions failed
- Response doesn't match expectations
- Validation errors

#### ⚠️ ERROR
- Connection failed
- Server error
- Test file parsing error

### Result Information

Each test result includes:
- **Status**: PASSED, FAILED, or ERROR
- **Duration**: Time taken to execute
- **Assertions**: Number of assertions run
- **Details**: Specific failure information

## 🎯 Test Categories

### Unary Tests

Test simple request-response patterns:

```php
--- ENDPOINT ---
user.UserService/GetUser

--- REQUEST ---
{
    "user_id": "12345"
}

--- RESPONSE ---
{
    "user": {
        "id": "12345",
        "name": "John Doe"
    }
}
```

### Streaming Support

> **Fully Implemented**: All gRPC streaming patterns are fully supported and tested.

gRPC Testify supports all streaming patterns:
- **Client Streaming**: Multiple requests, single response
- **Server Streaming**: Single request, multiple responses  
- **Bidirectional Streaming**: Multiple requests and responses
- **Unary**: Single request, single response (traditional)

## 🔧 Configuration

### Command Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `--verbose` | Detailed output | `--verbose` |
| `--parallel N` | Parallel execution | `--parallel 4` |
| `--log-format FORMAT` | Report format (junit, json) | `--log-format junit` |
| `--timeout SECONDS` | Global timeout | `--timeout 60` |
| `--no-color` | Disable colors | `--no-color` |

### Environment Variables

```bash
export GRPCTESTIFY_TIMEOUT=30
export GRPCTESTIFY_PARALLEL=4
export GRPCTESTIFY_PROGRESS=dots
export GRPCTESTIFY_NO_COLOR=false
```

### Configuration File

Create `.grpctestifyrc` in your project root:

```json
{
  "timeout": 30,
  "parallel": 4,
  "progress": "dots",
  "noColor": false,
  "verbose": false
}
```

## 🎨 Best Practices

### Test Organization

1. **Group Related Tests**: Organize tests by feature or service
2. **Use Descriptive Names**: Make test file names clear
3. **Add Comments**: Document complex test logic
4. **Keep Tests Focused**: One test per scenario

### Test Data

1. **Use Realistic Data**: Make tests representative
2. **Avoid Hard-coded Values**: Use variables when possible
3. **Test Edge Cases**: Include boundary conditions
4. **Validate All Fields**: Don't skip important assertions

### Maintenance

1. **Regular Updates**: Keep tests current with API changes
2. **Remove Obsolete Tests**: Clean up unused tests
3. **Monitor Performance**: Track test execution times
4. **Document Changes**: Update test documentation

## 🚀 Next Steps

Now that you understand the basic concepts:

1. **Practice**: Create some simple tests
2. **Explore Examples**: Check out [Examples](../examples/)
3. **Learn Advanced Features**: Read about [Real-time Chat Example](../examples/real-time-chat)
4. **Set Up CI/CD**: Learn about [CI/CD Integration](../development/ci-cd)

---

**Ready to dive deeper?** Explore the [Examples](../examples/) to see these concepts in action!

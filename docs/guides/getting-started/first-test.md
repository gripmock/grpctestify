# Your First Test

Write and run your first gRPC test with step-by-step instructions.

## 🎯 What You'll Learn

In this guide, you'll:
- Create your first `.gctf` test file
- Understand the basic test structure
- Run the test and interpret results
- Learn about test validation

## 📝 Creating Your First Test

### Step 1: Create a Test File

Create a file named `hello_test.gctf`:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
hello.HelloService/SayHello

--- REQUEST ---
{
  "name": "World"
}

--- RESPONSE ---
{
  "message": "Hello, World!"
}

--- ASSERTS ---
.message == "Hello, World!"
```

### Step 2: Understanding the Structure

Let's break down each section:

#### ADDRESS
The gRPC server address and port:
```gctf
--- ADDRESS ---
localhost:4770
```

#### ENDPOINT
The gRPC service and method to call:
```gctf
--- ENDPOINT ---
hello.HelloService/SayHello
```

#### REQUEST
The JSON payload to send:
```gctf
--- REQUEST ---
{
  "name": "World"
}
```

#### RESPONSE
The expected response from the server:
```gctf
--- RESPONSE ---
{
  "message": "Hello, World!"
}
```

#### ASSERTS
Validation rules using jq expressions:
```gctf
--- ASSERTS ---
.message == "Hello, World!"
```

## 🚀 Running Your Test

### Step 3: Start a Test Server

First, you need a gRPC server to test against. You can use any gRPC server, or create a simple one:

```bash
# Clone the examples repository
git clone https://github.com/gripmock/grpctestify.git
cd examples/basic-examples/real-time-chat

# Start GripMock server with stubs
gripmock -s stubs/ &
```

### Step 4: Run the Test

```bash
# Run your test
./grpctestify.sh hello_test.gctf
```

You should see output like:
```
✓ TEST PASSED: hello_test.gctf (45ms)
```

## 📊 Understanding Test Results

### Success Output
```
✓ TEST PASSED: hello_test.gctf (45ms)
```

### Failure Output
```
✗ TEST FAILED: hello_test.gctf (23ms)
--- Expected ---
{
  "message": "Hello, World!"
}
+++ Actual +++
{
  "message": "Hello, Alice!"
}
```

### Error Output
```
✗ TEST ERROR: hello_test.gctf (12ms)
Error: connection refused
```

## 🔧 Adding Assertions

Enhance your test with more sophisticated assertions:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
hello.HelloService/SayHello

--- REQUEST ---
{
  "name": "World"
}

--- RESPONSE ---
{
  "message": "Hello, World!"
}

--- ASSERTS ---
.message == "Hello, World!"
.message | length > 10
.message | contains("Hello")
```

## 🎯 Common Assertion Patterns

### String Validation
```gctf
--- ASSERTS ---
.message == "Hello, World!"           # Exact match
.message | contains("Hello")          # Contains substring
.message | startswith("Hello")        # Starts with
.message | endswith("!")              # Ends with
.message | test("Hello.*World")       # Regex pattern
```

### Numeric Validation
```gctf
--- ASSERTS ---
.count == 5                           # Exact number
.count > 0                            # Greater than
.count >= 1                           # Greater or equal
.count < 100                          # Less than
.count | type == "number"             # Type check
```

### Array and Object Validation
```gctf
--- ASSERTS ---
.items | length == 3                  # Array length
.items[0].id == "item_1"             # Array element
.user.name | type == "string"         # Object property
.success == true                      # Boolean check
```

## 🔄 Testing Different Scenarios

### Test with Variables
```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
hello.HelloService/SayHello

--- REQUEST ---
{
  "name": "Alice"
}

--- RESPONSE ---
{
  "message": "Hello, Alice!"
}

--- ASSERTS ---
.message == "Hello, Alice!"
```

### Test Error Conditions
```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
hello.HelloService/SayHello

--- REQUEST ---
{
  "name": ""
}

--- ERROR ---
{
  "code": 3,
  "message": "Name cannot be empty"
}

--- ASSERTS ---
.code == 3
.message | contains("empty")
```

## 📁 Organizing Your Tests

### Directory Structure
```
tests/
├── unit/
│   ├── hello_test.gctf
│   └── user_test.gctf
├── integration/
│   ├── auth_test.gctf
│   └── payment_test.gctf
└── e2e/
    └── workflow_test.gctf
```

### Running Multiple Tests
```bash
# Run all tests in a directory
./grpctestify.sh tests/unit/*.gctf

# Run tests recursively
./grpctestify.sh tests/**/*.gctf

# Run specific test
./grpctestify.sh tests/unit/hello_test.gctf
```

## 🎓 Best Practices

### 1. Use Descriptive Names
```gctf
# Good
user_creation_success_test.gctf
user_creation_validation_error_test.gctf

# Avoid
test1.gctf
test2.gctf
```

### 2. Keep Tests Focused
```gctf
# Good - single responsibility
--- ENDPOINT ---
user.UserService/CreateUser

# Avoid - multiple operations
--- ENDPOINT ---
user.UserService/CreateUser
# ... then another endpoint
```

### 3. Use Meaningful Assertions
```gctf
# Good - specific validation
.user.id | type == "string"
.user.email | test("@")

# Avoid - too generic
.success == true
```

### 4. Handle Edge Cases
```gctf
# Test empty input
--- REQUEST ---
{}

# Test invalid data
--- REQUEST ---
{
  "email": "invalid-email"
}
```

## 🚀 Next Steps

Now that you've written your first test:

1. **[Learn Basic Concepts](basic-concepts.md)** - Understand gRPC testing fundamentals
2. **[Explore Testing Patterns](../testing-patterns/testing-patterns)** - Master different test scenarios
3. **[Try Real Examples](../guides/examples/basic/real-time-chat)** - See complex real-world tests
4. **[Learn Advanced Features](../testing-patterns/testing-patterns)** - Optimize your test suite

## 🛠️ Troubleshooting

### Common Issues

#### "connection refused"
- Make sure your gRPC server is running
- Check the ADDRESS section points to the correct server
- Verify the server is listening on the specified port

#### "method not found"
- Check the ENDPOINT section uses the correct service and method
- Ensure your server implements the specified gRPC service
- Verify the method name matches exactly

#### "invalid JSON"
- Validate your JSON syntax in REQUEST and RESPONSE sections
- Use a JSON validator to check for syntax errors
- Ensure all quotes and brackets are properly closed

### Getting Help

- **[Troubleshooting Guide](../advanced/troubleshooting)** - Common problems and solutions
- **[Examples](../guides/examples/basic/real-time-chat)** - Real-world test examples
- **[API Reference](../reference/)** - Complete technical documentation

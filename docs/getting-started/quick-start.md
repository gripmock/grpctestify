# Quick Start Guide

Get up and running with gRPC Testify in 5 minutes! This guide will walk you through creating and running your first gRPC test.

## 🎯 What You'll Learn

By the end of this guide, you'll know how to:
- Create a simple gRPC test
- Run tests with gRPC Testify
- Understand basic test structure
- Use assertions to validate responses

## 📋 Prerequisites

- gRPC Testify installed (see [Installation Guide](installation.md))
- A running gRPC server to test against
- Basic understanding of gRPC concepts

## 🚀 Your First Test

Let's create a simple test for a "Hello World" gRPC service.

### Step 1: Create a Test File

Create a file called `hello_test.gctf`:

```php
# Hello World Test
# A simple test for a greeting service

--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
helloworld.Greeter/SayHello

--- REQUEST ---
{
    "name": "World"
}

--- RESPONSE ---
{
    "message": "Hello World"
}

--- ASSERTS ---
.message == "Hello World"
.message | length > 0
.message | test("Hello")

--- OPTIONS ---
timeout: 30
```

### Step 2: Run the Test

Execute your test:

```bash
./grpctestify.sh hello_test.gctf
```

### Step 3: Understand the Output

You should see output like this:

```
Running gRPC Testify v1.0.0
================================

Test: hello_test.gctf
Address: localhost:4770
Endpoint: helloworld.Greeter/SayHello
Status: ✅ PASSED
Duration: 0.123s

Summary:
  Total: 1
  Passed: 1
  Failed: 0
  Duration: 0.123s
```

## 📖 Understanding the Test Structure

Let's break down each section of the test file:

### Header Comment
```php
# Hello World Test
# A simple test for a greeting service
```
- Provides context and description
- Helps with test organization

### ADDRESS Section
```php
--- ADDRESS ---
localhost:4770
```
- Specifies the gRPC server address
- Can be hostname, IP address, or localhost
- Include port number

### ENDPOINT Section
```php
--- ENDPOINT ---
helloworld.Greeter/SayHello
```
- Defines the gRPC service and method
- Format: `package.Service/Method`
- Must match your protobuf definition

### REQUEST Section
```php
--- REQUEST ---
{
    "name": "World"
}
```
- Contains the request payload
- Must be valid JSON
- Fields should match your protobuf message

### RESPONSE Section
```php
--- RESPONSE ---
{
    "message": "Hello World"
}
```
- Expected response from the server
- Used for validation
- Must be valid JSON

### ASSERTS Section
```php
--- ASSERTS ---
.message == "Hello World"
.message | length > 0
.message | test("Hello")
```
- Validation rules for the response
- Uses JSONPath expressions
- Multiple assertions are supported

### OPTIONS Section
```php
--- OPTIONS ---
timeout: 30
```
- Test configuration options
- Optional section
- Can include timeout, tolerance, etc.

## 🔍 Understanding Assertions

Assertions validate that your gRPC service returns the expected data. Here are some common patterns:

### Basic Equality
```php
.message == "Hello World"
.user.id == "12345"
.status == true
```

### Field Existence
```php
.user.id | type == "string"
.message | length > 0
.data | type == "object"
```

### Pattern Matching
```php
.email | test("@")
.phone | test("\\+1-\\d{3}-\\d{3}-\\d{4}")
.url | test("https://")
```

### Array Operations
```php
.items | length == 3
.items[0].name == "First Item"
.users | length >= 1
```

### Nested Object Access
```php
.user.profile.name == "John Doe"
.response.data.items[0].id == "item_001"
```

## 🎯 Common Test Patterns

### Testing with Different Inputs

Create multiple test files for different scenarios:

**hello_alice.gctf:**
```php
# Test with different name
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
helloworld.Greeter/SayHello

--- REQUEST ---
{
    "name": "Alice"
}

--- RESPONSE ---
{
    "message": "Hello Alice"
}

--- ASSERTS ---
.message == "Hello Alice"
```

### Testing Error Cases

**hello_empty.gctf:**
```php
# Test with empty name
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
helloworld.Greeter/SayHello

--- REQUEST ---
{
    "name": ""
}

--- RESPONSE ---
{
    "error": "Name cannot be empty",
    "code": "INVALID_ARGUMENT"
}

--- ASSERTS ---
.error == "Name cannot be empty"
.code == "INVALID_ARGUMENT"
```

## 🏃‍♂️ Running Multiple Tests

### Run All Tests in a Directory
```bash
./grpctestify.sh tests/
```

### Run Tests in Parallel
```bash
./grpctestify.sh tests/ --parallel 4
```

### Run with Verbose Output
```bash
./grpctestify.sh tests/ --verbose
```

### Run with Progress Indicator
```bash
./grpctestify.sh tests/ --progress dots
```

## 🎨 Advanced Features

### Using Variables
```php
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
user.UserService/GetUser

--- REQUEST ---
{
    "user_id": "{{USER_ID}}"
}

--- RESPONSE ---
{
    "user": {
        "id": "{{USER_ID}}",
        "name": "John Doe"
    }
}

--- ASSERTS ---
.user.id == "{{USER_ID}}"
```

### Custom Timeouts
```php
--- OPTIONS ---
timeout: 60
tolerance: 0.1
redact: ["password", "token"]
```

### Partial Matching
```php
--- OPTIONS ---
partial: true
```

This allows the response to contain additional fields not specified in the test.

## 🐛 Troubleshooting

### Common Issues

#### Test Fails with "Connection Refused"
- Ensure your gRPC server is running
- Check the address and port
- Verify the server is accessible

#### Test Fails with "Method Not Found"
- Check the endpoint format
- Ensure the service and method exist
- Verify protobuf definitions

#### Assertion Failures
- Check the actual response format
- Verify field names and types
- Use `--verbose` to see detailed output

### Debugging Tips

1. **Use Verbose Mode**: `--verbose` shows detailed request/response data
2. **Check Server Logs**: Look at your gRPC server logs
3. **Validate JSON**: Ensure your REQUEST and RESPONSE sections contain valid JSON
4. **Test Manually**: Use grpcurl to test the endpoint manually

## 📚 Next Steps

Now that you've created your first test:

1. **Explore More Examples**: Check out the [Examples](../examples/)
2. **Learn Advanced Features**: Read about [Real-time Chat Example](../examples/real-time-chat)
3. **Understand Assertions**: Dive deeper into the [Assertion Language](../api-reference/assertions.md)
4. **Set Up CI/CD**: Learn about [CI/CD Integration](../development/ci-cd)

## 🎉 Congratulations!

You've successfully created and run your first gRPC test with gRPC Testify! You now understand:

- ✅ Basic test file structure
- ✅ How to write assertions
- ✅ How to run tests
- ✅ Common troubleshooting techniques

**Ready for more?** Explore the [Examples](../examples/) to see advanced testing patterns!

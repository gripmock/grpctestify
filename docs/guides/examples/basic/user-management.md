# User Management Examples

Complete user service testing with authentication, creation, and profile management.

## 📁 Example Location

```
examples/basic-examples/user-management/
├── server/           # Go gRPC server implementation
├── tests/           # .gctf test files
└── README.md        # Setup instructions
```

## 🎯 Test Scenarios

### User Creation
Tests basic user creation with validation:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
user.UserService/CreateUser

--- REQUEST ---
{
    "username": "john_doe",
    "email": "john@example.com"
}

--- RESPONSE ---
{
    "user": {
        "id": "user_123",
        "username": "john_doe",
        "email": "john@example.com"
    },
    "success": true
}

--- ASSERTS ---
.user.id | type == "string"
.user.username == "john_doe"
.success == true
```

### User Authentication
Tests user login with password validation:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
user.UserService/AuthenticateUser

--- REQUEST ---
{
  "username": "alice",
  "password": "password123"
}

--- RESPONSE ---
{
  "user": {
    "id": "*",
    "username": "alice",
    "email": "*",
    "profile": {
      "first_name": "Alice",
      "last_name": "*"
    },
    "is_active": true,
    "role": "admin"
  },
  "token": "*",
  "expires_at": "*",
  "success": true
}

--- ASSERTS ---
.user.username == "alice"
.user.role == "admin"
.user.is_active == true
.token | length > 10
.success == true
```

### TLS Authentication
Secure authentication with client certificates:

```gctf
--- ADDRESS ---
localhost:4770

--- TLS ---
ca_cert: ./../server/tls/ca-cert.pem
cert: ./../server/tls/client-cert.pem
key: ./../server/tls/client-key.pem
server_name: localhost
insecure_skip_verify: false

--- ENDPOINT ---
user.UserService/AuthenticateUser

--- REQUEST ---
{
  "username": "alice",
  "password": "password123"
}

--- RESPONSE ---
{
  "user": {
    "id": "*",
    "username": "alice",
    "email": "*",
    "profile": {
      "first_name": "Alice",
      "last_name": "*"
    },
    "is_active": true,
    "role": "admin"
  },
  "token": "*",
  "expires_at": "*",
  "success": true
}
```

### Error Handling
Tests error conditions and validation:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
user.UserService/GetUser

--- REQUEST ---
{
  "user_id": "nonexistent"
}

--- ERROR ---
{
  "code": 5,
  "message": "User not found",
  "details": []
}

--- ASSERTS ---
.code == 5
.message | contains("not found")
```

### Type Validation
Advanced type checking and validation:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
user.UserService/CreateUser

--- REQUEST ---
{
  "username": "test_user",
  "email": "test@example.com",
  "age": 25,
  "is_active": true
}

--- RESPONSE ---
{
  "user": {
    "id": "user_456",
    "username": "test_user",
    "email": "test@example.com",
    "age": 25,
    "is_active": true,
    "created_at": "2024-01-01T00:00:00Z"
  },
  "success": true
}

--- ASSERTS ---
.user.id | type == "string"
.user.age | type == "number"
.user.is_active | type == "boolean"
.user.created_at | strptime("%Y-%m-%dT%H:%M:%SZ") | type == "array"
.success == true
```

## 🔧 Running the Examples

```bash
# Navigate to the example
cd examples/basic-examples/user-management

# Start the server
make start

# Run all tests
../../grpctestify.sh tests/*.gctf

# Run specific test
../../grpctestify.sh tests/user_creation.gctf

# Stop the server
make stop
```

## 📊 Test Coverage

This example demonstrates:

- ✅ **Unary RPC calls** - Basic request/response patterns
- ✅ **Response validation** - JSON structure and field validation
- ✅ **Error handling** - gRPC error codes and messages
- ✅ **TLS authentication** - Secure connections with certificates
- ✅ **Type validation** - Advanced type checking with jq
- ✅ **Assertion patterns** - Various validation techniques

## 🎓 Learning Points

1. **Basic gRPC Testing** - Simple unary call patterns
2. **Response Validation** - Using RESPONSE and ASSERTS sections
3. **Error Testing** - Testing error conditions and codes
4. **Security Testing** - TLS and authentication patterns
5. **Type Safety** - Advanced validation with jq expressions

## 🔗 Related Examples

- **[Real-time Chat](real-time-chat.md)** - Messaging patterns
- **[IoT Monitoring](iot-monitoring.md)** - Device management
- **[E-commerce ShopFlow](../advanced/shopflow-ecommerce.md)** - Complex user workflows

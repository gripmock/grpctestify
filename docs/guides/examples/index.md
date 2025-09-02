# Examples

Learn gRPC Testify through practical examples covering different RPC patterns and real-world scenarios.

## 🎯 Example Categories

### 📚 [Basic Examples](basic/)
Start with fundamental concepts:
- **[User Management](basic/user-management)** - Complete user service testing with authentication, creation, and profile management
- **[Real-time Chat](basic/real-time-chat)** - Messaging patterns and real-time communication
- **[IoT Monitoring](basic/iot-monitoring)** - Device management and monitoring scenarios

### 🚀 [Advanced Examples](advanced/)
Explore sophisticated features:
- **[E-commerce ShopFlow](advanced/shopflow-ecommerce)** - Complete e-commerce platform testing
- **[Media Streaming](advanced/media-streaming)** - File upload, processing, and streaming scenarios
- **[AI Chat](advanced/ai-chat)** - AI-powered conversation and sentiment analysis

### 🔒 [Security Examples](security/)
Production security patterns:
- **[Fintech Payment](security/fintech-payment)** - Financial service validation with compliance
- **[File Storage](security/file-storage)** - Secure file operations and storage

### 🔌 [Plugin Examples](plugins/)
Custom plugin development:
- **[Custom Plugins](plugins/custom-plugins)** - Building and using custom plugins
- **[Plugin Development](plugins/development)** - Plugin architecture and development guide

## 🚀 Quick Start Examples

### Basic Unary RPC
```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
user.UserService/GetUser

--- REQUEST ---
{
  "user_id": "123"
}

--- RESPONSE ---
{
  "user_id": "123", 
  "name": "John Doe",
  "email": "john@example.com"
}
```

### With Assertions
```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
user.UserService/CreateUser

--- REQUEST ---
{
  "name": "Jane Doe",
  "email": "jane@example.com"
}

--- RESPONSE ---
{
  "user_id": "456",
  "name": "Jane Doe", 
  "email": "jane@example.com",
  "created_at": "2024-01-01T00:00:00Z"
}

--- ASSERTS ---
.user_id | tonumber > 0
.created_at | strptime("%Y-%m-%dT%H:%M:%SZ") | type == "array"
.email | test("@")
```

### Error Handling
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
  "code": "NOT_FOUND",
  "message": "User not found"
}

--- ASSERTS ---
.code == "NOT_FOUND"
.message | contains("not found")
```

### TLS Authentication
```gctf
--- ADDRESS ---
localhost:4770

--- TLS ---
ca_cert: ./../server/tls/ca-cert.pem
cert: ./../server/tls/client-cert.pem
key: ./../server/tls/client-key.pem
server_name: localhost

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
    "role": "admin"
  },
  "token": "*",
  "success": true
}
```

### Client Streaming
```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
storage.FileService/UploadFile

--- REQUEST ---
{
  "file_id": "file_001",
  "chunk_number": 1,
  "data": "SGVsbG8gV29ybGQh",
  "is_last": false
}

--- REQUEST ---
{
  "file_id": "file_001", 
  "chunk_number": 2,
  "data": "RmluYWwgY2h1bms=",
  "is_last": true
}

--- RESPONSE ---
{
  "file_id": "file_001",
  "total_chunks": 2,
  "success": true
}
```

## 📁 Example Structure

Each example category contains:
- **Server implementations** - Complete gRPC servers with business logic
- **Test files** - `.gctf` files demonstrating various testing patterns
- **Documentation** - Detailed explanations and usage guides

## 🎯 Getting Started

1. **Choose an example** from the categories above
2. **Start the server** using the provided scripts
3. **Run the tests** with `grpctestify.sh`
4. **Explore the patterns** and adapt them to your needs

## 🔧 Running Examples

```bash
# Navigate to an example
cd examples/basic-examples/user-management

# Start the server
make start

# Run tests
../../grpctestify.sh tests/*.gctf

# Stop the server
make stop
```

## 📚 Learning Path

1. **Start with Basic Examples** - Understand core concepts
2. **Explore Advanced Examples** - Learn complex patterns
3. **Study Security Examples** - Master production security
4. **Build Custom Plugins** - Extend functionality

Each example is designed to be self-contained and educational, providing real-world scenarios that you can adapt to your own projects.


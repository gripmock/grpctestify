---
layout: home
hero:
  name: gRPC Testify
  text: Powerful gRPC Testing Framework
  tagline: Test your gRPC services with ease. Simple syntax, powerful assertions, comprehensive coverage.
  actions:
    - theme: brand
      text: Get Started
      link: /guides/getting-started/installation
    - theme: alt
      text: View on GitHub
      link: https://github.com/gripmock/grpctestify
features:
  - icon: 🚀
    title: Simple & Fast
    details: Write tests in a simple .gctf format. Execute in parallel for maximum speed.
  - icon: 🎯
    title: Comprehensive Testing
    details: Support for unary, streaming, authentication, and error scenarios.
  - icon: 🔧
    title: Plugin System
    details: Extend functionality with custom plugins for authentication, validation, and more.
  - icon: 📊
    title: Rich Reporting
    details: Detailed test reports with timing, coverage, and failure analysis.
  - icon: 🔒
    title: Security First
    details: Built-in TLS support, header validation, and secure authentication testing.
  - icon: 🛠️
    title: Developer Friendly
    details: VS Code extension, web generator, and comprehensive documentation.
  - icon: 🔄
    title: CI/CD Ready
    details: Perfect integration with GitHub Actions, Jenkins, and other CI systems.
  - icon: 📈
    title: Performance Focused
    details: Optimized for high-performance testing with minimal overhead.
---

## Quick Start

### 1. Install

```bash
curl -LO https://github.com/gripmock/grpctestify/releases/latest/download/grpctestify.sh
chmod +x grpctestify.sh
```

### 2. Write Test

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
```

**Note**: For unary RPC, use either `RESPONSE` OR `ASSERTS`, not both. Use `RESPONSE with_asserts` if you need both.

### 3. Run Test

```bash
./grpctestify.sh test.gctf
```

## What You Can Test

### 📡 gRPC Patterns

gRPC supports four main communication patterns, each with different testing approaches:

#### Unary RPC (Request-Response)
Simple one-to-one communication - perfect for basic operations

```gctf
--- ENDPOINT ---
user.UserService/GetUser

--- REQUEST ---
{ "user_id": "123" }

--- RESPONSE ---
{ "user": { "id": "123", "name": "John" } }
```

**Note**: Use either `RESPONSE` OR `ASSERTS` for unary RPC.

#### Server Streaming (One-to-Many)
Server sends multiple responses to a single request - ideal for real-time data

```gctf
--- ENDPOINT ---
monitor.DeviceService/StreamMetrics

--- REQUEST ---
{ "device_id": "sensor_001" }

--- ASSERTS ---
.metric_type == "temperature"
.metric_value > 0

--- ASSERTS ---
.metric_type == "humidity"
.metric_value <= 100
```

#### Client Streaming (Many-to-One)
Client sends multiple requests, server responds once - great for batch operations

```gctf
--- ENDPOINT ---
upload.FileService/UploadChunks

--- REQUEST ---
{ "chunk": "data1", "sequence": 1 }

--- REQUEST ---
{ "chunk": "data2", "sequence": 2 }

--- RESPONSE ---
{ "status": "completed", "total_chunks": 2 }
```

#### Bidirectional Streaming (Many-to-Many)
Full duplex communication - perfect for real-time applications

```gctf
--- ENDPOINT ---
chat.ChatService/StreamMessages

--- REQUEST ---
{ "message": "Hello", "user": "alice" }

--- ASSERTS ---
.message | contains("Hello")
.user == "alice"

--- REQUEST ---
{ "message": "Hi there!", "user": "bob" }

--- ASSERTS ---
.message | contains("Hi")
.user == "bob"
```

### 🔒 Security & Authentication
TLS, headers, and secure endpoints

```gctf
--- TLS ---
ca_cert: ./certs/ca.pem
cert: ./certs/client.pem

--- REQUEST_HEADERS ---
authorization: Bearer token
x-api-key: your-secret-key

--- ENDPOINT ---
secure.SecureService/GetData
```



## Documentation

### 🚀 Getting Started
- [Installation Guide](/guides/getting-started/installation)
- [Your First Test](/guides/getting-started/first-test)
- [Basic Concepts](/guides/getting-started/basic-concepts)

### 🎯 Testing Patterns
- [Testing Patterns](/guides/testing-patterns/testing-patterns)

### 📖 Reference
- [Command Line Reference](/guides/reference/api/command-line)
- [Test File Format](/guides/reference/api/test-files)

## Learning Path

1. **Install & Setup** - Get gRPC Testify running on your system
   → [Start Here](/guides/getting-started/installation)

2. **Write First Test** - Create and run your first gRPC test
   → [Learn More](/guides/getting-started/first-test)

3. **Master Patterns** - Learn unary, streaming, and error testing
   → [Explore](/guides/testing-patterns/testing-patterns)

4. **Advanced Features** - Parallel execution, plugins, and performance
   → [Advanced](/guides/getting-started/basic-concepts)

## IDE Integration

### 📝 VS Code Extension
Enhanced .gctf editing with syntax highlighting, auto-completion, and validation
→ [Install Extension](https://marketplace.visualstudio.com/items?itemName=gripmock.grpctestify)

### 🌐 Web Generator
Interactive web interface for creating .gctf files with templates and examples
→ [Try Generator](/generator)

## Ready to Start?

Begin your gRPC testing journey. Join thousands of developers who trust gRPC Testify for their testing needs.

- [🚀 Get Started Now](/guides/getting-started/installation)
- [🐙 View on GitHub](https://github.com/gripmock/grpctestify)

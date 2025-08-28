---
layout: home

hero:
  name: "gRPC Testify"
  text: "Automate gRPC Testing"
  tagline: "Validate endpoints, requests, and responses using simple .gctf files"
  image: https://github.com/user-attachments/assets/d331a8db-4f4c-4296-950c-86b91ea5540a
  actions:
    - theme: brand
      text: Get Started
      link: /getting-started/installation
    - theme: alt
      text: View on GitHub
      link: https://github.com/gripmock/grpctestify
    - theme: alt
      text: Try Generator
      link: /generator

features:
  - title: 🌊 Full gRPC Streaming Support
    details: Test unary, client, server, and bidirectional streams with comprehensive validation
  - title: ⚡ Parallel Execution
    details: Run multiple tests simultaneously with --parallel N option for faster testing
  - title: 🎯 Advanced Assertions
    details: Powerful jq-based validation with custom plugins and flexible matching
  - title: 📂 Recursive Processing
    details: Automatically discover and run all .gctf files in directories and subdirectories
  - title: 📊 JUnit XML Reports
    details: Generate JUnit-compatible XML reports for seamless CI/CD integration
---

## 🚀 Quick Start

```bash
# Download and install
curl -LO https://github.com/gripmock/grpctestify/releases/latest/download/grpctestify.sh
chmod +x grpctestify.sh

# Run your first test
./grpctestify.sh examples/user-management/tests/user_creation.gctf
```

## 📋 Requirements

- [grpcurl](https://github.com/fullstorydev/grpcurl) - gRPC client
- [jq](https://stedolan.github.io/jq/) - JSON processor
- Docker (for integration tests)

## 📚 Documentation

- **[Getting Started](./getting-started/quick-start)** - Installation and basic concepts
- **[API Reference](./api-reference/)** - Complete feature documentation
- **[Examples](./examples/)** - Real-world usage examples
- **[Development](./development/)** - CI/CD workflows and development guides
- **[Troubleshooting](./troubleshooting)** - Common issues and solutions

## 🎯 What You Can Test

### Unary RPC
```php
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

### Client Streaming
```php
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

--- ASSERTS ---
.file_id == "file_001"
.total_chunks == 2
.success == true
```

## 🏗️ Real-World Examples

Explore our comprehensive examples that demonstrate real-world gRPC testing scenarios:

- **[User Management System](./examples/user-management)** - Complete user management with unary RPC
- **[Real-time Chat](./examples/real-time-chat)** - Chat system with bidirectional streaming

## 🎓 Learning Path

1. **[Installation](./getting-started/installation)** - Get gRPC Testify running
2. **[Quick Start](./getting-started/quick-start)** - Run your first test
3. **[Basic Concepts](./getting-started/basic-concepts)** - Understand the fundamentals
4. **[Examples](./examples/)** - Explore real-world scenarios
5. **[API Reference](./api-reference/)** - Master all features

## 🔗 Community

- **GitHub**: [gripmock/grpctestify](https://github.com/gripmock/grpctestify)
- **Issues**: [Report bugs or request features](https://github.com/gripmock/grpctestify/issues)

---

**Ready to test your gRPC services?** Start with our [installation guide](./getting-started/installation) or try the [online generator](./generator)!

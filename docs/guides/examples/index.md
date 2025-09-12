# Examples

Learn gRPC Testify through practical examples covering different RPC patterns and real-world scenarios.

## 🎯 Example Categories

### 📚 [Basic Examples](basic/)
Start with fundamental concepts:
- **[Real-time Chat](basic/real-time-chat)** - Messaging patterns and real-time communication with comprehensive testing examples

## 🚀 Quick Start Examples

### Basic Unary RPC
```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
chat.ChatService/SendMessage

--- REQUEST ---
{
  "message": {
    "user_id": "user1",
    "room_id": "room1",
    "content": "Hello from gRPC Testify!",
    "message_type": "text",
    "metadata": {
      "client": "grpctestify",
      "version": "1.0.0"
    }
  }
}

--- ASSERTS ---
.success == true
.message.id | test("msg_.*")
.message.content == "Hello from gRPC Testify!"
.message.userId == "user1"
.message.roomId == "room1"
```

### Response Validation
```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
chat.ChatService/SendMessage

--- REQUEST ---
{
  "message": {
    "user_id": "response_test_user",
    "room_id": "test_room",
    "content": "Testing RESPONSE validation!",
    "message_type": "text"
  }
}

--- RESPONSE ---
{
  "message": {
    "id": "msg_response_test_12345",
    "userId": "response_test_user",
    "roomId": "test_room",
    "content": "Testing RESPONSE validation!",
    "messageType": "text",
    "timestamp": "2024-01-15T10:30:00Z"
  },
  "success": true
}
```

### Advanced Assertions
```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
chat.ChatService/SendMessage

--- REQUEST ---
{
  "message": {
    "user_id": "assert_test_user",
    "room_id": "test_room",
    "content": "Testing various assertion types!",
    "message_type": "text",
    "metadata": {
      "client": "grpctestify_test",
      "version": "1.0.0"
    }
  }
}

--- ASSERTS ---
.success == true
.message.id | test("msg_.*")
.message.timestamp | test("[0-9]{4}-[0-9]{2}-[0-9]{2}T.*")
.message.content | contains("assertion")
.message.content | length > 20
.message.metadata | length >= 2
```

### Options and Timeout
```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
chat.ChatService/SendMessage

--- REQUEST ---
{
  "message": {
    "user_id": "options_test_user",
    "room_id": "test_room",
    "content": "Testing OPTIONS functionality!",
    "message_type": "text"
  }
}

--- RESPONSE partial=true ---
{
  "message": {
    "id": "msg_options_test_12345",
    "userId": "options_test_user",
    "content": "Testing OPTIONS functionality!"
  },
  "success": true
}

--- ASSERTS ---
.message.id | test("msg_.*")
.success == true

--- OPTIONS ---
timeout: 15
partial: true
```

## 📁 Example Structure

The real-time chat example contains:
- **Proto definitions** - gRPC service definitions
- **Stub files** - YAML files for gripmock server responses
- **Test files** - 9 `.gctf` files demonstrating various testing patterns
- **Comprehensive coverage** - All grpctestify capabilities in one example

## 🎯 Getting Started

1. **Navigate to the real-time chat example**
2. **Ensure gripmock is running** on localhost:4770
3. **Run the tests** with `grpctestify.sh`
4. **Explore the patterns** and adapt them to your needs

## 🔧 Running Examples

```bash
# Navigate to an example
cd examples/basic-examples/real-time-chat

# Start gripmock server (if needed)
# gripmock is already running on localhost:4770

# Run tests
../../grpctestify.sh tests/*.gctf

# Run with verbose output
../../grpctestify.sh tests/*.gctf --verbose
```

## 📚 Learning Path

1. **Start with Real-time Chat Examples** - Understand core concepts and testing patterns
2. **Explore Different Test Types** - Learn various assertion patterns and response validation
3. **Study Advanced Features** - Master verbose mode, options, and comprehensive testing

The real-time chat example is designed to be comprehensive and educational, providing multiple testing scenarios that demonstrate all grpctestify capabilities.


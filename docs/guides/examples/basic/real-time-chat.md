# Real-time Chat Examples

Messaging patterns and real-time communication testing.

## 📁 Example Location

```
examples/basic-examples/real-time-chat/
├── server/           # Go gRPC server implementation
├── tests/           # .gctf test files
└── README.md        # Setup instructions
```

## 🎯 Test Scenarios

### Send Message
Basic message sending with validation:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
chat.ChatService/SendMessage

--- REQUEST ---
{
    "room_id": "room_001",
    "user_id": "user_123",
    "message": "Hello, world!",
    "timestamp": "2024-01-01T12:00:00Z"
}

--- RESPONSE ---
{
    "message_id": "msg_456",
    "room_id": "room_001",
    "user_id": "user_123",
    "message": "Hello, world!",
    "timestamp": "2024-01-01T12:00:00Z",
    "status": "sent"
}

--- ASSERTS ---
.message_id | type == "string"
.room_id == "room_001"
.user_id == "user_123"
.status == "sent"
```

### Get Messages
Retrieve chat history:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
chat.ChatService/GetMessages

--- REQUEST ---
{
    "room_id": "room_001",
    "limit": 10,
    "offset": 0
}

--- RESPONSE ---
{
    "messages": [
        {
            "id": "msg_001",
            "user_id": "user_123",
            "message": "Hello!",
            "timestamp": "2024-01-01T12:00:00Z"
        },
        {
            "id": "msg_002",
            "user_id": "user_456",
            "message": "Hi there!",
            "timestamp": "2024-01-01T12:01:00Z"
        }
    ],
    "total_count": 2
}

--- ASSERTS ---
.messages | length == 2
.messages[0].user_id == "user_123"
.messages[1].user_id == "user_456"
.total_count == 2
```

### Secure Chat with TLS
Encrypted communication with TLS:

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
chat.ChatService/SendMessage

--- REQUEST ---
{
    "room_id": "secure_room",
    "user_id": "user_789",
    "message": "Secret message",
    "encrypted": true
}

--- RESPONSE ---
{
    "message_id": "msg_789",
    "room_id": "secure_room",
    "user_id": "user_789",
    "message": "Secret message",
    "encrypted": true,
    "status": "sent_encrypted"
}

--- ASSERTS ---
.status == "sent_encrypted"
.encrypted == true
```

## 🔧 Running the Examples

```bash
# Navigate to the example
cd examples/basic-examples/real-time-chat

# Start GripMock server with stubs
gripmock -s stubs/ &

# Run all tests
../../grpctestify.sh tests/*.gctf

# Run specific test
../../grpctestify.sh tests/send_message.gctf

# Stop GripMock server
pkill gripmock
```

## 📊 Test Coverage

This example demonstrates:

- ✅ **Message Operations** - Send and retrieve messages
- ✅ **Room Management** - Chat room functionality
- ✅ **User Context** - User identification and validation
- ✅ **Timestamp Handling** - Time-based message ordering
- ✅ **TLS Security** - Encrypted communication
- ✅ **Message History** - Pagination and retrieval patterns

## 🎓 Learning Points

1. **Message Patterns** - Basic chat message handling
2. **Data Retrieval** - Fetching message history
3. **Security** - TLS for encrypted communication
4. **Validation** - Message structure and content validation
5. **Real-time Concepts** - Timestamp and ordering patterns

## 🔗 Related Documentation

- **[Testing Patterns](../testing-patterns/)** - Learn advanced testing techniques
- **[Plugin Development](../plugins/)** - Extend functionality with custom plugins
- **[API Reference](../reference/)** - Complete command and format reference

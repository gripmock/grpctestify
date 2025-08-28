# Real-time Chat System

A comprehensive example demonstrating **Bidirectional Streaming RPC** patterns with gRPC Testify. This example implements a real-time chat system with live messaging, room management, and user presence tracking.

## 🎯 Learning Objectives

- Master bidirectional streaming RPC patterns
- Understand real-time communication testing
- Learn concurrent user scenario validation
- Explore streaming message validation
- Handle connection lifecycle management

## 🏗️ Architecture

```
real-time-chat/
├── server/
│   ├── main.go          # gRPC server with streaming support
│   ├── chat.proto       # Chat service definitions
│   ├── go.mod           # Go module configuration
│   └── Makefile         # Build and run commands
└── tests/
    ├── send_message.gctf        # Message sending tests
    ├── get_messages.gctf        # Message retrieval tests
    ├── join_room.gctf           # Room joining tests
    ├── chat_stream.gctf         # Bidirectional streaming tests
    └── user_presence.gctf       # Presence tracking tests
```

## 📋 Features Implemented

### Core Services
- **SendMessage** - Send single messages (Unary)
- **GetMessages** - Retrieve room messages (Unary)
- **ChatStream** - Real-time bidirectional streaming
- **JoinRoom/LeaveRoom** - Room management (Unary)
- **GetRooms** - List available rooms (Unary)
- **GetUsers** - List room members (Unary)
- **UpdateUserStatus** - User presence updates (Unary)

### Streaming Features
- **Real-time messaging** - Instant message delivery
- **Typing indicators** - Live typing status
- **User presence** - Online/offline status
- **Room notifications** - Join/leave events

### Data Models
- **ChatMessage** - Rich message structure with metadata
- **User** - User profiles with presence information
- **ChatRoom** - Room configuration and member management
- **ChatAction** - Streaming action commands

## 🚀 Quick Start

### 1. Start the Chat Server

```bash
cd examples/real-time-chat/server
make run
```

The server starts with pre-configured:
- **2 rooms**: "General Discussion", "Tech Support"
- **3 users**: alice, bob, charlie
- **Sample messages** for testing

### 2. Run All Tests

```bash
./grpctestify.sh examples/real-time-chat/tests/
```

### 3. Test Individual Features

```bash
# Test message sending
./grpctestify.sh examples/real-time-chat/tests/send_message.gctf

# Test message retrieval
./grpctestify.sh examples/real-time-chat/tests/get_messages.gctf
```

## 📝 Test Scenarios

### Message Sending (`send_message.gctf`)
Tests basic message sending functionality:

```php
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
.message.id | test("msg_.*")
.message.timestamp | test("[0-9]{4}-[0-9]{2}-[0-9]{2}T.*")
.success == true
```

### Message Retrieval (`get_messages.gctf`)
Validates message history and pagination:

```php
--- REQUEST ---
{
  "room_id": "room1",
  "limit": 10,
  "offset": 0
}

--- ASSERTS ---
.messages | length >= 1
.messages[0].room_id == "room1"
.total >= 1
```

### Room Management (`join_room.gctf`)
Tests room joining and user management:

```php
--- ENDPOINT ---
chat.ChatService/JoinRoom

--- REQUEST ---
{
  "user_id": "user3",
  "room_id": "room1"
}

--- ASSERTS ---
.success == true
.message == "Successfully joined the room"
```

### Bidirectional Streaming (`chat_stream.gctf`)
*Note: Full streaming tests require custom test runners, but we can test stream initialization*

## 🧪 Advanced Testing Features

### Real-time Message Validation
```php
--- ASSERTS ---
.message.id | test("msg_[0-9]+")
.message.timestamp | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T")
.message.content | length > 0
```

### User Presence Testing
```php
--- ENDPOINT ---
chat.ChatService/UpdateUserStatus

--- REQUEST ---
{
  "user_id": "user1",
  "online": true,
  "status": {
    "mood": "available",
    "message": "Ready to chat!"
  }
}

--- ASSERTS ---
.success == true
.user.online == true
.user.status.mood == "available"
```

### Error Scenarios
```php
--- REQUEST ---
{
  "message": {
    "user_id": "invalid_user",
    "room_id": "room1",
    "content": "This should fail"
  }
}

--- ERROR ---
{
  "code": 7,
  "message": "user is not a member of this room"
}
```

## 🔧 Server Implementation Highlights

### Streaming Management
- **Connection tracking** - Maintains active stream connections
- **Room-based broadcasting** - Messages delivered to all room members
- **Graceful disconnection** - Cleanup on client disconnect
- **Concurrent safety** - Thread-safe operations with mutex locks

### Message Processing
- **Real-time delivery** - Instant message broadcasting
- **Message persistence** - In-memory storage for demo
- **Metadata support** - Rich message context
- **Typing indicators** - Live user activity

### Room Management
- **Dynamic rooms** - Join/leave functionality
- **Member tracking** - User presence in rooms
- **Permission checks** - Room access control
- **Capacity limits** - Maximum room size enforcement

## 📊 What You'll Learn

### Streaming Patterns
- **Bidirectional streams** - Client and server streaming
- **Connection lifecycle** - Connect, communicate, disconnect
- **Concurrent handling** - Multiple simultaneous connections
- **Stream synchronization** - Coordinated messaging

### Real-time Testing
- **Message delivery** - Instant communication validation
- **Presence tracking** - User status monitoring
- **Event ordering** - Sequential message validation
- **Error recovery** - Connection failure handling

### Chat System Concepts
- **Room-based messaging** - Multi-user conversations
- **User management** - Identity and permissions
- **Message types** - Text, media, system messages
- **Notification systems** - Real-time updates

## 🎮 Interactive Testing

For more interactive testing, you can use tools like:

### grpcurl for Streaming
```bash
# Start a streaming session (requires manual interaction)
grpcurl -plaintext -d @ localhost:50053 chat.ChatService/ChatStream
```

### Multiple Client Testing
Run multiple test sessions to simulate concurrent users:

```bash
# Terminal 1: User 1 joins room
./grpctestify.sh examples/real-time-chat/tests/join_room.gctf

# Terminal 2: User 2 sends message  
./grpctestify.sh examples/real-time-chat/tests/send_message.gctf

# Terminal 3: Retrieve messages
./grpctestify.sh examples/real-time-chat/tests/get_messages.gctf
```

## 🔗 Related Examples

- **[User Management](./user-management)** - Learn basic unary patterns

## 🚨 Common Patterns Tested

### Connection Management
- Stream initialization and cleanup
- Graceful disconnection handling
- Connection error recovery

### Message Validation
- Content validation and sanitization
- Timestamp accuracy
- User permission verification

### Concurrency Testing
- Multiple simultaneous connections
- Race condition prevention
- Message ordering guarantees

## 🤝 Contributing

Want to enhance this chat example? Areas for improvement:
- Authentication and authorization
- Message encryption
- File sharing capabilities
- Emoji and rich text support
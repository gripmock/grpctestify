# Examples

This section contains comprehensive examples demonstrating various gRPC patterns and testing scenarios with gRPC Testify.

## Example Groups

Examples are organized into logical groups based on complexity and use cases:

### 🔰 Basic Examples
**Location**: `examples/basic-examples/`  
**Purpose**: Learn fundamental gRPC patterns and testing concepts

#### 🧑‍💼 User Management System
**Pattern**: Unary RPC  
**Features**: Authentication, CRUD operations, search, error handling  
**Technologies**: Go, gRPC, Protocol Buffers, TLS  
**Test Coverage**: 8 test scenarios covering all major operations
**Port**: 4770

#### 🏠 IoT Device Monitoring
**Pattern**: All streaming patterns  
**Features**: Device registration, metrics collection, status monitoring  
**Technologies**: Go, gRPC, streaming protocols  
**Test Coverage**: 8 scenarios covering device lifecycle and streaming
**Port**: 50055

#### 💬 Real-time Chat System
**Pattern**: Bidirectional Streaming RPC  
**Features**: Live messaging, room management, user presence  
**Technologies**: Go, gRPC, bidirectional streaming, TLS  
**Test Coverage**: 3 scenarios for real-time communication
**Port**: 50053

### 🚀 Advanced Examples
**Location**: `examples/advanced-examples/`  
**Purpose**: Complex streaming patterns and AI integration

#### 🤖 AI Chat Service
**Pattern**: Advanced streaming with AI processing  
**Features**: Natural language processing, sentiment analysis, context awareness  
**Technologies**: Go, gRPC, AI integration, streaming  
**Test Coverage**: 9 scenarios covering AI workflows and complex streaming
**Port**: 50057

#### 📹 Media Streaming Service
**Pattern**: File handling and streaming  
**Features**: File upload/download, streaming, metadata processing  
**Technologies**: Go, gRPC, file streaming, bulk operations  
**Test Coverage**: 7 scenarios for media processing workflows
**Port**: 50058

#### 🛒 E-commerce Platform (ShopFlow)
**Pattern**: Comprehensive platform example  
**Features**: Product catalog, orders, payments, user management  
**Technologies**: Go, gRPC, TLS, mTLS, custom plugins  
**Test Coverage**: 30+ scenarios covering entire e-commerce workflow
**Port**: 50054

### 🔒 Security Examples
**Location**: `examples/security-examples/`  
**Purpose**: Security, compliance, and enterprise patterns

#### 💳 Fintech Payment Processing
**Pattern**: Secure financial transactions  
**Features**: Payment processing, fraud detection, compliance validation  
**Technologies**: Go, gRPC, mTLS, advanced security  
**Test Coverage**: 10 scenarios covering secure payment workflows
**Port**: 50056

#### 📁 Secure File Storage
**Pattern**: Client streaming with security  
**Features**: Secure file upload, encryption, access control  
**Technologies**: Go, gRPC, TLS, streaming protocols  
**Test Coverage**: 2 scenarios for secure file operations
**Port**: 50052

### 🔧 Custom Plugins
**Location**: `examples/custom-plugins/`  
**Purpose**: Plugin development examples and templates

## Quick Start

Each example includes:

- **Complete gRPC server implementation** in Go
- **Proto definitions** with comprehensive service definitions  
- **Test files (*.gctf)** demonstrating various testing scenarios
- **Makefile** for easy building and running

## Running Examples

1. Navigate to any example directory:
   ```bash
   cd examples/basic-examples/user-management
   ```

2. Start the server:
   ```bash
   cd server
   make run
   ```

3. Run tests (in another terminal):
   ```bash
   cd ../../..
   ./grpctestify.sh examples/basic-examples/user-management/tests/
   ```

## Learning Path

We recommend following this order for learning:

1. **Basic Examples** - Start with fundamental patterns
   - User Management (unary RPC)
   - IoT Monitoring (all streaming types)
   - Real-time Chat (bidirectional streaming)

2. **Advanced Examples** - Move to complex scenarios
   - AI Chat (advanced streaming)
   - Media Streaming (file handling)
   - ShopFlow E-commerce (comprehensive platform)

3. **Security Examples** - Learn enterprise patterns
   - Fintech Payment (mTLS and compliance)
   - Secure File Storage (TLS and encryption)

4. **Custom Plugins** - Extend functionality
   - Plugin development templates
   - Custom assertion examples

## Testing Patterns

Each example demonstrates different testing patterns:

- **Basic Assertions** - Simple field validation
- **Complex JSON Validation** - Nested object testing  
- **Error Scenarios** - Failure case handling
- **Performance Testing** - Timeout and response time validation
- **Streaming Scenarios** - Real-time communication testing
- **Security Testing** - TLS/mTLS validation
- **Plugin Integration** - Custom assertion examples

## Configuration

Examples are configured via `examples/examples-config.json` with the following structure:

```json
{
  "groups": {
    "basic-examples": { ... },
    "advanced-examples": { ... },
    "security-examples": { ... },
    "custom-plugins": { ... }
  }
}
```

Each example has a unique port assignment to avoid conflicts during parallel testing.


# User Management System

A comprehensive example demonstrating **Unary RPC** patterns with gRPC Testify. This example implements a complete user management system with authentication, CRUD operations, and search functionality.

## 🎯 Learning Objectives

- Understand unary RPC request-response patterns
- Learn user authentication and authorization testing
- Master CRUD operation validation
- Explore search and filtering scenarios
- Handle error cases and edge conditions

## 🏗️ Architecture

```
user-management/
├── server/
│   ├── main.go          # gRPC server implementation
│   ├── user.proto       # Protocol buffer definitions
│   ├── go.mod           # Go module configuration
│   └── Makefile         # Build and run commands
└── tests/
    ├── user_creation.gctf     # User registration tests
    ├── user_authentication.gctf  # Login/auth tests  
    ├── user_profile.gctf      # Profile management tests
    ├── user_search.gctf       # Search functionality tests
    └── error_handling.gctf    # Error scenario tests
```

## 📋 Features Implemented

### Core Services
- **CreateUser** - User registration with validation
- **AuthenticateUser** - Login with credentials
- **GetUser** - Retrieve user profile by ID
- **UpdateUser** - Modify user information
- **SearchUsers** - Find users with filters
- **DeleteUser** - Remove user accounts

### Data Models
- **User** - Complete user profile with metadata
- **AuthRequest/Response** - Authentication flow
- **SearchRequest/Response** - Advanced filtering
- **UserStats** - Usage analytics

## 🚀 Quick Start

### 1. Start the Server

```bash
cd examples/user-management/server
make run
```

The server will start on `localhost:4770` with sample data:
- **alice** (admin user)
- **bob** (regular user)  
- **charlie** (inactive user)

### 2. Run All Tests

```bash
./grpctestify.sh examples/user-management/tests/
```

### 3. Run Individual Tests

```bash
# Test user creation
./grpctestify.sh examples/user-management/tests/user_creation.gctf

# Test authentication
./grpctestify.sh examples/user-management/tests/user_authentication.gctf
```

## 📝 Test Scenarios

### User Creation (`user_creation.gctf`)
Tests user registration with various data combinations:
- Valid user creation
- Email validation
- Username uniqueness
- Required field validation

```php
--- ENDPOINT ---
user.UserService/CreateUser

--- REQUEST ---
{
  "username": "newuser",
  "email": "newuser@example.com",
  "password": "securepass123",
  "profile": {
    "first_name": "New",
    "last_name": "User"
  }
}

--- ASSERTS ---
.user.id | test("user_.*")
.user.username == "newuser"
.user.email == "newuser@example.com"
```

### Authentication (`user_authentication.gctf`)
Validates login flow and session management:
- Successful authentication
- Invalid credentials handling
- Session token validation
- Rate limiting scenarios

### User Search (`user_search.gctf`)
Tests advanced search and filtering:
- Search by username patterns
- Filter by user status
- Pagination handling
- Empty result scenarios

### Error Handling (`error_handling.gctf`)
Covers various error conditions:
- Invalid user IDs
- Permission denied scenarios
- Rate limiting responses
- Server error handling

## 🧪 Advanced Testing Features

### Assertions Used
- **Field validation** - `== "expected_value"`
- **Pattern matching** - `test("regex_pattern")`
- **Array operations** - `length`, `contains`
- **Nested objects** - `.profile.first_name`

### Error Testing
```php
--- REQUEST ---
{
  "user_id": "invalid_id"
}

--- ERROR ---
{
  "code": 5,
  "message": "User not found"
}
```

### Performance Testing
```php
--- OPTIONS ---
timeout: 5s
retries: 3
```

## 🔧 Server Implementation Highlights

### Sample Data Initialization
The server includes pre-loaded users for testing:
- Different user roles and permissions
- Various account states (active, inactive, pending)
- Realistic user profiles with metadata

### Validation Logic
- Email format validation
- Password strength requirements
- Username uniqueness checks
- Input sanitization

### Error Handling
- Structured error responses
- Appropriate gRPC status codes
- Detailed error messages for debugging

## 📊 What You'll Learn

### gRPC Patterns
- Unary RPC implementation
- Request/response validation
- Error propagation
- Metadata handling

### Testing Strategies
- Positive test cases
- Negative test scenarios
- Edge condition handling
- Performance validation

### Real-world Applications
- User management systems
- Authentication services
- CRUD operations
- Search functionality

## 🔗 Related Examples

- **[Real-time Chat](./real-time-chat)** - Explore bidirectional streaming
- **[API Reference](../api-reference/)** - Detailed testing syntax
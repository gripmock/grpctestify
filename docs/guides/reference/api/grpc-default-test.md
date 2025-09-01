# gRPC Default Test Plugin

Built-in plugin that provides core gRPC testing functionality for gRPC Testify.

## Overview

**Type**: Core Testing Plugin  
**Status**: Stable  
**Included**: Built into gRPC Testify

This plugin handles the fundamental gRPC communication and validation logic that powers all test execution.

## Features

### Core Functionality
- **gRPC Communication**: Handles all gRPC protocol communication
- **Request/Response Processing**: Manages request serialization and response parsing
- **Connection Management**: Establishes and maintains gRPC connections
- **Error Handling**: Processes gRPC errors and status codes

### Automatic Features
- **Service Discovery**: Automatically detects available services and methods
- **Type Validation**: Validates request/response types against protobuf definitions
- **Retry Logic**: Automatic retry on transient failures
- **Timeout Management**: Configurable timeouts for all operations

## Usage

This plugin is automatically loaded and doesn't require explicit configuration. It provides the foundation for all gRPC test operations defined in `.gctf` files.

### Basic Test Structure
```gctf
--- ADDRESS ---
localhost:9090

--- ENDPOINT ---
user.UserService/GetUser

--- REQUEST ---
{
  "user_id": "123"
}

--- RESPONSE ---
{
  "user_id": "123",
  "name": "John Doe"
}
```

### Supported gRPC Patterns
- **Unary RPC**: Single request, single response
- **Server Streaming**: Single request, multiple responses
- **Client Streaming**: Multiple requests, single response  
- **Bidirectional Streaming**: Multiple requests and responses

## Configuration

### Global Options
Configure through command-line flags or environment variables:

```bash
# Timeout configuration
grpctestify tests/ --timeout 30

# Retry configuration  
grpctestify tests/ --retry 3 --retry-delay 2

# Connection options
export GRPCTESTIFY_ADDRESS=localhost:9090
```

### Per-Test Options
Configure in individual test files:

```gctf
--- OPTIONS ---
timeout: 60
tolerance: 0.1
partial: true
```

## Error Handling

### Connection Errors
- **Service Unavailable**: Automatic retry with exponential backoff
- **Network Timeout**: Configurable timeout with clear error messages
- **Authentication Failed**: Clear indication of auth requirements

### Protocol Errors
- **Method Not Found**: Validates service/method existence
- **Invalid Request**: Validates request format against protobuf schema
- **Server Errors**: Proper handling of gRPC status codes

## Advanced Features

### TLS Support
```gctf
--- TLS ---
enabled: true
cert_file: "client.crt"
key_file: "client.key"
ca_file: "ca.crt"
```

### Authentication
```gctf
--- REQUEST_HEADERS ---
authorization: Bearer token123
x-api-key: your-api-key
```

### Custom Metadata
```gctf
--- REQUEST_METADATA ---
{
  "user-agent": "grpc-testify/1.0",
  "trace-id": "abc123"
}
```

## Integration

### With Other Plugins
The default test plugin works seamlessly with other plugins:
- **Validation plugins**: Extend assertion capabilities
- **Report plugins**: Enhance output formatting
- **Custom plugins**: Add domain-specific logic

### State API Integration
Provides test results to the centralized state system:
- Test execution status
- Response times and metrics
- Error details and diagnostics
- Connection information

## Implementation Details

### Core Functions
- `run_grpc_call()`: Executes gRPC requests
- `validate_response()`: Validates responses against expectations
- `handle_grpc_error()`: Processes gRPC errors
- `establish_connection()`: Manages connections

### Dependencies
- **grpcurl**: For gRPC communication
- **jq**: For JSON processing and validation
- **protobuf tools**: For schema validation

## Troubleshooting

### Common Issues
1. **Service not available**: Check server status and address
2. **Method not found**: Verify service/method names
3. **Authentication failed**: Check headers and credentials
4. **Timeout errors**: Adjust timeout settings

### Debug Mode
Enable detailed logging:
```bash
grpctestify tests/ --verbose
```

View generated commands:
```bash
grpctestify tests/ --dry-run --verbose
```

## See Also

- [Test File Format](../test-files) - Complete `.gctf` syntax
- [Troubleshooting](../../advanced/troubleshooting) - Common issues and solutions
- [Plugin Development](../plugin-development) - Creating custom plugins
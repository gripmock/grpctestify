# Troubleshooting Guide

This guide helps you resolve common issues when using gRPC Testify.

## Common Issues

### 📡 Connection Issues

#### gRPC Server Not Available
**Error**: `Service at localhost:4770 is not available`

**Solutions**:
1. **Check server status**: Ensure your gRPC server is running
   ```bash
   grpcurl -plaintext localhost:4770 list
   ```

2. **Verify port**: Confirm the server is listening on the correct port
   ```bash
   netstat -an | grep 4770
   ```

3. **Check firewall**: Ensure port is not blocked by firewall
4. **Test with grpcurl directly**:
   ```bash
   grpcurl -plaintext localhost:4770 your.Service/Method
   ```

#### Connection Timeout
**Error**: `Connection timeout after 30s`

**Solutions**:
1. **Increase timeout** in test file:
   ```php
   --- OPTIONS ---
   timeout: 60
   ```

2. **Check network latency**
3. **Verify server performance**

### 📄 Test File Issues

#### Invalid JSON in Request
**Error**: `Failed to parse JSON request`

**Solutions**:
1. **Validate JSON syntax**:
   ```bash
   echo '{"your": "json"}' | jq .
   ```

2. **Check for trailing commas**:
   ```json
   // ❌ Invalid
   {"field": "value",}
   
   // ✅ Valid  
   {"field": "value"}
   ```

3. **Escape special characters properly**:
   ```json
   {"path": "/tmp/file", "quote": "He said \"hello\""}
   ```

#### Missing Required Sections
**Error**: `Missing ENDPOINT in test.gctf`

**Solutions**:
1. **Check section names** (case-sensitive):
   ```php
   --- ADDRESS ---     ✅ Correct
   --- address ---     ❌ Wrong case
   --- ADDRESSES ---   ❌ Wrong plural
   ```

2. **Verify section order** (recommended):
   ```php
   --- ADDRESS ---
   --- ENDPOINT ---
   --- REQUEST ---
   --- ASSERTS ---
   ```

### 🔍 Assertion Failures

#### jq Expression Errors
**Error**: `jq: error: Invalid jq expression`

**Solutions**:
1. **Test expressions separately**:
   ```bash
   echo '{"status": "ok"}' | jq '.status == "ok"'
   ```

2. **Common jq patterns**:
   ```php
   # String comparison
   .message == "success"
   
   # Type checking
   .id | type == "string"
   
   # Array operations
   .items | length > 0
   .tags | index("production") != null
   
   # Regex matching
   .email | test("@.*\.com$")
   
   # Null checking
   .error == null
   ```

3. **Escape special characters in jq**:
   ```php
   .path | test("^/api/")          # Regex
   .description | contains("test") # Substring
   ```

#### Plugin Assertion Errors
**Error**: `Plugin not found: header`

**Solutions**:
1. **Check plugin syntax**:
   ```php
   # ✅ Correct
   @header("x-api-version") == "1.0.0"
   @trailer("x-processing-time") | test("[0-9]+ms")
   
   # ❌ Wrong
   @header(x-api-version) == "1.0.0"   # Missing quotes
   header("x-api-version") == "1.0.0"  # Missing @
   ```

2. **Available plugins**:
   - `@header("name")` - Response headers
   - `@trailer("name")` - Response trailers

### 🔌 gRPC-Specific Issues

#### Method Not Found
**Error**: `Method not found: YourService/YourMethod`

**Solutions**:
1. **Check service name format**:
   ```php
   # ✅ Correct format
   package.ServiceName/MethodName
   
   # Examples
   user.UserService/CreateUser
   api.v1.ProductService/GetProduct
   ```

2. **List available methods**:
   ```bash
   grpcurl -plaintext localhost:4770 list
   grpcurl -plaintext localhost:4770 list your.ServiceName
   ```

3. **Check protobuf definitions**

#### Authentication Issues
**Error**: `Unauthenticated` or `Permission denied`

**Solutions**:
1. **Add authentication headers**:
   ```php
   --- REQUEST_HEADERS ---
   {
     "authorization": "Bearer your-token-here",
     "x-api-key": "your-api-key"
   }
   ```

2. **Use TLS if required**:
   ```php
   --- TLS ---
   enabled: true
   cert_file: "client.crt"
   key_file: "client.key"
   ca_file: "ca.crt"
   ```

#### Streaming Support
**Status**: All streaming types are now fully supported:
- ✅ **Client Streaming**: Multiple REQUEST sections
- ✅ **Server Streaming**: Single request, streaming responses
- ✅ **Bidirectional Streaming**: Interactive request/response patterns
- ✅ **Unary RPC**: Standard request/response patterns

### 🚀 Performance Issues

#### Slow Test Execution
**Problem**: Tests take too long to run

**Solutions**:
1. **Use parallel execution**:
   ```bash
   ./grpctestify.sh tests/ --parallel 4
   ```

2. **Optimize timeouts**:
   ```php
   --- OPTIONS ---
   timeout: 10  # Reduce if possible
   ```

3. **Profile server performance**

#### High Memory Usage
**Problem**: grpctestify uses too much memory

**Solutions**:
1. **Reduce parallel workers**:
   ```bash
   ./grpctestify.sh tests/ --parallel 2
   ```

2. **Split large test suites**
3. **Optimize test data size**

## Debugging Tips

### 🔍 Verbose Mode & Dry-Run
Enable detailed logging:
```bash
./grpctestify.sh test.gctf --verbose
```

Preview commands without execution (for debugging):
```bash
./grpctestify.sh test.gctf --dry-run
```

Combined debugging:
```bash
./grpctestify.sh test.gctf --dry-run --verbose
```

### 📊 Test Individual Files
Test files one by one to isolate issues:
```bash
./grpctestify.sh specific_test.gctf
```

### 🛠️ Validate with grpcurl
Test your server directly:
```bash
# List services
grpcurl -plaintext localhost:4770 list

# Test method
grpcurl -plaintext \
  -d '{"id": "123"}' \
  localhost:4770 \
  your.Service/GetItem
```

### 📋 Check Dependencies
Ensure all required tools are installed:
```bash
# Check grpcurl
grpcurl --version

# Check jq
jq --version

# Check gRPC Testify
./grpctestify.sh --version
```

## Getting Help

### 📚 Documentation
- [API Reference](./api-reference/)
- [Test File Format](./api-reference/test-files)
- [Examples](./examples/)

### 🐛 Reporting Issues
When reporting issues, include:

1. **gRPC Testify version**: `./grpctestify.sh --version`
2. **Test file content** (sanitized)
3. **Error message** (complete)
4. **Environment details** (OS, Go version)
5. **Steps to reproduce**

### 💡 Tips for Better Tests

1. **Start simple**: Begin with basic unary calls
2. **Test incrementally**: Add complexity gradually  
3. **Use meaningful names**: Make test files descriptive
4. **Validate early**: Check JSON syntax before running
5. **Monitor servers**: Ensure stable gRPC services
6. **Version control**: Track test file changes

## Advanced Troubleshooting

### 🔧 Custom Debugging
For complex issues, you can:

1. **Enable trace mode**:
   ```bash
   set -x
   ./grpctestify.sh test.gctf
   set +x
   ```

2. **Check generated grpcurl commands**:
   Look for the actual grpcurl calls in verbose output

3. **Inspect intermediate files**:
   Temporary files are created during test execution

4. **Network analysis**:
   Use tools like `tcpdump` or `wireshark` for network issues

### 🏥 Recovery Strategies

When tests fail consistently:

1. **Reset environment**: Restart servers and clear caches
2. **Validate baseline**: Test with minimal examples first
3. **Check dependencies**: Update grpcurl, jq, and other tools
4. **Review changes**: Compare with working versions
5. **Isolate variables**: Test different servers, networks, or configurations

---

## Quick Reference

### Exit Codes
- `0`: All tests passed
- `1`: Test failures or errors
- `2`: Invalid arguments
- `3`: Missing dependencies

### Environment Variables
- `GRPCTESTIFY_ADDRESS`: Default server address
- `GRPCTESTIFY_TIMEOUT`: Default timeout (seconds)
- `GRPCTESTIFY_VERBOSE`: Enable verbose output

### File Extensions
- `.gctf`: gRPC test configuration files
- `.proto`: Protocol buffer definitions (for reference)

This troubleshooting guide covers the most common issues. For specific problems not covered here, consult the [API reference](./api-reference/) or create an issue with detailed information.

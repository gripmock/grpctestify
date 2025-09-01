# Reference Documentation

Comprehensive technical reference for gRPC Testify. Use this section to look up specific APIs, commands, formats, and configurations.

## 📚 Reference Sections

### 🖥️ [Command Line](api/command-line.md)
Complete reference for all CLI commands, flags, and options.

### 📄 [Test Files](api/test-files.md)
Everything about `.gctf` test files.

### 🔧 [Programming APIs](api/)
APIs for plugin development and integration.

### 📊 [Report Formats](api/report-formats.md)
Output formats and customization.

## 🔍 Quick Reference

### Essential Commands
```bash
# Run tests
grpctestify tests/                    # Run all tests in directory
grpctestify test.gctf                 # Run single test
grpctestify tests/ --parallel 4       # Parallel execution

# Generate reports
grpctestify tests/ --log-format junit # JUnit XML report
grpctestify tests/ --log-format json  # JSON report

# Plugin management
grpctestify --list-plugins            # List available plugins
grpctestify --create-plugin my_plugin # Create new plugin

# System
grpctestify --version                 # Show version
grpctestify --help                    # Show help
grpctestify --update                  # Update to latest version
```

### Test File Sections
```gctf
--- ADDRESS ---          # Required: gRPC server address
--- ENDPOINT ---         # Required: service method
--- REQUEST ---          # Required: request payload
--- RESPONSE ---         # Optional: expected response
--- ASSERTS ---          # Optional: custom assertions
--- REQUEST_HEADERS ---   # Optional: gRPC headers
--- TIMEOUT ---          # Optional: request timeout
--- ERROR ---            # Optional: expected error
```

### Common Assertions
```bash
# Response validation
.status == "OK"                      # Status check
.data | length > 0                   # Array length
.user.email | test("@")              # Regex match
.timestamp | tonumber > 0            # Type conversion

# Custom assertions (via plugins)
assert_response_time_under "100ms"   # Performance assertion
assert_header_present "X-Request-ID" # Header validation
assert_status_code 200               # HTTP status
```

## 📖 Navigation Guide

### For Developers
- Start with [Programming APIs](api/) for integration
- Check [Plugin API](api/plugin-api.md) for extensions
- Reference [State API](api/state-api.md) for data access

### For Test Writers
- Begin with [Test File Format](test-format/)
- Learn [Variables & Templating](test-format/variables.md)
- Follow [Best Practices](test-format/best-practices.md)

### For CI/CD Integration
- Review [CLI Commands](cli/commands.md)
- Configure [Report Formats](reports/)
- Set up [Configuration Files](cli/configuration.md)

### For Operations
- Use [Command Reference](cli/) for automation
- Check [Configuration](cli/configuration.md) for deployment
- Monitor with [Report Formats](reports/)

## 🔗 Related Documentation

- **[Getting Started](../getting-started/)** - Installation and first steps
- **[Guides](../guides/)** - Step-by-step tutorials
- **[Examples](../guides/examples/)** - Real-world implementations
- **[Plugin Development](../plugins/development/)** - Create custom plugins
- **[Advanced Topics](../advanced/)** - Deep technical content

## 📝 Contributing to Reference

Help improve the documentation:

1. **Report inaccuracies** - Found something wrong? Let us know
2. **Suggest improvements** - Ideas for better organization
3. **Add examples** - Real-world usage examples
4. **Update APIs** - Keep pace with new features

This reference is designed to be your go-to resource for all technical details about gRPC Testify.



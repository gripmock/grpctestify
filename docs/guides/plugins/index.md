# Plugin System

gRPC Testify features a powerful plugin architecture that allows you to extend functionality, create custom assertions, and integrate with external systems.

## 🔌 Plugin Architecture Overview

The plugin system is built around several key APIs:

- **[Plugin API](development/plugin-api.md)** - Core plugin interface and lifecycle
- **[State API](development/state-api.md)** - Access to centralized test state
- **[IO API](development/io-api.md)** - Synchronized output and logging
- **[Testing Framework](development/testing.md)** - Tools for testing plugins

## 🏗️ Plugin Categories

### Built-in Plugins
- **[Assertion Plugins](built-in/assertions.md)** - Custom test assertions
- **[Validation Plugins](built-in/validation.md)** - Data validation and type checking
- **[Report Plugins](built-in/reporting.md)** - Custom report formats
- **[Utility Plugins](built-in/utils.md)** - Helper functions and tools

### Community Plugins
- **[Plugin Catalog](community/catalog.md)** - Browse available community plugins
- **[Contributing Plugins](community/contributing.md)** - How to share your plugins

## 🚀 Getting Started with Plugins

### Using Existing Plugins

```bash
# List available plugins
grpctestify --list-plugins

# Plugin automatically loaded if present in:
# ~/.grpctestify/plugins/
# ./plugins/
# Custom directory via GRPCTESTIFY_PLUGIN_DIR
```

### Creating Your First Plugin

```bash
# Generate plugin template
grpctestify --create-plugin my_custom_assertion

# This creates:
# - grpc_my_custom_assertion.sh (main plugin)
# - grpc_my_custom_assertion.bats (tests)
# - grpc_my_custom_assertion.md (documentation)
```

### Plugin Development Quick Start

1. **[Read the Plugin API](development/plugin-api.md)** - Understand the interfaces
2. **[Follow Development Guide](development/)** - Step-by-step plugin creation
3. **[See Examples](../guides/examples/advanced/)** - Real plugin implementations
4. **[Test Your Plugin](development/testing.md)** - Ensure quality and reliability

## 🎯 Common Plugin Use Cases

### Custom Assertions
```bash
# Example: Custom response time assertion
assert_response_time_under "100ms"
assert_custom_header_present "X-Request-ID"
```

### External Integrations
```bash
# Example: Slack notifications
plugin_slack_notify_on_failure "channel-name"

# Example: Database validation
assert_database_record_exists "users" "id=123"
```

### Advanced Reporting
```bash
# Example: Performance metrics
plugin_performance_tracker_enable
plugin_performance_export_to "metrics.json"
```

## 📊 Plugin State Management

Plugins can read and write to the centralized test state:

```bash
# Read test execution data
total_tests=$(test_state_get "total_tests")
success_rate=$(test_state_get_success_rate)

# Store plugin-specific metadata
test_state_set_plugin_metadata "my_plugin" "version" "1.0.0"
test_state_set_test_metadata "$test_path" "my_plugin" "custom_metric" "42"
```

## 🔒 Plugin Security

### Best Practices
- Validate all input parameters
- Use safe temporary file creation
- Respect user permissions
- Handle errors gracefully
- Document security considerations

### Plugin Isolation
- Plugins run in the same process space
- Use namespace prefixing to avoid conflicts
- Clean up resources properly
- Follow the plugin lifecycle

## 📈 Plugin Performance

### Optimization Tips
- Cache expensive operations
- Use lazy loading where possible
- Minimize external dependencies
- Profile plugin execution time
- Use efficient data structures

### State API Performance
```bash
# Cache frequently accessed data
if [[ -z "$_cached_total_tests" ]]; then
    _cached_total_tests=$(test_state_get "total_tests")
fi

# Batch metadata operations
test_state_set_plugin_metadata "batch_plugin" "metric1" "value1"
test_state_set_plugin_metadata "batch_plugin" "metric2" "value2"
```

## 🛠️ Plugin Development Tools

### Validation
```bash
# Validate plugin compliance
grpctestify --validate-plugin my_plugin.sh
```

### Testing
```bash
# Run plugin tests
grpctestify --test-plugin my_plugin.sh

# Run tests with coverage
PLUGIN_COVERAGE=true grpctestify --test-plugin my_plugin.sh
```

### Installation
```bash
# Install plugin system-wide
grpctestify --install-plugin my_plugin.sh

# Install to custom directory
grpctestify --install-plugin my_plugin.sh --plugin-dir ~/my-plugins
```

## 🌟 Featured Community Plugins

### Authentication Plugins
- **grpc-jwt-auth** - JWT token validation
- **grpc-oauth2** - OAuth2 integration
- **grpc-api-key** - API key authentication

### Monitoring & Observability
- **grpc-prometheus** - Prometheus metrics export
- **grpc-jaeger** - Distributed tracing
- **grpc-datadog** - DataDog integration

### Data Validation
- **grpc-schema-validator** - JSON schema validation
- **grpc-regex-matcher** - Advanced regex matching
- **grpc-fuzzer** - Fuzz testing support

## 📚 Resources

- **[Plugin Development Guide](development/)** - Complete development documentation
- **[API Reference](../reference/api/)** - Detailed API documentation
- **[Examples](../guides/examples/advanced/)** - Real-world plugin examples


## 🤝 Contributing

Help grow the plugin ecosystem:

1. **Create useful plugins** - Solve real problems
2. **Share with community** - Publish to plugin catalog
3. **Improve documentation** - Help others learn
4. **Report bugs** - Help improve the system
5. **Suggest features** - Share your ideas

Ready to build your first plugin? Start with the [Plugin Development Guide](development/)!



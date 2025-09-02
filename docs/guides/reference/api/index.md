# API Reference

Complete reference documentation for gRPC Testify.

## Overview

gRPC Testify provides a comprehensive testing framework for gRPC services using configuration files. This section documents all available features, syntax, and configuration options.

## Reference Sections

### [Command Line Interface](./command-line)
Complete documentation of all command-line options, flags, and usage patterns.

### [Test File Format](./test-files)  
Detailed specification of the `.gctf` test file format, including all sections and syntax.

### [Assertions & Validation](./assertions)
Comprehensive guide to assertion syntax, jq expressions, and validation patterns.

### [Plugin System](./plugins)
Documentation for the extensible plugin system and custom assertion development.

### [Report Formats](./report-formats)
Complete guide to output formats: console and JUnit XML reports.

### [Type Validation](./type-validation)
Advanced type validators for UUID, timestamps, URLs, emails, and more specialized data types.

### [Plugin Development](./plugin-development)
Official guide for developing custom plugins using the Plugin API.

## Quick Reference

### Basic Test File Structure
```php
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
service.Method

--- REQUEST ---
{
  "field": "value"
}

--- RESPONSE ---
{
  "result": "*"
}

--- ASSERTS ---
.result | length > 0
```

### Common Command Usage
```bash
# Run single test
./grpctestify.sh test.gctf

# Run all tests in directory
./grpctestify.sh tests/

# Run with options
./grpctestify.sh --parallel 4 --verbose tests/
```

## See Also

- [Getting Started Guide](../../getting-started/installation)
- [Examples](../guides/examples/)

# gRPC Testify

<img align="right" width="150" height="150" src="https://github.com/user-attachments/assets/d331a8db-4f4c-4296-950c-86b91ea5540a">

[![Release](https://img.shields.io/badge/Release-v1.0.0-success?logo=github)](https://github.com/gripmock/grpctestify/releases/latest)
[![Install in VS Code](https://img.shields.io/badge/VS_Code-Marketplace-blue?logo=visualstudiocode)](https://marketplace.visualstudio.com/items?itemName=gripmock.grpctestify)
[![GitHub Repo](https://img.shields.io/badge/GitHub-Repo-green?logo=github)](https://github.com/gripmock/grpctestify-vscode)
[![Documentation](https://img.shields.io/badge/Docs-VitePress-646CFF?logo=vitepress)](https://gripmock.github.io/grpctestify/)
[![Generator](https://img.shields.io/badge/Generator-Interactive-FF6B6B?logo=vue.js)](https://gripmock.github.io/grpctestify/generator)

Automate gRPC server testing with configuration files. Validate endpoints, requests, and responses using simple `.gctf` files.

## 🚀 Quick Links

- **[📚 Documentation](https://gripmock.github.io/grpctestify/)** - Complete guides, examples, and API reference
- **[🎯 Interactive Generator](https://gripmock.github.io/grpctestify/generator)** - Create .gctf files with visual interface
- **[💡 Examples](https://gripmock.github.io/grpctestify/examples/)** - Real-world gRPC testing scenarios

## ✨ Features

- 🌊 **gRPC streaming support**: Basic unary calls (streaming patterns under development)
- ⚡ **Parallel execution** with `--parallel N` option
- 📊 **Progress indicators** with `--progress=dots`
- 🎯 **Advanced assertions** with jq-based validation
- 🔧 **Inline options** for response validation (tolerance, partial matching, etc.)
- 🔄 **Self-updating** with `--update` flag
- 🛡 **Security** with checksum verification
- 📂 **Recursive directory processing**
- 🎨 **Colored output** with emoji support
- 🔍 **Automatic dependency checks**
- ⚠️ **Dedicated warning log level**
- 🛠 **Flexible configuration format**

## 📋 Requirements

- [grpcurl](https://github.com/fullstorydev/grpcurl)
- [jq](https://stedolan.github.io/jq/)
- Docker (for integration tests)

## 🚀 Quick Start

### Installation

```bash
# Download the latest release
curl -LO https://github.com/gripmock/grpctestify/releases/latest/download/grpctestify.sh
chmod +x grpctestify.sh

# Verify installation
./grpctestify.sh --version
```

Expected output:
```
➜  ~ ./grpctestify.sh --version
grpctestify v1.0.0
```

### Basic Usage

```bash
# Single test file
./grpctestify.sh test_case.gctf

# Directory mode (recursive)
./grpctestify.sh examples/scenarios/

# Parallel execution with progress
./grpctestify.sh examples/scenarios/ --parallel 4 --progress=dots

# Verbose output
./grpctestify.sh --verbose examples/scenarios/

# Disable colors
./grpctestify.sh --no-color test_case.gctf

# Check for updates
./grpctestify.sh --update
```

## 📝 Test File Format (`.gctf`)

```bash
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
package.service/Method

--- REQUEST ---
{
  "key": "value"
}

--- RESPONSE ---
{
  "status": "OK"
}

--- ASSERTS ---
.status == "OK"
.data | length > 0
```

## 🌊 Streaming Examples

### Client Streaming
Multiple REQUEST blocks followed by a single RESPONSE:

```bash
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
chat.ChatService/SendMessages

--- REQUEST ---
{ "name": "hello" }

--- REQUEST ---
{ "name": "world" }

--- REQUEST ---
{ "name": "from" }

--- REQUEST ---
{ "name": "grpctestify" }

--- RESPONSE ---
{ "message": "hello world from grpctestify" }
```

### Server Streaming
Single REQUEST followed by multiple RESPONSE blocks:

```bash
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
news.NewsService/Subscribe

--- REQUEST ---
{ "message": "hello world from grpctestify" }

--- RESPONSE ---
{ "name": "hello" }

--- RESPONSE ---
{ "name": "world" }

--- RESPONSE ---
{ "name": "from" }

--- RESPONSE ---
{ "name": "grpctestify" }
```

### Bidirectional Streaming
Alternating REQUEST and RESPONSE blocks:

```bash
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
math.Calculator/SumStream

--- REQUEST ---
{ "value": 2 }

--- RESPONSE ---
{ "sum": 2 }

--- REQUEST ---
{ "value": 1 }

--- RESPONSE ---
{ "sum": 3 }

--- REQUEST ---
{ "value": 0 }

--- RESPONSE ---
{ "sum": 3 }
```

## 🎯 Advanced Features

### Assertions
Use jq expressions to validate responses:

```bash
--- ASSERTS ---
.status == "success"
.data | length > 0
.error == null
.user.id | type == "number"
```

### Plugin System
Use `@plugin()` syntax for specialized assertions:

```bash
--- ASSERTS ---
.success == true

# Standard jq assertions
.user.name | type == "string"
.user.age | type == "number" and . >= 0

# Plugin-based assertions
@header("x-api-version") == "1.0.0"
@trailer("x-processing-time") == "45ms"

# Advanced type validation
@uuid(.user.id, "v4") == true
@email(.user.email) == true  
@timestamp(.user.created_at, "iso8601") == true
@url(.user.avatar_url, "https") == true
@ip(.client_ip, "v4") == true
```

**Available Plugins:**
- `@header("name")` - Assert gRPC response headers
- `@trailer("name")` - Assert gRPC response trailers
- `@uuid("field", "version")` - Validate UUID fields with optional version checking
- `@timestamp("field", "format")` - Validate timestamp formats (ISO 8601, RFC 3339, Unix)
- `@url("field", "scheme")` - Validate URLs with optional scheme restrictions
- `@email("field", "strict")` - Validate email addresses with strict mode option
- `@ip("field", "version")` - Validate IP addresses (IPv4/IPv6)
- Support for both exact matching (`==`) and pattern testing (`| test()`)
- More flexible than legacy RESPONSE_HEADERS/RESPONSE_TRAILERS sections

### Report Formats

Generate reports in multiple formats for different use cases:

```bash
# Console output (default)
./grpctestify.sh tests/

# JSON for CI/CD integration
./grpctestify.sh tests/ --report-format=json --report-output=results.json

# XML (JUnit compatible) for test management tools
./grpctestify.sh tests/ --report-format=xml --report-output=junit.xml

# Interactive HTML reports
./grpctestify.sh tests/ --report-format=html --report-output=report.html
```

**Supported Formats:**
- `console` - Human-readable colored output
- `json` - Machine-readable JSON with full metadata
- `xml` - JUnit-compatible XML for CI/CD tools
- `html` - Interactive web reports with charts and filtering

**ASSERTS vs RESPONSE:**
- **ASSERTS** (priority): Flexible jq-based validation
- **RESPONSE** (fallback): Strict exact match comparison
- If **ASSERTS** are present, **RESPONSE** is optional
- **Order of sections determines message processing order** - first section processes first message, second section processes second message

### Inline Options
Configure test behavior directly in the file:

```bash
--- OPTIONS ---
tolerance: 0.1
partial: true
redact: ["password", "token"]
```

### Progress Indicators
Choose your preferred progress display:

```bash
# Dots progress
./grpctestify.sh tests/ --progress=dots

# Bar progress  
./grpctestify.sh tests/ --progress=bar

# No progress
./grpctestify.sh tests/ --progress=none
```

## 🏗️ Project Structure

```
grpctestify/
├── grpctestify.sh               # Main executable
├── bashly.yml                   # Build configuration
├── Makefile                     # Build and test automation
├── src/                         # Modular source code
│   ├── lib/                     # Core libraries
│   ├── core/                    # Application logic
│   ├── commands/                # Command implementations
│   └── test/                    # Test framework
├── examples/                    # Test data and examples
│   ├── scenarios/               # .gctf test files organized by type
│   ├── contracts/               # Protocol buffer definitions
│   ├── fixtures/                # Proto files and stubs
│   ├── servers/                 # Test server implementations
│   └── benchmarks/              # Performance benchmarks
├── scripts/                     # Build utilities
└── index.html                   # Web-based .gctf generator
```

## 🛠️ Development

### Prerequisites
```bash
# Install dependencies
make setup

# Verify installation
make check
```

### Build and Test
```bash
# Generate grpctestify.sh from source
make generate

# Run unit tests
make unit-tests

# Run integration tests (requires server)
make integration-tests

# Run all tests
make test-all

# Start test server
make up

# Stop server
make down

# Show all available commands
make help
```

### Development Workflow
```bash
# Watch for changes and regenerate
make dev

# Show project structure
make tree

# Run coverage analysis
make coverage

# Clean up
make clean
```

## 🔧 Editor Support

Enhance your `.gctf` workflow with the official [VS Code extension](https://marketplace.visualstudio.com/items?itemName=gripmock.grpctestify):

- Syntax highlighting for `.gctf` files
- Snippets for quick test creation
- Section folding
- Validation warnings
- Quick documentation

## 🌐 Web Generator

Use the built-in web interface to generate `.gctf` files:

```bash
# Open index.html in your browser
open index.html
```

Features:
- Interactive form for test creation
- Support for all gRPC streaming types
- Built-in examples and templates
- Real-time preview

## 🔒 Security Features

- Automatic checksum verification during updates
- Secure download process with SHA-256 validation
- Warning system for potential security issues
- Safe error handling and validation

## 📚 Examples

Check out the comprehensive examples in `examples/scenarios/`:

- **Basic tests**: Simple unary calls
- **Stream tests**: All streaming patterns
- **Edge cases**: Error handling and validation
- **New features**: Latest functionality demonstrations

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Follow shell scripting best practices
4. Add test cases for new features
5. Ensure all tests pass: `make test-all`
6. Submit a pull request

## 📄 License

[MIT License](LICENSE) © 2025 GripMock

---

**Need help?** Check out the [VS Code extension](https://marketplace.visualstudio.com/items?itemName=gripmock.grpctestify) or open an issue on GitHub.

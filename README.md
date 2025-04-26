# gRPC Testify

<img align="right" width="150" height="150"  src="https://github.com/user-attachments/assets/d331a8db-4f4c-4296-950c-86b91ea5540a">

[![Install in VS Code](https://img.shields.io/badge/VS_Code-Marketplace-blue?logo=visualstudiocode)](https://marketplace.visualstudio.com/items?itemName=gripmock.grpctestify)
[![GitHub Repo](https://img.shields.io/badge/GitHub-Repo-green?logo=github)](https://github.com/gripmock/grpctestify-vscode)

Automate gRPC server testing with configuration files. Validate endpoints, requests, and responses using simple `.gctf` files.

## What's New 🎉
- Automatic self-update with checksum verification
- Enhanced warning system with dedicated log level
- Improved error handling and validation
- Better security with SHA-256 verification

## Features
- 🔄 **Self-updating** with `--update` flag
- 🛡 **Security** with checksum verification
- 📂 Recursive directory processing
- 🎨 Colored output with emoji support
- 🔍 Automatic dependency checks
- ⚠️ Dedicated warning log level
- 🛠 Flexible configuration format
- **🌊 Full gRPC streaming support**: unary, client, server, and bidirectional streams
- ⚡ Fast sequential test execution
- 📄 Version information display

## Requirements
- [grpcurl](https://github.com/fullstorydev/grpcurl)
- [jq](https://stedolan.github.io/jq/)

## Editor Support 🚀
Enhance your `.gctf` workflow with the official [VS Code extension](https://marketplace.visualstudio.com/items?itemName=gripmock.grpctestify):
- Syntax highlighting for `.gctf` files
- Snippets for quick test creation
- Section folding
- Validation warnings
- Quick documentation

## Installation

### Using Homebrew (macOS/Linux)
```bash
# Tap the repository
brew tap gripmock/tap

# Install grpctestify
brew install grpctestify

# Verify installation
grpctestify --version
```

### Manual Installation (Dependencies)
1. **Install Dependencies**:
   ```bash
   # macOS
   brew install grpcurl jq

   # Ubuntu/Debian
   sudo apt install -y grpcurl jq

   # Verify installation
   grpcurl --version
   jq --version
   ```

2. **Download the Script**:
   Use `curl` or `wget` to download the `grpctestify.sh` script from the latest release:
   ```bash
   # Using curl
   curl -LO https://github.com/gripmock/grpctestify/releases/latest/download/grpctestify.sh

   # Using wget
   wget https://github.com/gripmock/grpctestify/releases/latest/download/grpctestify.sh
   ```

3. **Make the Script Executable**:
   After downloading, make the script executable:
   ```bash
   chmod +x grpctestify.sh
   ```

4. **Move the Script to a Directory in Your PATH**:
   Optionally, move the script to a directory in your `PATH` for easier access:
   ```bash
   sudo mv grpctestify.sh /usr/local/bin/grpctestify
   ```

5. **Verify Installation**:
   Check that the script is working correctly:
   ```bash
   grpctestify --version
   ```

## Usage
```bash
# Single test file
./grpctestify.sh test_case.gctf

# Directory mode (recursive)
./grpctestify.sh tests/

# Verbose output mode
./grpctestify.sh --verbose tests/

# Disable colors
./grpctestify.sh --no-color test_case.gctf

# Check for updates
./grpctestify.sh --update

# Show version
./grpctestify.sh --version
```

## Test File Format (`.gctf`)
```php
--- ADDRESS ---
localhost:50051

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
```

## Streaming Examples 🌊

### Client Streaming
Multiple REQUEST blocks followed by a single RESPONSE
```php
--- ADDRESS ---
localhost:50051

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
Single REQUEST followed by multiple RESPONSE blocks
```php
--- ADDRESS ---
localhost:50051

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
Alternating REQUEST and RESPONSE blocks
```php
--- ADDRESS ---
localhost:50051

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

## Security Features 🔒
- Automatic checksum verification during updates
- Secure download process with SHA-256 validation
- Warning system for potential security issues

## Local Development
### Quick Start
```bash
# Install dependencies
make setup

# Start test server
make up

# Run all tests
make test

# Stop server
make down
```

## Contributing
1. Fork repository
2. Create feature branch
3. Follow shell scripting best practices
4. Add test cases
5. Submit pull request

## License
[MIT License](LICENSE) © 2025 GripMock

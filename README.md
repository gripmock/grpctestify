# gRPC Testify

[![Install in VS Code](https://img.shields.io/badge/VS_Code-Marketplace-blue?logo=visualstudiocode)](https://marketplace.visualstudio.com/items?itemName=gripmock.grpctestify)
[![GitHub Repo](https://img.shields.io/badge/GitHub-Repo-green?logo=github)](https://github.com/gripmock/grpctestify-vscode)

Automate gRPC server testing with configuration files. Validate endpoints, requests, and responses using simple `.gctf` files.

## Features
- 📂 Recursive directory processing
- 🎨 Colored output with emoji support
- 🔍 Automatic dependency checks
- 🛠 Flexible configuration format
- ⚡ Fast sequential test execution
- 📄 Version information display

## Requirements
- [grpcurl](https://github.com/fullstorydev/grpcurl)
- [jq](https://stedolan.github.io/jq/)

## Editor Support 🚀
Enhance your .gctf workflow with official [VS Code extension](https://marketplace.visualstudio.com/items?itemName=gripmock.grpctestify):
- Syntax highlighting for .gctf files
- Snippets for quick test creation
- Section folding
- Validation warnings
- Quick documentation

## Installation
```bash
# macOS
brew install grpcurl jq

# Ubuntu/Debian
sudo apt install -y grpcurl jq

# Verify installation
grpcurl --version
jq --version
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

# Show version
./grpctestify.sh --version
```

## Test File Format (`.gctf`)
```text
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

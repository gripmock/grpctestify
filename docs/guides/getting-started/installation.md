# Installation

Learn how to install and set up gRPC Testify on your system.

## 📋 Prerequisites

Before installing gRPC Testify, ensure you have the following dependencies:

- **grpcurl** - gRPC client for making requests
- **jq** - JSON processor for assertions
- **bash** - Shell environment (version 4.0+)
- **Docker** - For running example servers (optional)

## 🚀 Quick Installation

### Download and Install

```bash
# Download the latest release
curl -LO https://github.com/gripmock/grpctestify/releases/latest/download/grpctestify.sh

# Make executable
chmod +x grpctestify.sh

# Move to a directory in your PATH (optional)
sudo mv grpctestify.sh /usr/local/bin/grpctestify.sh
```

### Verify Installation

```bash
# Check if grpctestify is working
./grpctestify.sh --version

# Or if moved to PATH
grpctestify.sh --version
```

## 📦 Package Manager Installation

### macOS (Homebrew)

```bash
# Install via Homebrew
brew install gripmock/grpctestify/grpctestify

# Verify installation
grpctestify.sh --version
```

### Linux (Package Managers)

#### Ubuntu/Debian
```bash
# Add repository
curl -fsSL https://gripmock.github.io/grpctestify/gpg | sudo gpg --dearmor -o /usr/share/keyrings/grpctestify-archive-keyring.gpg

# Add repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/grpctestify-archive-keyring.gpg] https://gripmock.github.io/grpctestify/apt stable main" | sudo tee /etc/apt/sources.list.d/grpctestify.list

# Install
sudo apt update
sudo apt install grpctestify
```

#### CentOS/RHEL/Fedora
```bash
# Add repository
sudo dnf config-manager --add-repo https://gripmock.github.io/grpctestify/yum/grpctestify.repo

# Install
sudo dnf install grpctestify
```

## 🔧 Dependencies Installation

### Install grpcurl

#### macOS
```bash
brew install grpcurl
```

#### Ubuntu/Debian
```bash
# Download latest release
curl -LO https://github.com/fullstorydev/grpcurl/releases/latest/download/grpcurl_$(uname -s)_$(uname -m).tar.gz

# Extract and install
tar -xzf grpcurl_*.tar.gz
sudo mv grpcurl /usr/local/bin/
```

#### CentOS/RHEL/Fedora
```bash
sudo dnf install grpcurl
```

### Install jq

#### macOS
```bash
brew install jq
```

#### Ubuntu/Debian
```bash
sudo apt install jq
```

#### CentOS/RHEL/Fedora
```bash
sudo dnf install jq
```

## 🐳 Docker Installation

If you prefer to use Docker:

```bash
# Pull the official image
docker pull gripmock/grpctestify:latest

# Run tests using Docker
docker run -v $(pwd):/workspace gripmock/grpctestify:latest /workspace/tests/*.gctf
```

## 🔍 Verify Your Setup

Run a simple test to verify everything is working:

```bash
# Create a test file
cat > test.gctf << 'EOF'
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
grpc.health.v1.Health/Check

--- REQUEST ---
{}

--- RESPONSE ---
{
  "status": "SERVING"
}
EOF

# Run the test
./grpctestify.sh test.gctf
```

## ⚙️ Configuration

### Environment Variables

Set these environment variables for customization:

```bash
# Default gRPC address (used when ADDRESS section is missing)
export GRPCTESTIFY_ADDRESS="localhost:4770"

# Plugin directory
export GRPCTESTIFY_PLUGIN_DIR="$HOME/.grpctestify/plugins"

# Log level (debug, info, warning, error)
export GRPCTESTIFY_LOG_LEVEL="info"

# Parallel execution (number of concurrent tests)
# Use CLI flags instead of environment variables for these options:
# --parallel 4
```

### Configuration File

Create a configuration file at `~/.grpctestify/config.yaml`:

```yaml
# Default settings
defaults:
  address: "localhost:4770"
  timeout: 30
  parallel: 4

# Logging
logging:
  level: "info"
  format: "text"

# Plugins
plugins:
  directory: "~/.grpctestify/plugins"
  auto_load: true

# Reports
reports:
  junit:
    enabled: true
    output: "test-results.xml"
  json:
    enabled: false
    output: "test-results.json"
```

## 🚀 Next Steps

Now that you have gRPC Testify installed:

1. **[Write Your First Test](first-test.md)** - Create and run your first test
2. **[Learn Basic Concepts](basic-concepts.md)** - Understand the fundamentals
3. **[Explore Examples](../guides/examples/basic/real-time-chat)** - See real-world usage

## 🛠️ Troubleshooting

### Common Issues

#### "command not found: grpcurl"
Install grpcurl using the instructions above.

#### "command not found: jq"
Install jq using your package manager.

#### Permission Denied
Make sure the script is executable:
```bash
chmod +x grpctestify.sh
```

#### TLS Certificate Issues
For development, you can skip certificate verification:
```bash
export GRPCTESTIFY_TLS_INSECURE=true
```

### Getting Help

- **[Troubleshooting Guide](../advanced/troubleshooting)** - Common problems and solutions
- **[GitHub Issues](https://github.com/gripmock/grpctestify/issues)** - Report bugs and request features


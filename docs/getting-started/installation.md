# Installation

Multiple ways to install gRPC Testify on your system.

## 📦 Quick Install (Recommended)

The fastest way to get started:

```bash
curl -sSL https://raw.githubusercontent.com/gripmock/grpctestify/main/install.sh | bash
```

This will:
- Download the latest version
- Verify checksums for security
- Install to `/usr/local/bin/grpctestify`
- Set proper permissions

## 🔧 Manual Installation

### Download Release

```bash
# Download latest release
wget https://github.com/gripmock/grpctestify/releases/latest/download/grpctestify.sh

# Make executable
chmod +x grpctestify.sh

# Install globally (optional)
sudo mv grpctestify.sh /usr/local/bin/grpctestify
```

### From Source

```bash
# Clone repository
git clone https://github.com/gripmock/grpctestify.git
cd grpctestify

# Install bashly (required for building)
gem install bashly

# Generate script
make generate

# Install
sudo cp grpctestify.sh /usr/local/bin/grpctestify
sudo chmod +x /usr/local/bin/grpctestify
```

## 🧰 Dependencies

gRPC Testify requires these tools to be installed:

### Required Dependencies

```bash
# macOS (using Homebrew)
brew install grpcurl jq

# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y jq
# For grpcurl, download from GitHub releases

# CentOS/RHEL
sudo yum install -y jq
# For grpcurl, download from GitHub releases
```

### Installing grpcurl

```bash
# Download latest grpcurl
curl -LO https://github.com/fullstorydev/grpcurl/releases/latest/download/grpcurl_linux_x86_64.tar.gz
tar -xzf grpcurl_linux_x86_64.tar.gz
sudo mv grpcurl /usr/local/bin/
sudo chmod +x /usr/local/bin/grpcurl
```

## ✅ Verify Installation

```bash
# Check gRPC Testify version
grpctestify --version

# Verify dependencies
grpcurl --version
jq --version

# Test basic functionality
grpctestify --help
```

Expected output:
```
gRPC Testify v1.0.0
grpcurl v1.8.9
jq-1.6
```

## 🔄 Updates

Keep your installation up to date:

```bash
# Auto-update to latest version
grpctestify --update

# Check for updates without installing
grpctestify --update --dry-run
```

## 🐳 Docker Usage

Run gRPC Testify in a container:

```bash
# Pull official image
docker pull gripmock/grpctestify:latest

# Run tests
docker run --rm -v $(pwd):/workspace gripmock/grpctestify:latest /workspace/tests/

# Interactive shell
docker run --rm -it -v $(pwd):/workspace gripmock/grpctestify:latest bash
```

## 🚀 IDE Integration

### VS Code Extension

Install the official VS Code extension for enhanced .gctf editing:

1. Open VS Code
2. Go to Extensions (Ctrl+Shift+X)
3. Search for "gRPCTestify"
4. Click Install

Features:
- Syntax highlighting for .gctf files
- Auto-completion
- Inline validation
- Test runner integration

### Other Editors

For other editors, you can use the generic JSON syntax highlighting for the REQUEST/RESPONSE sections.

## 🛠️ Troubleshooting

### Permission Denied

```bash
# Fix permissions
chmod +x grpctestify
```

### Command Not Found

```bash
# Add to PATH
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Dependency Issues

```bash
# Check if dependencies are in PATH
which grpcurl
which jq

# If missing, reinstall dependencies
# See dependency installation section above
```

## 🔗 Next Steps

Once installed, proceed to [Your First Test](first-test.md) to write and run your first gRPC test.
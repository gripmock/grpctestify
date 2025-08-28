# Installation Guide

This guide will help you install and set up gRPC Testify on your system.

## 📋 Prerequisites

Before installing gRPC Testify, ensure you have the following prerequisites:

### Required Dependencies

- **Bash 4.0+** - The framework is built on Bash
- **curl** - For downloading dependencies
- **jq** - For JSON processing
- **grpcurl** - For gRPC communication
- **Docker** (optional) - For containerized testing

### System Requirements

- **Operating System**: Linux, macOS, or Windows (with WSL)
- **Memory**: Minimum 512MB RAM
- **Disk Space**: 100MB for installation
- **Network**: Internet connection for downloading dependencies

## 🚀 Installation Methods

### Method 1: Clone from Repository

The recommended way to install gRPC Testify:

```bash
git clone https://github.com/gripmock/grpctestify.git
cd grpctestify
```

This will:
- Download the complete source code
- Include all examples and documentation
- Allow you to contribute back to the project

### Method 2: Direct Download

#### Step 1: Download the Repository

```bash
# Create installation directory
mkdir -p ~/grpctestify
cd ~/grpctestify

# Download the repository
curl -L -o grpctestify.zip https://github.com/gripmock/grpctestify/archive/main.zip

# Extract the archive
unzip grpctestify.zip
mv grpctestify-main/* .
rm -rf grpctestify-main grpctestify.zip
```

#### Step 2: Install Dependencies

**On Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y bash jq curl
```

**On CentOS/RHEL:**
```bash
sudo yum install -y bash jq curl
```

**On macOS:**
```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dependencies
brew install bash jq curl
```

#### Step 3: Install grpcurl

```bash
# Download grpcurl
curl -L -o grpcurl.tar.gz https://github.com/fullstorydev/grpcurl/releases/latest/download/grpcurl_linux_x86_64.tar.gz

# Extract and install
tar -xzf grpcurl.tar.gz
sudo mv grpcurl /usr/local/bin/
sudo chmod +x /usr/local/bin/grpcurl
```

#### Step 4: Set Up Environment

```bash
# Add to your shell profile (~/.bashrc, ~/.zshrc, etc.)
echo 'export PATH="$HOME/grpctestify:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Method 3: Using Docker (Custom Build)

If you prefer using Docker, you can build your own image:

```bash
# Build the Docker image
docker build -t grpctestify .

# Create an alias for easy usage
echo 'alias grpctestify="docker run --rm -v $(pwd):/workspace -w /workspace grpctestify"' >> ~/.bashrc
source ~/.bashrc
```

## ✅ Verification

After installation, verify that everything is working:

```bash
# Check gRPC Testify version
./grpctestify.sh --version

# Check dependencies
./grpctestify.sh --check-deps

# Run a simple test
./grpctestify.sh --help
```

Expected output:
```
gRPC Testify v1.0.0
Usage: grpctestify.sh [OPTIONS] &lt;test-file-or-directory&gt;

Options:
  --help, -h          Show this help message
  --version, -v       Show version information
  --verbose           Enable verbose output
  --parallel N        Run tests in parallel (N workers)
  --progress TYPE     Progress display type (dots, bar, none)
  --timeout SECONDS   Global timeout for all tests
  --no-color          Disable colored output
  --check-deps        Check system dependencies
```

## 🔧 Configuration

### Environment Variables

Set these environment variables for customization:

```bash
# Default gRPC server address
export GRPCTESTIFY_ADDRESS=localhost:4770

# Default timeout for tests (seconds)
export GRPCTESTIFY_TIMEOUT=30

# Default parallel workers
export GRPCTESTIFY_PARALLEL=4

# Progress display type
export GRPCTESTIFY_PROGRESS=dots

# Disable colors
export GRPCTESTIFY_NO_COLOR=false
```

### Configuration File

Create a `.grpctestifyrc` file in your project root:

```json
{
  "address": "localhost:4770",
  "timeout": 30,
  "parallel": 4,
  "progress": "dots",
  "noColor": false,
  "verbose": false
}
```

## 🐛 Troubleshooting

### Common Issues

#### Issue: "command not found: grpctestify"
**Solution**: Ensure the installation directory is in your PATH:
```bash
echo 'export PATH="$HOME/grpctestify:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### Issue: "jq: command not found"
**Solution**: Install jq:
```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq

# CentOS/RHEL
sudo yum install jq
```

#### Issue: "grpcurl: command not found"
**Solution**: Install grpcurl:
```bash
curl -L -o grpcurl.tar.gz https://github.com/fullstorydev/grpcurl/releases/latest/download/grpcurl_linux_x86_64.tar.gz
tar -xzf grpcurl.tar.gz
sudo mv grpcurl /usr/local/bin/
```

#### Issue: Permission Denied
**Solution**: Make the script executable:
```bash
chmod +x grpctestify.sh
```

### Getting Help

If you encounter issues:

1. **Check Dependencies**: Run `./grpctestify.sh --check-deps`
2. **Enable Verbose Mode**: Run with `--verbose` flag
3. **Check Logs**: Look for error messages in the output
4. **Report Issues**: Create an issue on GitHub with:
   - Operating system and version
   - Installation method used
   - Full error output
   - Steps to reproduce

## 🔄 Updating

To update gRPC Testify to the latest version:

```bash
# If you cloned the repository
cd grpctestify
git pull origin main

# If you downloaded manually
cd ~/grpctestify
curl -L -o grpctestify.zip https://github.com/gripmock/grpctestify/archive/main.zip
unzip -o grpctestify.zip
mv grpctestify-main/* .
rm -rf grpctestify-main grpctestify.zip
```

## 🗑️ Uninstallation

To remove gRPC Testify:

```bash
# Remove installation directory
rm -rf ~/grpctestify

# Remove from PATH (edit ~/.bashrc, ~/.zshrc, etc.)
# Remove the line: export PATH="$HOME/grpctestify:$PATH"

# Remove configuration file
rm -f ~/.grpctestifyrc
```

## 📚 Next Steps

Now that you have gRPC Testify installed:

1. **Learn the Basics**: Read the [Quick Start Guide](quick-start.md)
2. **Understand Concepts**: Check out [Basic Concepts](basic-concepts.md)
3. **Explore Examples**: Browse the [Examples](../examples/)
4. **Write Your First Test**: Follow the [Quick Start Guide](quick-start.md)

---

**Ready to start testing?** Head over to the [Quick Start Guide](quick-start.md) to write your first gRPC test!

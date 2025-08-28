# Development

This section contains development-related documentation for contributors and maintainers of the gRPC Testify project.

## 📋 Development Guides

### [CI/CD Workflows](./ci-cd.md)
Complete documentation of GitHub Actions workflows used for continuous integration and deployment, including:

- **Core Workflows**: Main CI/CD pipeline and examples testing
- **Specialized Workflows**: Security scanning, linting, and quality checks
- **Release Management**: Automated releases and asset distribution
- **Configuration**: Platform support, triggers, and dependencies
- **Troubleshooting**: Common issues and solutions

## 🚀 Quick Links

- **[Contributing Guide](https://github.com/gripmock/grpctestify/blob/main/CONTRIBUTING.md)** - How to contribute to the project
- **[Code of Conduct](https://github.com/gripmock/grpctestify/blob/main/CODE_OF_CONDUCT.md)** - Community guidelines
- **[License](https://github.com/gripmock/grpctestify/blob/main/LICENSE)** - Project license information

## 🛠️ Development Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/gripmock/grpctestify.git
   cd grpctestify
   ```

2. **Install dependencies**:
   ```bash
   # Install required tools
   brew install grpcurl jq bats-core
   
   # Or using package managers on Linux
   # apt-get install jq
   # npm install -g @fullstorydev/grpcurl
   ```

3. **Run tests**:
   ```bash
   make test
   ```

4. **Build documentation**:
   ```bash
   npm install
   npm run docs:dev
   ```

## 🧪 Testing

- **Unit Tests**: BATS tests for individual components
- **Integration Tests**: Example-based testing with real gRPC servers
- **End-to-end Tests**: Complete workflow testing via GitHub Actions

## 📦 Release Process

Releases are automated via GitHub Actions:

1. Create and push a version tag: `git tag v1.0.1 && git push origin v1.0.1`
2. GitHub Actions automatically:
   - Runs all tests
   - Generates release notes
   - Creates release assets
   - Updates documentation

## 🔧 Tools and Dependencies

- **Bash**: Core scripting language
- **BATS**: Testing framework for Bash scripts
- **ShellCheck**: Static analysis for shell scripts
- **grpcurl**: gRPC client for testing
- **jq**: JSON processor for response validation
- **VitePress**: Documentation generator

---

For questions or support, please [open an issue](https://github.com/gripmock/grpctestify/issues) on GitHub.

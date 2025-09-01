# Development & CI/CD

Resources for developers and continuous integration with gRPC Testify.

## 🔄 CI/CD Integration

### GitHub Actions
```yaml
name: gRPC Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install gRPC Testify
        run: |
          curl -sSL https://raw.githubusercontent.com/gripmock/grpctestify/main/install.sh | bash
      - name: Run Tests
        run: |
          grpctestify tests/ --log-format junit --log-output results.xml
      - name: Publish Test Results
        uses: dorny/test-reporter@v1
        with:
          name: gRPC Tests
          path: results.xml
          reporter: java-junit
```

### Docker Integration
```dockerfile
FROM golang:1.25-alpine AS builder
RUN apk add --no-cache bash curl
RUN curl -sSL https://raw.githubusercontent.com/gripmock/grpctestify/main/install.sh | bash

FROM alpine:latest
RUN apk add --no-cache bash jq
COPY --from=builder /usr/local/bin/grpctestify /usr/local/bin/
COPY tests/ /tests/
CMD ["grpctestify", "/tests"]
```

### Environment Variables
| Variable | Description | Default |
|----------|-------------|---------|
| `GRPCTESTIFY_ADDRESS` | Default server address | `localhost:4770` |
| `GRPCTESTIFY_ADDRESS` | Default gRPC server address | `localhost:4770` |
| `GRPCTESTIFY_PLUGIN_DIR` | Directory for external plugins | `~/.grpctestify/plugins` |
| `GRPCTESTIFY_PROGRESS` | Progress display mode | `auto` |

## 🛠️ Contributing

### Development Setup
```bash
# Clone and setup
git clone https://github.com/gripmock/grpctestify.git
cd grpctestify

# Install dependencies
gem install bashly

# Generate script
make generate

# Run tests
make test
```

### Code Style
- Follow shell scripting best practices
- Use consistent naming conventions
- Add comments for complex logic
- Include tests for new features

### Release Process
1. Update version numbers
2. Update changelog
3. Create release branch
4. Run full test suite
5. Create GitHub release

## 📚 Resources

- [GitHub Repository](https://github.com/gripmock/grpctestify)
- [Issue Tracker](https://github.com/gripmock/grpctestify/issues)
- [API Reference](../guides/reference/)
- [Examples](../guides/examples/)

# Guides

Welcome to the gRPC Testify guides! This comprehensive documentation will help you master gRPC testing from basics to advanced patterns.

## 🚀 Getting Started

Start your journey with these fundamental guides:

- **[Installation Guide](getting-started/installation)** - Set up gRPC Testify on your system
- **[Your First Test](getting-started/first-test)** - Write and run your first gRPC test
- **[Basic Concepts](getting-started/basic-concepts)** - Understand core gRPC testing principles

## 🎯 Testing Patterns

gRPC supports four main communication patterns. Each requires different testing approaches:

### Unary RPC (Request-Response)
- **Pattern**: One request → One response
- **Use Case**: Simple operations like CRUD, data retrieval
- **Testing**: Validate single request/response pair
- **[Testing Patterns](testing-patterns/testing-patterns)** - Universal testing principles

### Server Streaming (One-to-Many)
- **Pattern**: One request → Multiple responses
- **Use Case**: Real-time data, monitoring, live feeds
- **Testing**: Validate stream of responses from single request
- *Coming soon: Server Streaming Testing*

### Client Streaming (Many-to-One)
- **Pattern**: Multiple requests → One response
- **Use Case**: File uploads, batch operations, data collection
- **Testing**: Validate multiple requests result in single response
- *Coming soon: Client Streaming Testing*

### Bidirectional Streaming (Many-to-Many)
- **Pattern**: Multiple requests ↔ Multiple responses
- **Use Case**: Chat applications, real-time collaboration
- **Testing**: Validate complex request/response sequences
- *Coming soon: Bidirectional Streaming Testing*

## 🔧 Advanced Features

- **[Parallel Execution](testing-patterns/testing-patterns)** - Run tests concurrently
- **[Plugin System](../plugins/)** - Extend functionality with custom plugins
- **[Performance Testing](testing-patterns/testing-patterns)** - Optimize test execution

## 🏗️ Real-World Examples

- **[E-commerce Testing](real-world-examples/ecommerce)** - Complex business workflows
- **[IoT Device Testing](real-world-examples/iot)** - Device management and monitoring
- **[Financial Services](real-world-examples/fintech)** - Secure payment processing

## 🔒 Security Testing

- **[Authentication Testing](security-testing/auth)** - JWT, OAuth, API keys
- **[TLS Configuration](security-testing/tls)** - Certificate validation
- **[Access Control](security-testing/access-control)** - Permission testing

## 🔄 CI/CD Integration

- **[GitHub Actions](ci-cd/github-actions)** - Automated testing workflows
- **[Jenkins Integration](ci-cd/jenkins)** - Enterprise CI/CD setup
- **[Docker Testing](ci-cd/docker)** - Containerized testing environments

## 📊 Reporting & Monitoring

- **[Test Reports](reporting/test-reports)** - Understanding test results
- **[Performance Metrics](reporting/performance)** - Test execution analytics
- **[Coverage Analysis](reporting/coverage)** - Test coverage insights

## 🛠️ Troubleshooting

- **[Common Issues](../advanced/troubleshooting)** - Solutions to frequent problems
- **[Debug Techniques](../advanced/troubleshooting)** - Advanced debugging methods
- **[Performance Optimization](../advanced/troubleshooting)** - Speed up your tests

## Learning Path

We recommend following this learning path:

1. **Start with Installation** → Get gRPC Testify running
2. **Write Your First Test** → Understand basic concepts
3. **Master Unary Testing** → Learn the foundation
4. **Explore Advanced Patterns** → Handle complex scenarios
5. **Integrate with CI/CD** → Automate your testing
6. **Optimize Performance** → Scale your test suite

Ready to begin? Start with the [Installation Guide](getting-started/installation)!

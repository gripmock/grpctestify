# Report Formats

gRPC Testify supports console output, JUnit XML, and JSON export for test results.

## Supported Formats

### Console (Default)
Human-readable output with colors and progress indicators.

```bash
./grpctestify.sh tests/
```

**Features**:
- ✅ Color-coded output (pass/fail/timeout/skipped)
- 📊 Summary statistics
- 🔍 Detailed failure information
- 📈 Progress indicators (dots/none modes)
- ⏭️ Skipped test tracking (fail-fast mode)

**Example Output**:
```
───[ Test Execution Summary ]───
  📊 Total tests planned: 5
  🏃 Tests executed: 4
  ✅ Passed: 3
  ❌ Failed: 1
  ⏭️  Skipped (due to early stop): 1
  📈 Success rate: 75%
  ⏱️  Duration: 1s

❌ 💥 1 test(s) failed, 1 test(s) not executed
```

### JUnit XML Format
Machine-readable XML output for CI/CD integration.

```bash
./grpctestify.sh tests/ --log-format junit --log-output test-results.xml
```

**Features**:
- 📄 JUnit-compatible XML format
- ✅ Test case details (passed/failed/skipped)
- ⏭️ Proper skipped test handling (fail-fast mode)
- 🏷️ Test metadata (duration, failure messages)
- 🔗 CI/CD tool integration

### JSON Format
Structured JSON output for programmatic processing and API integrations.

```bash
./grpctestify.sh tests/ --log-format json --log-output test-results.json
```

**Features**:
- 📄 Structured JSON format
- ✅ Programmatic processing support
- 🔗 API integration compatibility
- 📊 Complete test metadata
- 🏷️ Machine-readable format

**Example JUnit XML Output**:
```xml
&lt;?xml version="1.0" encoding="UTF-8"?&gt;
<testsuites name="grpctestify" tests="3" failures="1" errors="0" skipped="2">
  <testsuite name="grpc-tests" tests="3" failures="1" skipped="2">
    <testcase name="test1_fail" file="test1_fail.gctf">
      <failure message="Test failed" type="AssertionError">
        Test execution failed
      </failure>
    </testcase>
    <testcase name="test2_skipped" file="test2_skipped.gctf">
      <skipped message="Test skipped due to early termination (fail-fast mode)" type="Skipped">
        Test was not executed because a previous test failed and fail-fast mode is enabled
      </skipped>
    </testcase>
  </testsuite>
</testsuites>
```

## Command Line Usage

### Basic Usage
```bash
# Default console output
./grpctestify.sh tests/

# Generate JUnit XML report
./grpctestify.sh tests/ --log-format junit --log-output results.xml
```

### Progress Modes
```bash
# Detailed output (default)
./grpctestify.sh tests/ --verbose

# Dots progress indicator
./grpctestify.sh tests/ --parallel auto
```

## Best Practices

### 1. **Local Development**
Use verbose mode for detailed debugging:
```bash
./grpctestify.sh tests/ --verbose
```

### 2. **CI/CD Integration**
Use JUnit XML format for test result integration:
```bash
./grpctestify.sh tests/ --parallel auto --log-format junit --log-output test-results.xml
```

### 3. **Archival and Reporting**
Generate timestamped JUnit reports:
```bash
# Include timestamp in filename
./grpctestify.sh tests/ --log-format junit --log-output "results-$(date +%Y%m%d-%H%M%S).xml"
```

## Troubleshooting

### Common Issues

#### 1. **JUnit XML Permission Denied**
```bash
# Ensure output directory is writable
mkdir -p reports && chmod 755 reports
./grpctestify.sh tests/ --log-format junit --log-output reports/test-results.xml
```

#### 2. **Color Issues in CI**
```bash
# Disable colors in CI environments
./grpctestify.sh tests/ --no-color --log-format junit --log-output results.xml
```

#### 3. **Output Redirection**
```bash
# Capture console output while generating JUnit XML
./grpctestify.sh tests/ --log-format junit --log-output results.xml 2>&1 | tee console.log
```

The reporting system provides comprehensive output for development, testing, and CI/CD integration scenarios.
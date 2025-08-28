# Command Line Interface

Complete reference for gRPC Testify command-line usage.

## Synopsis

```bash
grpctestify [TEST_PATH] [OPTIONS]
```

## Arguments

### TEST_PATH
Path to test file or directory to execute.

- **Single file**: `./grpctestify.sh test.gctf`
- **Directory**: `./grpctestify.sh tests/`
- **Pattern**: `./grpctestify.sh tests/*_auth.gctf`

## Options

### Execution Control

#### `--parallel N`
Run tests in parallel with N workers.
- **Default**: `1` (sequential)
- **Range**: `1-32`
- **Example**: `--parallel 4`

#### Fail-Fast Behavior
**Always enabled**: Execution stops on first test failure (like v0.0.13).
- **Behavior**: Tests stop at first failure
- **Note**: No flag needed - this is the default and only behavior

### Output Control

#### `--verbose, -v`
Enable verbose debug output.
- **Default**: Minimal output
- **Example**: `--verbose`

#### `--no-color, -c`
Disable colored output.
- **Default**: Colors enabled
- **Example**: `--no-color`

#### `--progress PROGRESS_MODE`
Set progress indicator type.
- **Options**: `none`, `dots`, `bar`
- **Default**: `none`
- **Example**: `--progress dots`

#### `--log-junit JUNIT_FILE`
Save test results in JUnit XML format to specified file.
- **Format**: XML file path
- **Example**: `--log-junit test-results.xml`
- **Note**: Creates JUnit-compatible XML for CI/CD integration

### Network & Timing

#### `--timeout TIMEOUT`
Set timeout for individual tests (seconds).
- **Default**: `30`
- **Range**: `1-300`
- **Example**: `--timeout 60`

#### `--retry RETRIES`
Number of retries for failed network calls.
- **Default**: `3`
- **Range**: `0-10`
- **Example**: `--retry 5`

#### `--retry-delay DELAY`
Initial delay between retries (seconds).
- **Default**: `1`
- **Range**: `0.1-10`
- **Example**: `--retry-delay 2`

#### `--no-retry`
Disable retry mechanisms completely.
- **Default**: Retries enabled
- **Example**: `--no-retry`

### Information

#### `--help, -h`
Show help message and exit.

#### `--version`
Show version information and exit.

#### `--config`
Show current configuration and exit.

### Utilities

#### `--completion SHELL_TYPE`
Install shell completion.
- **Options**: `bash`, `zsh`, `all`
- **Example**: `--completion bash`

#### `--list-plugins`
List available assertion plugins.

#### `--create-plugin PLUGIN_NAME`
Create new plugin template.
- **Example**: `--create-plugin my_validator`

#### `--update`
Check for updates and update the script.

#### `--init-config CONFIG_FILE`
Create default configuration file.
- **Example**: `--init-config grpctestify.conf`

## Environment Variables

### GRPCTESTIFY_ADDRESS
Default gRPC server address.
- **Default**: `localhost:4770`
- **Format**: `host:port`
- **Example**: `export GRPCTESTIFY_ADDRESS=api.example.com:443`

### GRPCTESTIFY_TIMEOUT  
Default timeout for gRPC calls (seconds).
- **Default**: `30`
- **Example**: `export GRPCTESTIFY_TIMEOUT=60`

### GRPCTESTIFY_VERBOSE
Enable verbose output by default.
- **Values**: `true`, `false`
- **Default**: `false`
- **Example**: `export GRPCTESTIFY_VERBOSE=true`

## Usage Examples

### Basic Usage
```bash
# Run single test file
./grpctestify.sh user_test.gctf

# Run all tests in directory
./grpctestify.sh tests/

# Run with verbose output
./grpctestify.sh --verbose tests/auth/
```

### Advanced Usage
```bash
# Parallel execution with progress
./grpctestify.sh --parallel 8 --progress bar tests/

# Custom timeout and retries
./grpctestify.sh --timeout 60 --retry 5 --retry-delay 2 tests/

# Minimal output for CI/CD (fail-fast is always enabled)
./grpctestify.sh --no-color tests/

# Generate JUnit XML for CI/CD integration
./grpctestify.sh tests/ --log-junit test-results.xml
```

### Development Usage
```bash
# List available plugins
./grpctestify.sh --list-plugins

# Create new plugin
./grpctestify.sh --create-plugin custom_validator

# Install shell completion
./grpctestify.sh --completion bash
```

## Exit Codes

- **0**: All tests passed
- **1**: One or more tests failed
- **2**: Invalid arguments or configuration
- **3**: Test file not found
- **4**: Network or connection error
- **5**: Server error or timeout

## Configuration Precedence

Settings are applied in this order (highest to lowest priority):

1. Command-line flags
2. Environment variables  
3. Configuration file
4. Built-in defaults

## See Also

- [Test File Format](./test-files)
- [Getting Started](../getting-started/quick-start)
- [Examples](../examples/)


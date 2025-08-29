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
- **Default**: `auto` (auto-detect CPU count)  
- **Range**: `1-32` or `auto`
- **Example**: `--parallel 4` or `--parallel auto`
- **Note**: Currently falls back to sequential mode due to recursion issue being resolved

#### `--dry-run`
Show commands that would be executed without running them.
- **Default**: Execute tests normally
- **Example**: `--dry-run`
- **Use case**: Debug command formation and validation

### Output Control

#### `--verbose, -v`
Enable verbose debug output.
- **Default**: Minimal output
- **Example**: `--verbose`

#### `--no-color, -c`
Disable colored output.
- **Default**: Colors enabled
- **Example**: `--no-color`

#### `--log-format FORMAT`
Generate test reports in specified format.
- **Options**: `junit`, `json`
- **Default**: None (no reports generated)
- **Example**: `--log-format junit`
- **Note**: Use with `--log-output` to specify output file

#### `--log-output OUTPUT_FILE`
Output file for test reports (use with `--log-format`).
- **Format**: File path
- **Example**: `--log-output test-results.xml`
- **Note**: File extension should match selected format

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
# Parallel execution with automatic job detection
./grpctestify.sh --parallel auto tests/

# Dry-run mode for debugging
./grpctestify.sh --dry-run tests/auth_test.gctf

# Custom timeout and retries
./grpctestify.sh --timeout 60 --retry 5 --retry-delay 2 tests/

# Minimal output for CI/CD  
./grpctestify.sh --no-color tests/

# Generate JUnit XML for CI/CD integration
./grpctestify.sh tests/ --log-format junit --log-output test-results.xml
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


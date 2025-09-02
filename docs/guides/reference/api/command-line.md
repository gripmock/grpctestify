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
Run test files in parallel with N workers.
- **Argument**: Number of workers (required)
- **Default**: `auto` (auto-detect CPU count)  
- **Range**: `1-32` or `auto`
- **Example**: `--parallel 4` or `--parallel auto`
- **Note**: Parallel execution works at the file level, not individual tests within files

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

#### `--sort SORT_TYPE`
Sort test files by type.
- **Argument**: Sort type (required)
- **Options**: `path`, `random`, `name`, `size`, `mtime`
- **Default**: `path`
- **Example**: `--sort random`

#### `--log-format FORMAT`
Generate test reports in specified format.
- **Argument**: Format type (required)
- **Options**: `junit`, `json`
- **Default**: None (no reports generated)
- **Example**: `--log-format junit`
- **Note**: Use with `--log-output` to specify output file
- **Requirement**: `--log-output` is required when using `--log-format`

#### `--log-output OUTPUT_FILE`
Output file for test reports (use with `--log-format`).
- **Argument**: Output file path (required)
- **Format**: File path
- **Example**: `--log-output test-results.xml`
- **Note**: File extension should match selected format

### Network & Timing

#### `--timeout TIMEOUT`
Set timeout for individual tests (seconds).
- **Argument**: Timeout in seconds (required)
- **Default**: `30`
- **Range**: `1-300`
- **Example**: `--timeout 60`

#### `--retry RETRIES`
Number of retries for failed network calls.
- **Argument**: Number of retries (required)
- **Default**: `3`
- **Range**: `0-10`
- **Example**: `--retry 5`

#### `--retry-delay DELAY`
Initial delay between retries (seconds).
- **Argument**: Delay in seconds (required)
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
- **Argument**: Shell type (required)
- **Options**: `bash`, `zsh`, `all`
- **Example**: `--completion bash`

#### `--list-plugins`
List available assertion plugins.

#### `--create-plugin PLUGIN_NAME`
Create new plugin template.
- **Argument**: Plugin name (required)
- **Example**: `--create-plugin my_validator`

#### `--update`
Check for updates and update the script.
- **Method**: Uses GitHub API to fetch latest release
- **Features**: Automatic checksum verification, backup, and rollback
- **Example**: `--update`

#### `--init-config CONFIG_FILE`
Create default configuration file.
- **Argument**: Configuration file name (required)
- **Example**: `--init-config grpctestify.conf`

## Environment Variables

### GRPCTESTIFY_ADDRESS
Default gRPC server address.
- **Default**: `localhost:4770`
- **Format**: `host:port`
- **Example**: `export GRPCTESTIFY_ADDRESS=api.example.com:443`

### GRPCTESTIFY_PLUGIN_DIR
Directory for external plugins.
- **Default**: `~/.grpctestify/plugins`
- **Example**: `export GRPCTESTIFY_PLUGIN_DIR=/opt/grpctestify/plugins`

**Note**: Use CLI flags for timeout (`--timeout`), verbose output (`--verbose`), parallel execution (`--parallel`), and sort mode (`--sort`).

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
- [Getting Started](../../getting-started/installation)
- [Examples](../examples/)


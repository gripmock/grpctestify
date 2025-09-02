# Custom Plugin Examples

Building and using custom plugins to extend gRPC Testify functionality.

## 📁 Example Location

```
examples/plugin-examples/
├── custom_plugins/   # Custom plugin implementations
├── tests/           # .gctf test files using plugins
└── README.md        # Setup instructions
```

## 🎯 Plugin Examples

### API Key Authentication Plugin
Custom plugin for API key validation:

```bash
# Create a new plugin
./grpctestify.sh --create-plugin api_key_auth

# This creates:
# ~/.grpctify/plugins/api_key_auth.sh
```

Plugin implementation:
```bash
#!/bin/bash

# API Key Authentication Plugin
PLUGIN_API_KEY_AUTH_NAME="API Key Authentication"
PLUGIN_API_KEY_AUTH_VERSION="1.0.0"
PLUGIN_API_KEY_AUTH_AUTHOR="Your Name <info@example.com>"
PLUGIN_API_KEY_AUTH_DESCRIPTION="Validates API keys in request headers"

# Plugin handler
api_key_auth_handler() {
    local command="$1"
    shift
    local args=("$@")
    
    case "$command" in
        "validate")
            local api_key="${args[0]}"
            local expected_key="${args[1]}"
            
            if [[ "$api_key" == "$expected_key" ]]; then
                echo "VALID"
                return 0
            else
                echo "INVALID"
                return 1
            fi
            ;;
        *)
            echo "Unknown command: $command"
            return 1
            ;;
    esac
}

# Export plugin functions
export -f api_key_auth_handler
```

### Custom Validation Plugin
Advanced validation plugin:

```bash
#!/bin/bash

# Custom Validation Plugin
PLUGIN_CUSTOM_VALIDATION_NAME="Custom Validation"
PLUGIN_CUSTOM_VALIDATION_VERSION="1.0.0"
PLUGIN_CUSTOM_VALIDATION_AUTHOR="Your Name <info@example.com>"
PLUGIN_CUSTOM_VALIDATION_DESCRIPTION="Custom business logic validation"

# Plugin handler
custom_validation_handler() {
    local command="$1"
    shift
    local args=("$@")
    
    case "$command" in
        "validate_email")
            local email="${args[0]}"
            
            if [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
                echo "VALID_EMAIL"
                return 0
            else
                echo "INVALID_EMAIL"
                return 1
            fi
            ;;
        "validate_phone")
            local phone="${args[0]}"
            
            if [[ "$phone" =~ ^\+?[1-9]\d{1,14}$ ]]; then
                echo "VALID_PHONE"
                return 0
            else
                echo "INVALID_PHONE"
                return 1
            fi
            ;;
        *)
            echo "Unknown command: $command"
            return 1
            ;;
    esac
}

export -f custom_validation_handler
```

## 🎯 Test Scenarios

### Using Custom Plugin in Tests
Test file using custom validation:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
user.UserService/CreateUser

--- REQUEST ---
{
    "username": "john_doe",
    "email": "john@example.com",
    "phone": "+1234567890"
}

--- RESPONSE ---
{
    "user": {
        "id": "user_123",
        "username": "john_doe",
        "email": "john@example.com",
        "phone": "+1234567890"
    },
    "success": true
}

--- ASSERTS ---
.user.id | type == "string"
.user.username == "john_doe"
@plugin("custom_validation", "validate_email", .user.email) == "VALID_EMAIL"
@plugin("custom_validation", "validate_phone", .user.phone) == "VALID_PHONE"
.success == true
```

### API Key Authentication Test
Test with API key validation:

```gctf
--- ADDRESS ---
localhost:4770

--- REQUEST_HEADERS ---
x-api-key: secret-api-key-12345
authorization: Bearer token-67890

--- ENDPOINT ---
secure.SecureService/GetData

--- REQUEST ---
{
    "user_id": "user_123"
}

--- RESPONSE ---
{
    "data": {
        "user_id": "user_123",
        "sensitive_info": "protected_data"
    },
    "success": true
}

--- ASSERTS ---
@plugin("api_key_auth", "validate", @header("x-api-key"), "secret-api-key-12345") == "VALID"
.data.user_id == "user_123"
.success == true
```

### Complex Business Logic
Advanced business rule validation:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
business.BusinessService/ProcessOrder

--- REQUEST ---
{
    "order_id": "order_001",
    "customer_age": 25,
    "order_amount": 1500.00,
    "payment_method": "credit_card"
}

--- RESPONSE ---
{
    "order": {
        "id": "order_001",
        "status": "approved",
        "risk_score": 0.1,
        "requires_review": false
    },
    "success": true
}

--- ASSERTS ---
@plugin("business_rules", "validate_age", .customer_age) == "VALID_AGE"
@plugin("business_rules", "validate_amount", .order_amount) == "VALID_AMOUNT"
@plugin("business_rules", "calculate_risk", .customer_age, .order_amount) < 0.5
.order.status == "approved"
.success == true
```

## 🔧 Plugin Development

### Plugin Structure
Every plugin must have:

```bash
# Required metadata
PLUGIN_<NAME>_NAME="Plugin Name"
PLUGIN_<NAME>_VERSION="1.0.0"
PLUGIN_<NAME>_AUTHOR="Your Name <info@example.com>"
PLUGIN_<NAME>_DESCRIPTION="Plugin description"

# Main handler function
<plugin_name>_handler() {
    local command="$1"
    shift
    local args=("$@")
    
    case "$command" in
        "command1")
            # Implementation
            ;;
        "command2")
            # Implementation
            ;;
        *)
            echo "Unknown command: $command"
            return 1
            ;;
    esac
}

# Export the handler
export -f <plugin_name>_handler
```

### Plugin Installation
```bash
# Create plugin directory
mkdir -p ~/.grpctestify/plugins

# Copy plugin file
cp my_plugin.sh ~/.grpctestify/plugins/

# Make executable
chmod +x ~/.grpctestify/plugins/my_plugin.sh

# List installed plugins
./grpctestify.sh --list-plugins
```

### Plugin Usage in Tests
```gctf
--- ASSERTS ---
# Basic plugin call
@plugin("plugin_name", "command", "arg1", "arg2") == "expected_result"

# Plugin with response data
@plugin("validation", "check", .field.value) == "VALID"

# Plugin with multiple arguments
@plugin("business", "calculate", .amount, .tax_rate) > 100
```

## 🔧 Running the Examples

```bash
# Navigate to the example
cd examples/plugin-examples

# Install custom plugins
cp custom_plugins/* ~/.grpctestify/plugins/

# Run tests with plugins
../../grpctestify.sh tests/*.gctf

# List available plugins
../../grpctestify.sh --list-plugins
```

## 📊 Plugin Capabilities

Custom plugins can:

- ✅ **Data Validation** - Custom business rule validation
- ✅ **Authentication** - Custom auth mechanisms
- ✅ **Data Transformation** - Format and transform data
- ✅ **Business Logic** - Complex business rule enforcement
- ✅ **External Integrations** - Connect to external services
- ✅ **Performance Monitoring** - Custom metrics and monitoring
- ✅ **Security Checks** - Custom security validations

## 🎓 Learning Points

1. **Plugin Architecture** - How to build custom plugins
2. **Plugin Integration** - Using plugins in test files
3. **Business Logic** - Implementing custom validation rules
4. **Plugin Management** - Installing and managing plugins
5. **Advanced Testing** - Complex validation scenarios

## 🔗 Related Examples

- **[Plugin Development](../plugins/development.md)** - Plugin development guide
- **[User Management](../basic/user-management.md)** - Authentication patterns
- **[Fintech Payment](../security/fintech-payment.md)** - Security validation

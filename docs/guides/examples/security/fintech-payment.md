# Fintech Payment Examples

Financial service validation with compliance and security patterns.

## 📁 Example Location

```
examples/security-examples/fintech-payment/
├── server/           # Go gRPC server implementation
├── tests/           # .gctf test files
└── README.md        # Setup instructions
```

## 🎯 Test Scenarios

### Account Creation
Secure account creation with validation:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
fintech.FintechService/CreateAccount

--- REQUEST ---
{
    "customer_id": "cust_123",
    "account_type": "checking",
    "initial_balance": 1000.00,
    "currency": "USD",
    "kyc_verified": true
}

--- RESPONSE ---
{
    "account": {
        "id": "acc_001",
        "customer_id": "cust_123",
        "account_type": "checking",
        "balance": 1000.00,
        "currency": "USD",
        "status": "active",
        "created_at": "2024-01-01T12:00:00Z"
    },
    "success": true
}

--- ASSERTS ---
.account.id | type == "string"
.account.balance == 1000.00
.account.status == "active"
.success == true
```

### Card Validation
Credit card validation and verification:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
fintech.FintechService/ValidateCard

--- REQUEST ---
{
    "card_number": "4111111111111111",
    "expiry_month": 12,
    "expiry_year": 2025,
    "cvv": "123"
}

--- RESPONSE ---
{
    "card": {
        "card_number": "4111111111111111",
        "card_type": "visa",
        "is_valid": true,
        "risk_score": 0.1,
        "fraud_detected": false
    },
    "success": true
}

--- ASSERTS ---
.card.is_valid == true
.card.risk_score < 0.5
.card.fraud_detected == false
.success == true
```

### Payment Processing
Secure payment processing with fraud detection:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
fintech.FintechService/ProcessPayment

--- REQUEST ---
{
    "account_id": "acc_001",
    "amount": 150.00,
    "currency": "USD",
    "merchant_id": "merch_001",
    "description": "Online purchase"
}

--- RESPONSE ---
{
    "payment": {
        "id": "pay_001",
        "account_id": "acc_001",
        "amount": 150.00,
        "currency": "USD",
        "status": "completed",
        "transaction_id": "txn_1234567890",
        "fraud_score": 0.05,
        "processed_at": "2024-01-01T12:05:00Z"
    },
    "success": true
}

--- ASSERTS ---
.payment.status == "completed"
.payment.amount == 150.00
.payment.fraud_score < 0.1
.success == true
```

### High-Value Transaction Security
Enhanced security for large transactions:

```gctf
--- ADDRESS ---
localhost:4770

--- TLS ---
ca_cert: ./../server/tls/ca-cert.pem
cert: ./../server/tls/client-cert.pem
key: ./../server/tls/client-key.pem
server_name: localhost

--- ENDPOINT ---
fintech.FintechService/ProcessHighValuePayment

--- REQUEST ---
{
    "account_id": "acc_001",
    "amount": 10000.00,
    "currency": "USD",
    "merchant_id": "merch_001",
    "additional_verification": {
        "otp": "123456",
        "biometric_verified": true
    }
}

--- RESPONSE ---
{
    "payment": {
        "id": "pay_002",
        "account_id": "acc_001",
        "amount": 10000.00,
        "currency": "USD",
        "status": "pending_review",
        "security_level": "high",
        "requires_manual_review": true
    },
    "success": true
}

--- ASSERTS ---
.payment.status == "pending_review"
.payment.security_level == "high"
.payment.requires_manual_review == true
.success == true
```

### Cross-Border Compliance
International payment compliance:

```gctf
--- ADDRESS ---
localhost:4770

--- TLS ---
ca_cert: ./../server/tls/ca-cert.pem
cert: ./../server/tls/client-cert.pem
key: ./../server/tls/client-key.pem
server_name: localhost

--- ENDPOINT ---
fintech.FintechService/ProcessCrossBorderPayment

--- REQUEST ---
{
    "from_account": "acc_001",
    "to_account": "acc_002",
    "amount": 500.00,
    "from_currency": "USD",
    "to_currency": "EUR",
    "exchange_rate": 0.85,
    "purpose": "business_transfer"
}

--- RESPONSE ---
{
    "payment": {
        "id": "pay_003",
        "from_account": "acc_001",
        "to_account": "acc_002",
        "amount_usd": 500.00,
        "amount_eur": 425.00,
        "exchange_rate": 0.85,
        "status": "completed",
        "compliance_verified": true,
        "sanctions_checked": true
    },
    "success": true
}

--- ASSERTS ---
.payment.compliance_verified == true
.payment.sanctions_checked == true
.payment.amount_eur == 425.00
.success == true
```

### Fraud Detection Streaming
Real-time fraud detection:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
fintech.FintechService/FraudDetectionStreaming

--- REQUEST ---
{
    "account_id": "acc_001",
    "transaction_pattern": "normal"
}

--- ASSERTS ---
.risk_level == "low"
.fraud_detected == false
.confidence_score > 0.8

--- ASSERTS ---
.risk_level == "medium"
.fraud_detected == false
.confidence_score > 0.6

--- ASSERTS ---
.risk_level == "high"
.fraud_detected == true
.confidence_score > 0.9
```

### Transaction Monitoring
Server streaming for transaction monitoring:

```gctf
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
fintech.FintechService/StreamTransactions

--- REQUEST ---
{
    "account_id": "acc_001",
    "monitoring_duration": 60
}

--- ASSERTS ---
.transaction_id | type == "string"
.amount | type == "number"
.timestamp | type == "string"
.risk_score | type == "number"

--- ASSERTS ---
.transaction_id | type == "string"
.amount | type == "number"
.fraud_detected | type == "boolean"
```

## 🔧 Running the Examples

```bash
# Navigate to the example
cd examples/security-examples/fintech-payment

# Start the server
make start

# Run all tests
../../grpctestify.sh tests/*.gctf

# Run specific test
../../grpctestify.sh tests/create_account_unary.gctf

# Stop the server
make stop
```

## 📊 Test Coverage

This example demonstrates:

- ✅ **Account Management** - Secure account creation and validation
- ✅ **Card Validation** - Credit card verification and fraud detection
- ✅ **Payment Processing** - Secure transaction handling
- ✅ **High-Value Security** - Enhanced security for large amounts
- ✅ **Cross-Border Compliance** - International payment regulations
- ✅ **Fraud Detection** - Real-time fraud monitoring
- ✅ **Transaction Monitoring** - Continuous transaction surveillance
- ✅ **TLS Security** - Encrypted communication
- ✅ **Compliance** - Regulatory requirements and sanctions checking

## 🎓 Learning Points

1. **Financial Security** - Secure payment processing patterns
2. **Fraud Detection** - Real-time risk assessment
3. **Compliance** - Regulatory and cross-border requirements
4. **TLS Security** - Encrypted financial communications
5. **Transaction Monitoring** - Continuous surveillance patterns

## 🔗 Related Examples

- **[User Management](../basic/user-management.md)** - Customer account management
- **[ShopFlow E-commerce](../advanced/shopflow-ecommerce.md)** - Payment integration
- **[File Storage](file-storage.md)** - Secure document storage

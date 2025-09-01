# File Storage Security Examples

Secure file operations and storage with encryption and access control.

## 📁 Example Location

```
examples/security-examples/file-storage/
├── server/           # Go gRPC server implementation
├── tests/           # .gctf test files
└── README.md        # Setup instructions
```

## 🎯 Test Scenarios

### Secure File Upload
Encrypted file upload with access control:

```gctf
--- ADDRESS ---
localhost:4770

--- TLS ---
ca_cert: ./../server/tls/ca-cert.pem
cert: ./../server/tls/client-cert.pem
key: ./../server/tls/client-key.pem
server_name: localhost

--- ENDPOINT ---
storage.SecureFileService/UploadFile

--- REQUEST ---
{
    "filename": "sensitive_document.pdf",
    "file_data": "SGVsbG8gV29ybGQh",
    "encryption_type": "AES256",
    "access_level": "confidential",
    "user_id": "user_123"
}

--- RESPONSE ---
{
    "file": {
        "id": "file_001",
        "filename": "sensitive_document.pdf",
        "encrypted": true,
        "encryption_type": "AES256",
        "access_level": "confidential",
        "upload_status": "completed",
        "checksum": "sha256:abc123...",
        "uploaded_at": "2024-01-01T12:00:00Z"
    },
    "success": true
}

--- ASSERTS ---
.file.encrypted == true
.file.encryption_type == "AES256"
.file.access_level == "confidential"
.file.checksum | test("sha256:")
.success == true
```

### File Access Control
Secure file access with permissions:

```gctf
--- ADDRESS ---
localhost:4770

--- TLS ---
ca_cert: ./../server/tls/ca-cert.pem
cert: ./../server/tls/client-cert.pem
key: ./../server/tls/client-key.pem
server_name: localhost

--- ENDPOINT ---
storage.SecureFileService/GetFile

--- REQUEST ---
{
    "file_id": "file_001",
    "user_id": "user_123",
    "access_token": "valid-token-12345"
}

--- RESPONSE ---
{
    "file": {
        "id": "file_001",
        "filename": "sensitive_document.pdf",
        "content": "decrypted_content_here",
        "access_granted": true,
        "access_level": "confidential",
        "accessed_at": "2024-01-01T12:05:00Z"
    },
    "success": true
}

--- ASSERTS ---
.file.access_granted == true
.file.access_level == "confidential"
.file.content | type == "string"
.success == true
```

### Access Denied Scenario
Testing access control failures:

```gctf
--- ADDRESS ---
localhost:4770

--- TLS ---
ca_cert: ./../server/tls/ca-cert.pem
cert: ./../server/tls/client-cert.pem
key: ./../server/tls/client-key.pem
server_name: localhost

--- ENDPOINT ---
storage.SecureFileService/GetFile

--- REQUEST ---
{
    "file_id": "file_001",
    "user_id": "user_456",
    "access_token": "invalid-token"
}

--- ERROR ---
{
    "code": 7,
    "message": "Access denied: insufficient permissions",
    "details": [
        {
            "type": "permission_error",
            "reason": "user_456 does not have access to confidential files"
        }
    ]
}

--- ASSERTS ---
.code == 7
.message | contains("Access denied")
.details[0].type == "permission_error"
```

### File Encryption Verification
Verify file encryption status:

```gctf
--- ADDRESS ---
localhost:4770

--- TLS ---
ca_cert: ./../server/tls/ca-cert.pem
cert: ./../server/tls/client-cert.pem
key: ./../server/tls/client-key.pem
server_name: localhost

--- ENDPOINT ---
storage.SecureFileService/VerifyEncryption

--- REQUEST ---
{
    "file_id": "file_001",
    "user_id": "user_123"
}

--- RESPONSE ---
{
    "verification": {
        "file_id": "file_001",
        "encrypted": true,
        "encryption_type": "AES256",
        "key_rotation_date": "2024-01-01T00:00:00Z",
        "integrity_check": "passed",
        "verified_at": "2024-01-01T12:10:00Z"
    },
    "success": true
}

--- ASSERTS ---
.verification.encrypted == true
.verification.integrity_check == "passed"
.verification.encryption_type == "AES256"
.success == true
```

### Audit Trail
File access audit logging:

```gctf
--- ADDRESS ---
localhost:4770

--- TLS ---
ca_cert: ./../server/tls/ca-cert.pem
cert: ./../server/tls/client-cert.pem
key: ./../server/tls/client-key.pem
server_name: localhost

--- ENDPOINT ---
storage.SecureFileService/GetAuditTrail

--- REQUEST ---
{
    "file_id": "file_001",
    "start_date": "2024-01-01T00:00:00Z",
    "end_date": "2024-01-01T23:59:59Z"
}

--- RESPONSE ---
{
    "audit_trail": [
        {
            "event_id": "event_001",
            "file_id": "file_001",
            "user_id": "user_123",
            "action": "upload",
            "timestamp": "2024-01-01T12:00:00Z",
            "ip_address": "192.168.1.100"
        },
        {
            "event_id": "event_002",
            "file_id": "file_001",
            "user_id": "user_123",
            "action": "access",
            "timestamp": "2024-01-01T12:05:00Z",
            "ip_address": "192.168.1.100"
        }
    ],
    "total_events": 2,
    "success": true
}

--- ASSERTS ---
.audit_trail | length == 2
.audit_trail[0].action == "upload"
.audit_trail[1].action == "access"
.total_events == 2
.success == true
```

### Key Rotation
Encryption key management:

```gctf
--- ADDRESS ---
localhost:4770

--- TLS ---
ca_cert: ./../server/tls/ca-cert.pem
cert: ./../server/tls/client-cert.pem
key: ./../server/tls/client-key.pem
server_name: localhost

--- ENDPOINT ---
storage.SecureFileService/RotateEncryptionKeys

--- REQUEST ---
{
    "file_id": "file_001",
    "new_encryption_type": "AES256",
    "admin_user_id": "admin_001"
}

--- RESPONSE ---
{
    "key_rotation": {
        "file_id": "file_001",
        "old_encryption_type": "AES128",
        "new_encryption_type": "AES256",
        "rotation_status": "completed",
        "rotation_date": "2024-01-01T12:15:00Z",
        "admin_user_id": "admin_001"
    },
    "success": true
}

--- ASSERTS ---
.key_rotation.rotation_status == "completed"
.key_rotation.new_encryption_type == "AES256"
.key_rotation.admin_user_id == "admin_001"
.success == true
```

## 🔧 Running the Examples

```bash
# Navigate to the example
cd examples/security-examples/file-storage

# Start the server
make start

# Run all tests
../../grpctestify.sh tests/*.gctf

# Run specific test
../../grpctestify.sh tests/secure_file_upload.gctf

# Stop the server
make stop
```

## 📊 Test Coverage

This example demonstrates:

- ✅ **Secure File Upload** - Encrypted file storage
- ✅ **Access Control** - Permission-based file access
- ✅ **TLS Security** - Encrypted communication
- ✅ **Error Handling** - Access denied scenarios
- ✅ **Encryption Verification** - File encryption status
- ✅ **Audit Trail** - Access logging and monitoring
- ✅ **Key Rotation** - Encryption key management
- ✅ **Integrity Checks** - File integrity verification
- ✅ **Security Compliance** - Security best practices

## 🎓 Learning Points

1. **File Security** - Secure file storage and access patterns
2. **Encryption** - File encryption and key management
3. **Access Control** - Permission-based access systems
4. **Audit Logging** - Security event tracking
5. **TLS Integration** - Secure communication protocols

## 🔗 Related Examples

- **[Media Streaming](../advanced/media-streaming.md)** - File upload patterns
- **[Fintech Payment](fintech-payment.md)** - Security compliance
- **[User Management](../basic/user-management.md)** - Authentication patterns

#!/bin/bash

# Generate TLS certificates for gRPC server testing
set -e

echo "🔐 Generating TLS certificates for gRPC testing..."

# Create certificate authority (CA)
echo "1. Creating Certificate Authority (CA)..."
openssl genrsa -out ca-key.pem 4096
openssl req -new -x509 -key ca-key.pem -sha256 -subj "/C=US/ST=CA/O=gRPC Testify/CN=Test CA" -days 365 -out ca-cert.pem

# Create server private key
echo "2. Creating server private key..."
openssl genrsa -out server-key.pem 4096

# Create certificate signing request for server
echo "3. Creating server certificate signing request..."
openssl req -new -key server-key.pem -out server.csr -subj "/C=US/ST=CA/O=gRPC Testify/CN=localhost"

# Create server certificate signed by CA
echo "4. Creating server certificate..."
cat > server-ext.conf << EOF
[v3_ext]
subjectAltName = @alt_names
[alt_names]
DNS.1 = localhost
DNS.2 = *.localhost
IP.1 = 127.0.0.1
IP.2 = ::1
EOF

openssl x509 -req -in server.csr -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial -out server-cert.pem -days 365 -extensions v3_ext -extfile server-ext.conf

# Create client private key (for mTLS testing)
echo "5. Creating client private key..."
openssl genrsa -out client-key.pem 4096

# Create certificate signing request for client
echo "6. Creating client certificate signing request..."
openssl req -new -key client-key.pem -out client.csr -subj "/C=US/ST=CA/O=gRPC Testify Client/CN=grpctestify-client"

# Create client certificate signed by CA
echo "7. Creating client certificate..."
openssl x509 -req -in client.csr -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial -out client-cert.pem -days 365

# Clean up temporary files
echo "8. Cleaning up temporary files..."
rm server.csr client.csr server-ext.conf

# Set appropriate permissions
chmod 600 *-key.pem
chmod 644 *-cert.pem ca-cert.pem

echo "✅ TLS certificates generated successfully!"
echo ""
echo "Generated files:"
echo "  - ca-cert.pem       (Certificate Authority)"
echo "  - server-cert.pem   (Server certificate)"
echo "  - server-key.pem    (Server private key)"
echo "  - client-cert.pem   (Client certificate for mTLS)"
echo "  - client-key.pem    (Client private key for mTLS)"
echo ""
echo "🔒 Ready for TLS and mTLS testing!"

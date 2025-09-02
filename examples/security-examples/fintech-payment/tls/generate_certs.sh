#!/bin/bash

# Generate TLS certificates for FinTech Payment Service mTLS testing
# This script creates a complete PKI setup for demonstration purposes

set -e

echo "🔐 Generating TLS certificates for FinTech Payment Service..."

# Create directory if it doesn't exist
mkdir -p tls

# Generate CA private key
openssl genrsa -out ca-key.pem 4096

# Generate CA certificate
openssl req -new -x509 -key ca-key.pem -sha256 -subj "/C=US/ST=NY/O=FinTech/CN=FinTech-CA" -days 3650 -out ca-cert.pem

# Generate server private key
openssl genrsa -out server-key.pem 4096

# Generate server certificate signing request
openssl req -subj "/C=US/ST=NY/O=FinTech/CN=localhost" -sha256 -new -key server-key.pem -out server.csr

# Generate server certificate
echo "subjectAltName=DNS:localhost,IP:127.0.0.1" > server.conf
openssl x509 -req -in server.csr -CA ca-cert.pem -CAkey ca-key.pem -out server-cert.pem -days 365 -extensions v3_req -extfile server.conf

# Generate client private key
openssl genrsa -out client-key.pem 4096

# Generate client certificate signing request
openssl req -subj "/C=US/ST=NY/O=FinTech/CN=payment-client" -new -key client-key.pem -out client.csr

# Generate client certificate
openssl x509 -req -in client.csr -CA ca-cert.pem -CAkey ca-key.pem -out client-cert.pem -days 365

# Clean up CSR files
rm server.csr client.csr server.conf

# Set appropriate permissions
chmod 600 *.pem

echo "✅ TLS certificates generated successfully!"
echo "📁 Files created:"
echo "   - ca-cert.pem (Certificate Authority)"
echo "   - ca-key.pem (CA Private Key)"
echo "   - server-cert.pem (Server Certificate)"
echo "   - server-key.pem (Server Private Key)"
echo "   - client-cert.pem (Client Certificate)"
echo "   - client-key.pem (Client Private Key)"
echo ""
echo "🔒 These certificates enable mTLS authentication for secure financial transactions."
echo "💡 Use these certificates in your GCTF tests for secure payment processing."

.PHONY: build run clean proto tls

# Build the FinTech payment server
build: proto
	@echo "Building FinTech Payment Server..."
	go build -o fintech-payment-server .
	@echo "✅ Server built successfully!"

# Run the server
run: build
	@echo "Starting FinTech Payment Server..."
	./fintech-payment-server

# Generate protobuf code
proto:
	@echo "Generating Go code from protobuf..."
	protoc --go_out=. --go_opt=paths=source_relative \
		--go-grpc_out=. --go-grpc_opt=paths=source_relative \
		payment.proto
	@echo "Moving generated files to paymentpb package..."
	mkdir -p paymentpb
	mv payment.pb.go payment_grpc.pb.go paymentpb/
	@echo "✅ Protobuf code generated successfully!"

# Generate TLS certificates
tls:
	@echo "Generating TLS certificates..."
	mkdir -p tls
	openssl req -x509 -newkey rsa:4096 -keyout tls/server-key.pem -out tls/server-cert.pem -days 365 -nodes -subj "/C=US/ST=CA/L=San Francisco/O=FinTech/CN=localhost"
	openssl req -x509 -newkey rsa:4096 -keyout tls/client-key.pem -out tls/client-cert.pem -days 365 -nodes -subj "/C=US/ST=CA/L=San Francisco/O=FinTech/CN=client"
	openssl req -x509 -newkey rsa:4096 -keyout tls/ca-cert.pem -out tls/ca-cert.pem -days 365 -nodes -subj "/C=US/ST=CA/L=San Francisco/O=FinTech/CN=CA"
	@echo "✅ TLS certificates generated successfully!"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f fintech-payment-server
	rm -rf paymentpb
	rm -rf tls/*.pem
	@echo "✅ Cleaned successfully!"

# Install dependencies
deps:
	@echo "Installing dependencies..."
	go mod tidy
	@echo "✅ Dependencies installed successfully!"

# Run without TLS (for testing)
run-no-tls: build
	@echo "Starting FinTech Payment Server without TLS..."
	@echo "⚠️  WARNING: Running without TLS is not secure for production!"
	USE_TLS=false ./fintech-payment-server

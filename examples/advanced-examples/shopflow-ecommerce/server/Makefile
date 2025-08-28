.PHONY: proto build run clean test tls help

# Default target
help:
	@echo "ShopFlow E-commerce Server Makefile"
	@echo "Available targets:"
	@echo "  proto    - Generate Go code from protobuf files"
	@echo "  build    - Build the server binary"
	@echo "  run      - Run the server"
	@echo "  clean    - Clean build artifacts"
	@echo "  test     - Run tests"
	@echo "  tls      - Generate TLS certificates"
	@echo "  help     - Show this help message"

# Generate Go code from protobuf
proto:
	@echo "Generating Go code from protobuf..."
	protoc --go_out=. --go_opt=paths=source_relative \
		--go-grpc_out=. --go-grpc_opt=paths=source_relative \
		shopflow.proto
	@echo "Moving generated files to shopflowpb package..."
	mkdir -p shopflowpb
	mv shopflow.pb.go shopflow_grpc.pb.go shopflowpb/
	@echo "✅ Protobuf code generated successfully!"

# Build the server
build: proto
	@echo "Building ShopFlow E-commerce Server..."
	go build -o shopflow-server .
	@echo "✅ Server built successfully!"

# Run the server
run: build
	@echo "🚀 Starting ShopFlow E-commerce Server..."
	./shopflow-server

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f shopflow-server
	rm -rf shopflowpb/
	@echo "✅ Cleaned successfully!"

# Run tests
test:
	@echo "Running tests..."
	go test -v ./...

# Generate TLS certificates
tls:
	@echo "Generating TLS certificates..."
	cd tls && ./generate_certs.sh

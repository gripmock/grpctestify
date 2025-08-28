# User Management Service Makefile

.PHONY: build run clean proto test tls

# Build the user management service
build: proto
	@echo "Building User Management Service..."
	go build -o server .

# Generate protobuf files
proto:
	@echo "Generating protobuf files..."
	protoc --go_out=. --go_opt=paths=source_relative \
		--go-grpc_out=. --go-grpc_opt=paths=source_relative \
		user.proto
	@echo "Moving generated files to userpb package..."
	mkdir -p userpb
	mv user.pb.go user_grpc.pb.go userpb/
	@echo "Protobuf code generated successfully!"

# Run the service
run: build
	@echo "Starting User Management Service..."
	./server

# Run in background
up: build
	@echo "Starting User Management Service in background..."
	./server &

# Stop the service
down:
	@echo "Stopping User Management Service..."
	@pkill -f server || true

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f server
	rm -rf userpb/

# Install dependencies
deps:
	@echo "Installing dependencies..."
	go mod tidy
	go mod download

# Run tests
test:
	@echo "Running tests..."
	go test ./...

# Generate TLS certificates
tls:
	@echo "Generating TLS certificates..."
	@cd tls && ./generate_certs.sh

# Show help
help:
	@echo "Available targets:"
	@echo "  build  - Build the user management service"
	@echo "  proto  - Generate protobuf files"
	@echo "  run    - Run the service"
	@echo "  up     - Run the service in background"
	@echo "  down   - Stop the service"
	@echo "  clean  - Clean build artifacts"
	@echo "  deps   - Install dependencies"
	@echo "  test   - Run tests"
	@echo "  tls    - Generate TLS certificates"
	@echo "  help   - Show this help"


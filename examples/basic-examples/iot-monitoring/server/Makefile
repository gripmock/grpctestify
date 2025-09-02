.PHONY: build run clean proto

# Build the IoT monitoring server
build: proto
	@echo "Building IoT Monitoring Server..."
	go build -o server .
	@echo "✅ Server built successfully!"

# Run the server
run: build
	@echo "Starting IoT Monitoring Server..."
	./server

# Generate protobuf code
proto:
	@echo "Generating Go code from protobuf..."
	protoc --go_out=. --go_opt=paths=source_relative \
		--go-grpc_out=. --go-grpc_opt=paths=source_relative \
		monitoring.proto
	@echo "Moving generated files to monitoringpb package..."
	mkdir -p monitoringpb
	mv monitoring.pb.go monitoring_grpc.pb.go monitoringpb/
	@echo "✅ Protobuf code generated successfully!"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f server
	rm -rf monitoringpb
	@echo "✅ Cleaned successfully!"

# Install dependencies
deps:
	@echo "Installing dependencies..."
	go mod tidy
	@echo "✅ Dependencies installed successfully!"

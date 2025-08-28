.PHONY: build run clean proto

# Build the media streaming server
build: proto
	@echo "Building Media Streaming Server..."
	go build -o media-streaming-server .
	@echo "✅ Server built successfully!"

# Run the server
run: build
	@echo "Starting Media Streaming Server..."
	./media-streaming-server

# Generate protobuf code
proto:
	@echo "Generating Go code from protobuf..."
	protoc --go_out=. --go_opt=paths=source_relative \
		--go-grpc_out=. --go-grpc_opt=paths=source_relative \
		media.proto
	@echo "Moving generated files to mediapb package..."
	mkdir -p mediapb
	mv media.pb.go media_grpc.pb.go mediapb/
	@echo "✅ Protobuf code generated successfully!"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f media-streaming-server
	rm -rf mediapb
	@echo "✅ Cleaned successfully!"

# Install dependencies
deps:
	@echo "Installing dependencies..."
	go mod tidy
	@echo "✅ Dependencies installed successfully!"

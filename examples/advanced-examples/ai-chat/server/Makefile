.PHONY: build run clean proto

# Build the AI chat server
build: proto
	@echo "Building AI Chat Server..."
	go build -o ai-chat-server .
	@echo "✅ Server built successfully!"

# Run the server
run: build
	@echo "Starting AI Chat Server..."
	./ai-chat-server

# Generate protobuf code
proto:
	@echo "Generating Go code from protobuf..."
	protoc --go_out=. --go_opt=paths=source_relative \
		--go-grpc_out=. --go-grpc_opt=paths=source_relative \
		chat.proto
	@echo "Moving generated files to aichatpb package..."
	mkdir -p aichatpb
	mv chat.pb.go chat_grpc.pb.go aichatpb/
	@echo "✅ Protobuf code generated successfully!"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f ai-chat-server
	rm -rf aichatpb
	@echo "✅ Cleaned successfully!"

# Install dependencies
deps:
	@echo "Installing dependencies..."
	go mod tidy
	@echo "✅ Dependencies installed successfully!"

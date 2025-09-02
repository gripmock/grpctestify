.PHONY: proto build run clean test

# Generate Go code from protobuf
proto:
	protoc --go_out=. --go_opt=paths=source_relative \
		--go-grpc_out=. --go-grpc_opt=paths=source_relative \
		file_storage.proto
	mkdir -p filestoragepb
	mv file_storage.pb.go file_storage_grpc.pb.go filestoragepb/

# Build the server
build: proto
	go build -o server .

# Run the server
run: build
	./server

# Clean generated files
clean:
	rm -f file_storage.pb.go file_storage_grpc.pb.go file-storage-server

# Test the server (basic health check)
test: build
	@echo "Testing file storage server..."
	@timeout 5s ./server &
	@sleep 2
	@grpcurl -plaintext localhost:50058 filestorage.FileStorageService/HealthCheck
	@pkill -f file-storage-server || true

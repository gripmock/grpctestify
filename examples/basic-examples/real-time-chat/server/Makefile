# Real-time Chat gRPC Server Makefile

# Go parameters
GOCMD=go
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean
GOTEST=$(GOCMD) test
GOGET=$(GOCMD) get
GOMOD=$(GOCMD) mod

# Build targets
BINARY_NAME=server
PROTO_FILE=chat.proto
GO_OUT=./chatpb

.PHONY: all build clean test deps proto run help

all: deps proto build

## Build the server binary
build: proto
	@echo "🔨 Building chat server..."
	$(GOBUILD) -o $(BINARY_NAME) -v .
	@echo "✅ Build complete: $(BINARY_NAME)"

## Generate protobuf code
proto:
	@echo "📝 Generating protobuf code..."
	@mkdir -p $(GO_OUT)
	protoc --go_out=$(GO_OUT) --go_opt=paths=source_relative \
		--go-grpc_out=$(GO_OUT) --go-grpc_opt=paths=source_relative \
		$(PROTO_FILE)
	@echo "✅ Protobuf generation complete"

## Install dependencies
deps:
	@echo "📦 Installing dependencies..."
	$(GOMOD) tidy
	$(GOMOD) download
	@echo "✅ Dependencies installed"

## Run the server
run: build
	@echo "🚀 Starting chat server on :50053..."
	./$(BINARY_NAME)

## Run tests
test:
	@echo "🧪 Running tests..."
	$(GOTEST) -v ./...

## Clean build artifacts
clean:
	@echo "🧹 Cleaning..."
	$(GOCLEAN)
	rm -f $(BINARY_NAME)
	rm -rf $(GO_OUT)
	@echo "✅ Clean complete"

## Development server with auto-restart
dev:
	@echo "🔄 Starting development server..."
	@if command -v air >/dev/null 2>&1; then \
		air; \
	else \
		echo "Installing air for hot reload..."; \
		go install github.com/cosmtrek/air@latest; \
		air; \
	fi

## Show help
help:
	@echo "Real-time Chat gRPC Server"
	@echo ""
	@echo "Available targets:"
	@awk '/^[a-zA-Z\-\_0-9]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")-1); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "  %-15s %s\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)

## Check if protoc is installed
check-protoc:
	@if ! command -v protoc >/dev/null 2>&1; then \
		echo "❌ protoc is not installed. Please install Protocol Buffers compiler."; \
		echo "   macOS: brew install protobuf"; \
		echo "   Ubuntu: Install latest version from https://github.com/protocolbuffers/protobuf/releases"; \
		echo "   Quick install: curl -sSL https://get.protoc.sh | bash"; \
		exit 1; \
	fi
	@if ! command -v protoc-gen-go >/dev/null 2>&1; then \
		echo "📦 Installing protoc-gen-go..."; \
		go install google.golang.org/protobuf/cmd/protoc-gen-go@latest; \
	fi
	@if ! command -v protoc-gen-go-grpc >/dev/null 2>&1; then \
		echo "📦 Installing protoc-gen-go-grpc..."; \
		go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest; \
	fi

.PHONY: check-protoc

# Ensure protoc is available before proto generation
proto: check-protoc


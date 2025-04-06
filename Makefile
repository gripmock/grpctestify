# Strict makefile configuration
SHELL := /bin/bash
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-print-directory

# Variables
TEST_DIR      := tests
SERVER_PORT   := 4770
SERVER_IMAGE  := bavix/gripmock:3
CONTAINER_NAME := grpctestify-server

# Start test server
.PHONY: up
up:
	docker run -d --name $(CONTAINER_NAME) \
		-v ./api:/proto \
		-v ./stubs:/stubs \
		-p $(SERVER_PORT):4770 \
		$(SERVER_IMAGE) --stub=/stubs /proto/helloworld.proto 
	until grpcurl -plaintext localhost:$(SERVER_PORT) list; do sleep 1; done

# Run tests
.PHONY: test
test:
	@echo "Running tests..."
	./grpctestify.sh $(TEST_DIR)

# Stop test server
.PHONY: down
down:
	docker rm -f $(CONTAINER_NAME) 2>/dev/null || true

# Cleanup
.PHONY: clean
clean: down
	rm -f *.tmp *.log

# Install dependencies
.PHONY: setup
setup:
	@if command -v brew &> /dev/null; then \
		echo "Installing via Homebrew"; \
		brew install grpcurl jq; \
	elif command -v apt &> /dev/null; then \
		echo "Installing via apt"; \
		sudo apt install -y grpcurl jq; \
	else \
		echo "Cannot find package manager"; \
		exit 1; \
	fi

# Verify configuration
.PHONY: check
check:
	grpcurl --version
	jq --version
	docker --version

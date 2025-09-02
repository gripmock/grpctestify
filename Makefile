# grpctestify Makefile - Simple build system
SHELL := /bin/bash
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-print-directory

# Configuration
APP_NAME := grpctestify
MAIN_SCRIPT := grpctestify.sh
SRC_DIR := src

# Get version dynamically from the script (after it's generated)
VERSION = $(shell test -f $(MAIN_SCRIPT) && ./$(MAIN_SCRIPT) --version 2>/dev/null || echo "unknown")

# Build target
.PHONY: generate
generate:
	@echo "🔧 Generating $(MAIN_SCRIPT) from modular source using bashly..."
	@BASHLY_SOURCE_DIR=$(SRC_DIR) bashly generate -u
	@echo "✅ $(MAIN_SCRIPT) generated successfully!"

# Testing targets  
.PHONY: test
test: generate
	@echo "🧪 Running unit tests with bats..."
	@find $(SRC_DIR) -name "*.bats" -not -name "*_bench.bats" -exec bats {} \;

.PHONY: test-bench
test-bench: generate
	@echo "🏃‍♂️ Running benchmark and stress tests..."
	@if command -v bats >/dev/null 2>&1; then \
		echo "⚡ Running mutex benchmark tests..."; \
		bats src/lib/plugins/utils/process_mutex_bench.bats || true; \
		echo "⚡ Running IO benchmark tests..."; \
		bats src/lib/plugins/utils/custom_io_bench.bats || true; \
		echo "⚡ Running infinite loop prevention tests..."; \
		bats src/lib/kernel/infinite_loop_prevention.bats || true; \
	else \
		echo "❌ bats not found. Install with: brew install bats-core"; \
		exit 1; \
	fi

.PHONY: test-all
test-all: test test-bench
	@echo "✅ All tests completed"

.PHONY: test-gripmock
test-gripmock: generate
	@echo "🧪 Testing with gripmock examples..."
	@echo "Note: This requires gripmock to be running on localhost:4770"
	@./$(MAIN_SCRIPT) /tmp/gripmock/examples/types/well-known-types/ || echo "gripmock tests failed"

.PHONY: test-examples
test-examples: generate
	@echo "🧪 Testing local examples..."
	@./$(MAIN_SCRIPT) examples/basic-examples/user-management/tests/ || echo "local examples need servers running"

# Utility targets
.PHONY: check
check: generate
	@echo "🔍 Checking installation..."
	@command -v grpcurl >/dev/null || echo "❌ grpcurl not found"
	@command -v jq >/dev/null || echo "❌ jq not found"
	@command -v bashly >/dev/null || echo "❌ bashly not found"
	@test -f $(MAIN_SCRIPT) && ./$(MAIN_SCRIPT) --version || echo "Run 'make generate' first"

.PHONY: clean
clean:
	@echo "🧹 Cleaning up..."
	@rm -f *.tmp *.log *.backup
	@rm -rf dist/

.PHONY: help
help:
	@echo "$(APP_NAME) Makefile - Available targets:"
	@echo ""
	@echo "  generate        - Generate $(MAIN_SCRIPT) from source"
	@echo "  test            - Run unit tests (bats)"
	@echo "  test-bench      - Run performance/stress tests and infinite loop prevention"
	@echo "  test-all        - Run all tests (unit + benchmark)"
	@echo "  test-gripmock   - Test with gripmock examples (requires gripmock running)"
	@echo "  test-examples   - Test with local examples (requires servers running)"
	@echo "  check           - Verify installation"
	@echo "  clean           - Clean temporary files"
	@echo "  help            - Show this help"
	@echo ""
	@echo "Version: $(VERSION)"

.DEFAULT_GOAL := help
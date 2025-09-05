#!/bin/bash

# Call the existing implementation
source "$(dirname "$0")/../lib/commands/run.sh"

# Get test paths from bashly args
test_paths=("${args[test_paths]}")

# Call the main function from run.sh
run_tests "${test_paths[@]}"

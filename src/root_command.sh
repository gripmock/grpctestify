# Get test paths from bashly args - repeatable args may arrive as a single string
# Normalize into an array
if [[ -n "${args[test_paths]:-}" ]]; then
    test_paths=("${args[test_paths]}")
    if [[ ${#test_paths[@]} -eq 1 && "${test_paths[0]}" =~ [[:space:]] ]]; then
        IFS=' ' read -r -a test_paths <<< "${test_paths[0]}"
    fi
else
    test_paths=()
fi

# Invoke once with all paths (so parallelism spans all inputs)
run_tests "${test_paths[@]}"
exit $?

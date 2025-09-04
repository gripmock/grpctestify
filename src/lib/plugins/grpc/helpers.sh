#!/usr/bin/env bash

# Shared gRPC helpers (centralized)
# build_grpcurl_args, render_grpcurl_preview, execute_grpcurl_argv

# Build -H header arguments from newline-separated headers into an array variable name
# Usage: grpc_build_header_args "$headers_text" header_array_name
grpc_build_header_args() {
    local headers_text="$1"
    local _out_name="$2"
    local -a _tmp=()
    if [[ -n "$headers_text" ]]; then
        while IFS= read -r _h; do
            [[ -z "$_h" || "$_h" =~ ^[[:space:]]*$ ]] && continue
            _tmp+=("-H" "$_h")
        done <<< "$headers_text"
    fi
    eval "$_out_name=(\"\${_tmp[@]}\")"
}

build_grpcurl_args() {
    local address="$1"
    local endpoint="$2"
    local tls_json="$3"
    local proto_json="$4"
    local -n headers_ref=$5
    local request_present="$6"

    GRPCURL_ARGS=(grpcurl)

    # TLS (accept both legacy and plugin JSON schemas)
    local tls_mode="plaintext"
    if [[ -n "$tls_json" ]]; then
        tls_mode=$(echo "$tls_json" | jq -r '.mode // "plaintext"' 2>/dev/null || echo "plaintext")
    fi
    case "$tls_mode" in
        plaintext|"")
            GRPCURL_ARGS+=("-plaintext")
            ;;
        insecure)
            GRPCURL_ARGS+=("-insecure")
            ;;
        tls|mtls)
            # Prefer plugin schema: certificates.{client_cert,client_key,ca_cert}, options.{server_name,authority}, options.insecure
            local cert_file key_file ca_file server_name authority insecure_opt
            cert_file=$(echo "$tls_json" | jq -r '.certificates.client_cert // .cert_file // empty' 2>/dev/null)
            key_file=$(echo "$tls_json" | jq -r '.certificates.client_key // .key_file // empty' 2>/dev/null)
            ca_file=$(echo "$tls_json" | jq -r '.certificates.ca_cert // .ca_file // empty' 2>/dev/null)
            server_name=$(echo "$tls_json" | jq -r '.options.server_name // .server_name // empty' 2>/dev/null)
            authority=$(echo "$tls_json" | jq -r '.options.authority // .authority // empty' 2>/dev/null)
            insecure_opt=$(echo "$tls_json" | jq -r '(.options.insecure // false) | tostring' 2>/dev/null)
            [[ "$insecure_opt" == "true" ]] && GRPCURL_ARGS+=("-insecure")
            [[ -n "$ca_file" ]] && GRPCURL_ARGS+=("-cacert" "$ca_file")
            [[ -n "$cert_file" ]] && GRPCURL_ARGS+=("-cert" "$cert_file")
            [[ -n "$key_file" ]] && GRPCURL_ARGS+=("-key" "$key_file")
            [[ -n "$server_name" ]] && GRPCURL_ARGS+=("-servername" "$server_name")
            [[ -n "$authority" ]] && GRPCURL_ARGS+=("-authority" "$authority")
            ;;
        *)
            # Fallback to plaintext for unknown modes
            GRPCURL_ARGS+=("-plaintext")
            ;;
    esac

    # Proto
    if [[ -n "$proto_json" ]]; then
        local proto_file
        proto_file=$(echo "$proto_json" | jq -r '.file // empty' 2>/dev/null)
        [[ -n "$proto_file" ]] && GRPCURL_ARGS+=("-proto" "$proto_file")
    fi

    # Headers
    if [[ ${#headers_ref[@]} -gt 0 ]]; then
        for ((i=0; i<${#headers_ref[@]}; i+=2)); do
            local flag="${headers_ref[i]}"; local header="${headers_ref[i+1]}"
            GRPCURL_ARGS+=("$flag" "$header")
        done
    fi

    # Always include format option before positional args
    GRPCURL_ARGS+=("-format-error")

    # Data
    if [[ "$request_present" == "1" ]]; then
        GRPCURL_ARGS+=("-d" "@")
    fi

    # Address + endpoint
    GRPCURL_ARGS+=("$address" "$endpoint")
}

render_grpcurl_preview() {
    local request="$1"; shift
    local -a argv=("$@")
    if [[ -n "$request" ]]; then
        printf "echo '%s' | %s\n" "$request" "${argv[*]}"
    else
        printf "%s\n" "${argv[*]}"
    fi
}

execute_grpcurl_argv() {
    local timeout_seconds="$1"; shift
    local request="$1"; shift
    local -a argv=("$@")

    if [[ -n "$request" ]]; then
        echo "$request" | kernel_timeout "$timeout_seconds" "${argv[@]}" 2>&1
    else
        kernel_timeout "$timeout_seconds" "${argv[@]}" 2>&1
    fi
}

# Export helpers
export -f grpc_build_header_args build_grpcurl_args render_grpcurl_preview execute_grpcurl_argv

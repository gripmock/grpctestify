#!/usr/bin/env bats

# update.bats - Tests for update.sh module

# Load the update module
load "/load "${BATS_TEST_DIRNAME}/update.sh'"

@test "update_command function handles update command" {
    # Test update command
    run update_command
    [ $status -eq 0 ]
}

@test "check_for_updates function checks for updates" {
    # Test update checking
    run check_for_updates
    [ $status -eq 0 ]
}

@test "get_latest_version function gets latest version" {
    # Test latest version retrieval
    run get_latest_version
    [ $status -eq 0 ]
}

@test "download_latest function downloads latest version" {
    # Test latest version download
    run download_latest "/tmp/test_download"
    [ $status -eq 0 ]
}

@test "verify_checksum function verifies checksum" {
    # Test checksum verification
    run verify_checksum "/tmp/test_file" "test_checksum"
    [ $status -ne 0 ]  # Expected to fail with invalid checksum
}

@test "install_update function installs update" {
    # Test update installation
    run install_update "/tmp/test_file"
    [ $status -eq 0 ]
}

@test "confirm_update function confirms update" {
    # Test update confirmation
    run confirm_update "1.0.0" "1.1.0"
    [ $status -eq 0 ]
}

@test "perform_update function performs update" {
    # Test update performance
    run perform_update
    [ $status -eq 0 ]
}

@test "show_update_help function shows update help" {
    # Test update help display
    run show_update_help
    [ $status -eq 0 ]
    [[ "$output" =~ "update" ]]
}
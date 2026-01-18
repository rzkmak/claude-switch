#!/bin/bash
# Test Helper for Claude Switch Script
# Provides sandboxed testing environment

# Test colors
TEST_RED='\033[0;31m'
TEST_GREEN='\033[0;32m'
TEST_YELLOW='\033[1;33m'
TEST_BLUE='\033[0;34m'
TEST_NC='\033[0m'

# Test statistics
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test environment
TEST_TMP_DIR=""
TEST_HOME_DIR=""
ORIGINAL_HOME=""

# Setup test environment
setup_test_env() {
    # Create a temporary directory for testing
    TEST_TMP_DIR=$(mktemp -d -t claude-switch-test-XXXXXX)
    TEST_HOME_DIR="$TEST_TMP_DIR/home"

    # Save original HOME
    ORIGINAL_HOME="$HOME"

    # Create fake home directory structure
    mkdir -p "$TEST_HOME_DIR/.claude/profiles"
    mkdir -p "$TEST_HOME_DIR/.claude/backups"

    # Export test home
    export HOME="$TEST_HOME_DIR"
    export CLAUDE_DIR="$HOME/.claude"
    export CLAUDE_AUTH="$HOME/.claude.json"
    export CLAUDE_SETTINGS="$CLAUDE_DIR/settings.json"
    export PROFILES_DIR="$CLAUDE_DIR/profiles"
    export BACKUP_DIR="$CLAUDE_DIR/backups"

    # Disable keychain operations in tests
    MOCK_KEYCHAIN=1
}

# Cleanup test environment
cleanup_test_env() {
    # Restore original HOME
    export HOME="$ORIGINAL_HOME"

    # Remove test directory
    if [[ -n "$TEST_TMP_DIR" && -d "$TEST_TMP_DIR" ]]; then
        rm -rf "$TEST_TMP_DIR"
    fi
}

# Assert functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Expected '$expected' but got '$actual'}"

    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        echo "  FAIL: $message"
        echo "    Expected: $expected"
        echo "    Actual: $actual"
        return 1
    fi
}

assert_not_equals() {
    local not_expected="$1"
    local actual="$2"
    local message="${3:-Expected '$not_expected' to not equal '$actual'}"

    if [[ "$not_expected" != "$actual" ]]; then
        return 0
    else
        echo "  FAIL: $message"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist: $file}"

    if [[ -f "$file" ]]; then
        return 0
    else
        echo "  FAIL: $message"
        return 1
    fi
}

assert_file_not_exists() {
    local file="$1"
    local message="${2:-File should not exist: $file}"

    if [[ ! -f "$file" ]]; then
        return 0
    else
        echo "  FAIL: $message"
        return 1
    fi
}

assert_dir_exists() {
    local dir="$1"
    local message="${2:-Directory should exist: $dir}"

    if [[ -d "$dir" ]]; then
        return 0
    else
        echo "  FAIL: $message"
        return 1
    fi
}

assert_symlink() {
    local file="$1"
    local message="${2:-File should be a symlink: $file}"

    if [[ -L "$file" ]]; then
        return 0
    else
        echo "  FAIL: $message"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Expected '$haystack' to contain '$needle'}"

    if [[ "$haystack" == *"$needle"* ]]; then
        return 0
    else
        echo "  FAIL: $message"
        return 1
    fi
}

assert_success() {
    local result="$1"
    local message="${2:-Command should succeed but failed}"

    if [[ "$result" == "0" ]]; then
        return 0
    else
        echo "  FAIL: $message (exit code: $result)"
        return 1
    fi
}

assert_fail() {
    local result="$1"
    local message="${2:-Command should fail but succeeded}"

    if [[ "$result" != "0" ]]; then
        return 0
    else
        echo "  FAIL: $message"
        return 1
    fi
}

# Test runner
run_test() {
    local test_name="$1"
    local test_function="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    echo -n "  $test_name ... "

    # Setup test environment
    setup_test_env

    # Run test function
    if $test_function; then
        echo -e "${TEST_GREEN}PASS${TEST_NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${TEST_RED}FAIL${TEST_NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    # Cleanup test environment
    cleanup_test_env
}

# Test suite
run_test_suite() {
    local suite_name="$1"

    echo -e "${TEST_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${TEST_NC}"
    echo -e "${TEST_BLUE}$suite_name${TEST_NC}"
    echo -e "${TEST_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${TEST_NC}"
    echo ""

    # Run all test functions starting with "test_"
    local test_functions=$(declare -F | awk '{print $3}' | grep '^test_')
    for test_func in $test_functions; do
        run_test "$test_func" "$test_func"
    done

    echo ""
}

# Print test results summary
print_test_summary() {
    echo -e "${TEST_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${TEST_NC}"
    echo -e "${TEST_BLUE}Test Summary${TEST_NC}"
    echo -e "${TEST_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${TEST_NC}"
    echo "  Total:  $TESTS_RUN"
    echo -e "  ${TEST_GREEN}Passed:$TEST_NC $TESTS_PASSED"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "  ${TEST_RED}Failed:$TEST_NC $TESTS_FAILED"
        return 1
    else
        echo "  Failed: $TESTS_FAILED"
        return 0
    fi
}

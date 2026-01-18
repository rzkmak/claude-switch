#!/bin/bash
# Unit Tests for Claude Switch Script
# Run with: bash tests/test_claude_switch.bats

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source the test helper
source "$SCRIPT_DIR/test_helper.sh"

# Source the main script functions without running main()
source_script() {
    # Source the script, but skip the main() call at the end
    source "$PROJECT_DIR/claude-switch.sh"

    # Override functions that interact with real system
    has_keychain_credentials() {
        return 1  # Always return false in tests
    }

    backup_keychain_to_profile() {
        return 0  # No-op in tests
    }

    restore_keychain_from_profile() {
        return 1  # Always fail in tests
    }

    delete_keychain_credentials() {
        return 0  # No-op in tests
    }
}

# Source the script before running tests
source_script

#==============================================================================
# Test: Profile Creation (save_profile)
#==============================================================================

test_save_profile_creates_directory() {
    # Create a fake auth file
    cat > "$CLAUDE_AUTH" << 'EOF'
{
  "oauthAccount": {
    "emailAddress": "test@example.com"
  }
}
EOF

    # Save profile
    save_profile "test-profile" > /dev/null 2>&1

    # Assert profile directory was created
    assert_dir_exists "$PROFILES_DIR/test-profile" "Profile directory should be created"
}

test_save_profile_copies_auth_file() {
    # Create a fake auth file
    cat > "$CLAUDE_AUTH" << 'EOF'
{
  "oauthAccount": {
    "emailAddress": "test@example.com"
  }
}
EOF

    # Save profile
    save_profile "test-profile" > /dev/null 2>&1

    # Assert auth file was copied
    assert_file_exists "$PROFILES_DIR/test-profile/auth.json" "Auth file should be copied"
}

test_save_profile_copies_settings_file() {
    # Create fake auth and settings files
    # Use OAuth only to avoid confirmation prompt
    cat > "$CLAUDE_AUTH" << 'EOF'
{
  "oauthAccount": {
    "emailAddress": "test@example.com"
  }
}
EOF

    # Create settings file (this will still be copied even without API key)
    cat > "$CLAUDE_SETTINGS" << 'EOF'
{
  "model": "sonnet"
}
EOF

    # Save profile
    save_profile "test-profile" > /dev/null 2>&1

    # Assert settings file was copied
    assert_file_exists "$PROFILES_DIR/test-profile/settings.json" "Settings file should be copied"
}

test_save_profile_without_valid_auth_fails() {
    # Create invalid auth file (no OAuth or API key)
    cat > "$CLAUDE_AUTH" << 'EOF'
{
  "hasCompletedOnboarding": true
}
EOF

    # Save profile should fail (run in subshell to catch exit)
    (save_profile "test-profile" > /dev/null 2>&1) || local result=$?

    # Assert it failed (non-zero exit code)
    assert_fail ${result:-1} "save_profile should fail without valid authentication"
}

#==============================================================================
# Test: Profile Switching (switch_profile)
#==============================================================================

test_switch_profile_creates_symlink_for_oauth() {
    # Create a profile with OAuth
    mkdir -p "$PROFILES_DIR/test-profile"
    cat > "$PROFILES_DIR/test-profile/auth.json" << 'EOF'
{
  "oauthAccount": {
    "emailAddress": "test@example.com"
  }
}
EOF

    # Create existing auth file first
    cat > "$CLAUDE_AUTH" << 'EOF'
{"hasCompletedOnboarding": true}
EOF

    # Switch to profile
    switch_profile "test-profile" > /dev/null 2>&1

    # Assert symlink was created
    assert_symlink "$CLAUDE_AUTH" "Auth file should be a symlink"

    # Assert settings.json does not exist (removed for OAuth)
    assert_file_not_exists "$CLAUDE_SETTINGS" "Settings should be removed for OAuth profile"
}

test_switch_profile_creates_symlink_for_api_key() {
    # Create a profile with API key
    mkdir -p "$PROFILES_DIR/test-profile"
    cat > "$PROFILES_DIR/test-profile/auth.json" << 'EOF'
{"hasCompletedOnboarding": true}
EOF
    cat > "$PROFILES_DIR/test-profile/settings.json" << 'EOF'
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "test-token"
  }
}
EOF

    # Create existing auth file first
    cat > "$CLAUDE_AUTH" << 'EOF'
{"hasCompletedOnboarding": true}
EOF

    # Switch to profile
    switch_profile "test-profile" > /dev/null 2>&1

    # Assert settings symlink was created
    assert_symlink "$CLAUDE_SETTINGS" "Settings file should be a symlink"

    # Assert auth.json exists and is NOT a symlink (API key uses regular file)
    if [[ -L "$CLAUDE_AUTH" ]]; then
        echo "  FAIL: Auth file should not be a symlink for API key profile"
        return 1
    fi
}

test_switch_nonexistent_profile_fails() {
    # Try to switch to non-existent profile (run in subshell to catch exit)
    (switch_profile "nonexistent-profile" > /dev/null 2>&1) || local result=$?

    # Assert it failed
    assert_fail ${result:-1} "Switching to non-existent profile should fail"
}

#==============================================================================
# Test: Profile Listing (list_profiles)
#==============================================================================

test_list_profiles_with_no_profiles() {
    # List profiles when none exist
    local output=$(list_profiles)

    # Should contain "No profiles found"
    assert_contains "$output" "No profiles found" "Should show message when no profiles exist"
}

test_list_profiles_shows_profiles() {
    # Create two profiles
    mkdir -p "$PROFILES_DIR/profile1"
    cat > "$PROFILES_DIR/profile1/auth.json" << 'EOF'
{"oauthAccount": {"emailAddress": "profile1@example.com"}}
EOF

    mkdir -p "$PROFILES_DIR/profile2"
    cat > "$PROFILES_DIR/profile2/auth.json" << 'EOF'
{"oauthAccount": {"emailAddress": "profile2@example.com"}}
EOF

    # List profiles
    local output=$(list_profiles)

    # Should contain both profile names
    assert_contains "$output" "profile1" "Should show profile1"
    assert_contains "$output" "profile2" "Should show profile2"
}

#==============================================================================
# Test: Profile Deletion (delete_profile)
#==============================================================================

test_delete_profile_removes_directory() {
    # Create a profile
    mkdir -p "$PROFILES_DIR/test-profile"
    cat > "$PROFILES_DIR/test-profile/auth.json" << 'EOF'
{"oauthAccount": {"emailAddress": "test@example.com"}}
EOF

    # Delete profile (run in subshell to catch exit)
    echo "y" | (delete_profile "test-profile" > /dev/null 2>&1)

    # Assert directory was removed
    if [[ -d "$PROFILES_DIR/test-profile" ]]; then
        echo "  FAIL: Profile directory should be deleted"
        return 1
    fi
}

test_delete_nonexistent_profile_fails() {
    # Try to delete non-existent profile (run in subshell to catch exit)
    (delete_profile "nonexistent-profile" > /dev/null 2>&1) || local result=$?

    # Should fail (non-zero exit code)
    assert_fail ${result:-1} "Deleting non-existent profile should fail"
}

#==============================================================================
# Test: Current Profile Detection (get_current_profile)
#==============================================================================

test_get_current_profile_with_symlink() {
    # Create a profile
    mkdir -p "$PROFILES_DIR/test-profile"
    cat > "$PROFILES_DIR/test-profile/auth.json" << 'EOF'
{"oauthAccount": {"emailAddress": "test@example.com"}}
EOF

    # Create symlink
    ln -sf "$PROFILES_DIR/test-profile/auth.json" "$CLAUDE_AUTH"

    # Get current profile
    local current=$(get_current_profile)

    # Should return "test-profile"
    assert_equals "test-profile" "$current" "Should detect current profile from symlink"
}

test_get_current_profile_without_symlink() {
    # Create a regular auth file (not a symlink)
    cat > "$CLAUDE_AUTH" << 'EOF'
{"oauthAccount": {"emailAddress": "test@example.com"}}
EOF

    # Get current profile
    local current=$(get_current_profile)

    # Should return "unknown" (file exists but doesn't match any profile)
    assert_equals "unknown" "$current" "Should return 'unknown' when auth exists but doesn't match any profile"
}

#==============================================================================
# Test: First-time Setup
#==============================================================================

test_first_time_setup_creates_backups() {
    # Create fake auth file
    cat > "$CLAUDE_AUTH" << 'EOF'
{"oauthAccount": {"emailAddress": "test@example.com"}}
EOF

    # Run first-time setup (will prompt for profile, we'll pipe "n")
    echo "n" | first_time_setup > /dev/null 2>&1

    # Assert backups were created
    assert_file_exists "$BACKUP_DIR/original-auth.json" "Should backup original auth"
}

test_first_time_setup_skips_if_already_backed_up() {
    # Create fake auth file and backup
    cat > "$CLAUDE_AUTH" << 'EOF'
{"oauthAccount": {"emailAddress": "test@example.com"}}
EOF
    mkdir -p "$BACKUP_DIR"
    cat > "$BACKUP_DIR/original-auth.json" << 'EOF'
{"oauthAccount": {"emailAddress": "original@example.com"}}
EOF

    # Run first-time setup
    first_time_setup > /dev/null 2>&1

    # Original backup should not be modified (check if it still has original content)
    local content=$(cat "$BACKUP_DIR/original-auth.json")
    assert_contains "$content" "original@example.com" "Should not overwrite existing backup"
}

#==============================================================================
# Test: OAuth vs API Key Detection
#==============================================================================

test_is_oauth_profile_detects_oauth() {
    # Create OAuth profile
    mkdir -p "$PROFILES_DIR/oauth-profile"
    cat > "$PROFILES_DIR/oauth-profile/auth.json" << 'EOF'
{
  "oauthAccount": {
    "emailAddress": "oauth@example.com"
  }
}
EOF

    # Should detect as OAuth
    if ! is_oauth_profile "$PROFILES_DIR/oauth-profile"; then
        echo "  FAIL: Should detect OAuth profile"
        return 1
    fi
}

test_is_oauth_profile_detects_api_key() {
    # Create API key profile
    mkdir -p "$PROFILES_DIR/api-profile"
    cat > "$PROFILES_DIR/api-profile/auth.json" << 'EOF'
{"hasCompletedOnboarding": true}
EOF
    cat > "$PROFILES_DIR/api-profile/settings.json" << 'EOF'
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "test-token"
  }
}
EOF

    # Should NOT detect as OAuth
    if is_oauth_profile "$PROFILES_DIR/api-profile"; then
        echo "  FAIL: Should not detect API key profile as OAuth"
        return 1
    fi
}

#==============================================================================
# Test: Auth Token Clearing
#==============================================================================

test_clear_oauth_tokens_removes_session_token() {
    # Create auth file with OAuth tokens
    local test_auth=$(mktemp)
    cat > "$test_auth" << 'EOF'
{
  "sessionToken": "test-session-token",
  "oauthAccount": {
    "emailAddress": "test@example.com"
  },
  "hasCompletedOnboarding": true
}
EOF

    # Clear OAuth tokens
    clear_oauth_tokens "$test_auth"

    # Check that sessionToken was removed
    local content=$(cat "$test_auth")
    if [[ "$content" == *"sessionToken"* ]]; then
        echo "  FAIL: sessionToken should be removed"
        rm -f "$test_auth"
        return 1
    fi

    rm -f "$test_auth"
}

test_clear_oauth_tokens_preserves_other_fields() {
    # Create auth file with mixed data
    local test_auth=$(mktemp)
    cat > "$test_auth" << 'EOF'
{
  "sessionToken": "test-session-token",
  "oauthAccount": {"emailAddress": "test@example.com"},
  "hasCompletedOnboarding": true,
  "customApiKeyResponses": {"approved": ["local"]}
}
EOF

    # Clear OAuth tokens
    clear_oauth_tokens "$test_auth"

    # Check that hasCompletedOnboarding is still present
    local content=$(cat "$test_auth")
    if [[ "$content" != *"hasCompletedOnboarding"* ]]; then
        echo "  FAIL: hasCompletedOnboarding should be preserved"
        rm -f "$test_auth"
        return 1
    fi

    rm -f "$test_auth"
}

#==============================================================================
# Main Test Runner
#==============================================================================

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  Claude Account Switcher - Unit Test Suite                 ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    # Run test suites
    run_test_suite "Profile Creation Tests"
    run_test_suite "Profile Switching Tests"
    run_test_suite "Profile Listing Tests"
    run_test_suite "Profile Deletion Tests"
    run_test_suite "Current Profile Detection Tests"
    run_test_suite "First-Time Setup Tests"
    run_test_suite "OAuth/API Key Detection Tests"
    run_test_suite "Auth Token Clearing Tests"

    # Print summary
    echo ""
    print_test_summary
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

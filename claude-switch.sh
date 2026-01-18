#!/usr/bin/env bash

# Claude Account Switcher
# Safely switch between multiple Claude CLI accounts
# Version: 1.0.2

set -euo pipefail

# Configuration
CLAUDE_DIR="$HOME/.claude"
CLAUDE_AUTH="$HOME/.claude.json"
CLAUDE_SETTINGS="$CLAUDE_DIR/settings.json"
PROFILES_DIR="$CLAUDE_DIR/profiles"
BACKUP_DIR="$CLAUDE_DIR/backups"
KEYCHAIN_SERVICE="Claude Code-credentials"
KEYCHAIN_ACCOUNT="user"

# Colors for output - using tput for better compatibility
if command -v tput &> /dev/null && tput setaf 1 &> /dev/null; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    NC=$(tput sgr0) # No Color
else
    # Fallback to standard ANSI if tput fails
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' 
fi

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Keychain management functions (macOS only)
# Claude Code stores OAuth credentials in the macOS keychain

# Check if keychain credentials exist
has_keychain_credentials() {
    security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" &> /dev/null
}

# Backup keychain credentials to a profile directory
backup_keychain_to_profile() {
    local profile_dir="$1"

    if ! has_keychain_credentials; then
        return 0
    fi

    # Extract the password (OAuth token) from keychain
    local token
    token=$(security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -w 2>/dev/null) || return 0

    # Save to profile directory (base64 encoded for safety)
    # Use printf to avoid adding trailing newline that would corrupt the token
    printf '%s' "$token" | base64 > "$profile_dir/keychain-credentials.b64"
}

# Restore keychain credentials from a profile directory
restore_keychain_from_profile() {
    local profile_dir="$1"
    local cred_file="$profile_dir/keychain-credentials.b64"

    if [[ ! -f "$cred_file" ]]; then
        return 1
    fi

    # Delete existing keychain entry if present
    security delete-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" &> /dev/null || true

    # Decode and restore the token
    local token
    token=$(base64 -d < "$cred_file")

    # Add back to keychain
    security add-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -w "$token" &> /dev/null
}

# Delete keychain credentials
delete_keychain_credentials() {
    security delete-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" &> /dev/null || true
}

# Initialize profiles directory
init_profiles() {
    if [[ ! -d "$PROFILES_DIR" ]]; then
        log_info "Creating profiles directory..."
        mkdir -p "$PROFILES_DIR"
        log_success "Profiles directory created at $PROFILES_DIR"
    fi
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        log_success "Backup directory created at $BACKUP_DIR"
    fi
}

# First-time setup: backup current configuration (if exists)
first_time_setup() {
    local original_auth_backup="$BACKUP_DIR/original-auth.json"
    local original_settings_backup="$BACKUP_DIR/original-settings.json"

    if [[ -f "$original_auth_backup" ]]; then
        # Already backed up
        return 0
    fi

    # If no existing auth, that's okay - user can create API key profile
    if [[ ! -f "$CLAUDE_AUTH" ]]; then
        return 0
    fi

    log_warning "First-time setup detected!"
    log_info "Backing up your original Claude configuration..."

    # Backup both auth and settings
    cp "$CLAUDE_AUTH" "$original_auth_backup"
    log_success "Original auth backed up to: $original_auth_backup"

    if [[ -f "$CLAUDE_SETTINGS" ]]; then
        cp "$CLAUDE_SETTINGS" "$original_settings_backup"
        log_success "Original settings backed up to: $original_settings_backup"
    fi

    echo ""
    read -p "Would you like to save this as a profile? (y/n): " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter profile name (e.g., 'anthropic', 'z.ai'): " profile_name
        if [[ -n "$profile_name" ]]; then
            mkdir -p "$PROFILES_DIR/${profile_name}"
            cp "$CLAUDE_AUTH" "$PROFILES_DIR/${profile_name}/auth.json"
            if [[ -f "$CLAUDE_SETTINGS" ]]; then
                cp "$CLAUDE_SETTINGS" "$PROFILES_DIR/${profile_name}/settings.json"
            fi
            log_success "Current configuration saved as profile: $profile_name"
        fi
    fi
}

# List all available profiles
list_profiles() {
    echo ""
    log_info "Available profiles:"
    echo ""
    
    if [[ ! -d "$PROFILES_DIR" ]] || [[ -z "$(ls -A "$PROFILES_DIR" 2>/dev/null)" ]]; then
        log_warning "No profiles found. Create one with: $0 new <profile-name>"
        return 0
    fi
    
    local current_profile=$(get_current_profile)
    
    for profile_dir in "$PROFILES_DIR"/*; do
        if [[ -d "$profile_dir" ]]; then
            local name=$(basename "$profile_dir")
            local marker=""
            
            if [[ "$name" == "$current_profile" ]]; then
                marker=" ${GREEN}(active)${NC}"
            fi
            
            echo -e "  • $name$marker"
            
            # Show some details from the profile
            if command -v jq &> /dev/null && [[ -f "$profile_dir/auth.json" ]]; then
                local email=$(jq -r '.oauthAccount.emailAddress // .oauthAccount.email // "API Key"' "$profile_dir/auth.json" 2>/dev/null)
                echo -e "    ${BLUE}Account:${NC} $email"
                
                if [[ -f "$profile_dir/settings.json" ]]; then
                    local base_url=$(jq -r '.env.ANTHROPIC_BASE_URL // "not set"' "$profile_dir/settings.json" 2>/dev/null)
                    local model=$(jq -r '.model // "default"' "$profile_dir/settings.json" 2>/dev/null)
                    echo -e "    ${BLUE}URL:${NC} $base_url"
                    echo -e "    ${BLUE}Model:${NC} $model"
                fi
            fi
            echo ""
        fi
    done
}

# Get current active profile
get_current_profile() {
    if [[ ! -f "$CLAUDE_AUTH" ]]; then
        echo "none"
        return
    fi
    
    local current_hash=$(md5 -q "$CLAUDE_AUTH" 2>/dev/null || md5sum "$CLAUDE_AUTH" | cut -d' ' -f1)
    
    for profile_dir in "$PROFILES_DIR"/*; do
        if [[ -d "$profile_dir" && -f "$profile_dir/auth.json" ]]; then
            local profile_hash=$(md5 -q "$profile_dir/auth.json" 2>/dev/null || md5sum "$profile_dir/auth.json" | cut -d' ' -f1)
            if [[ "$current_hash" == "$profile_hash" ]]; then
                basename "$profile_dir"
                return
            fi
        fi
    done
    
    echo "unknown"
}

# Save current configuration as a profile
save_profile() {
    local profile_name="$1"
    
    if [[ -z "$profile_name" ]]; then
        log_error "Profile name is required"
        echo "Usage: $0 save <profile-name>"
        exit 1
    fi
    
    if [[ ! -f "$CLAUDE_AUTH" ]]; then
        log_error "No Claude auth found at $CLAUDE_AUTH"
        exit 1
    fi
    
    # Validate that we have valid authentication
    local has_oauth=false
    local has_apikey=false
    
    if command -v jq &> /dev/null; then
        # Check for OAuth tokens (sessionToken OR oauthAccount)
        local has_session=$(jq -r '(.sessionToken != null and .sessionToken != "") or (.oauthAccount != null)' "$CLAUDE_AUTH" 2>/dev/null)
        if [[ "$has_session" == "true" ]]; then
            has_oauth=true
        fi
        
        # Check for API key in settings
        if [[ -f "$CLAUDE_SETTINGS" ]]; then
            local has_api=$(jq -r '(.env.ANTHROPIC_API_KEY != null and .env.ANTHROPIC_API_KEY != "") or (.env.ANTHROPIC_AUTH_TOKEN != null and .env.ANTHROPIC_AUTH_TOKEN != "")' "$CLAUDE_SETTINGS" 2>/dev/null)
            if [[ "$has_api" == "true" ]]; then
                has_apikey=true
            fi
        fi
    fi
    
    # Warn if no valid authentication found
    if [[ "$has_oauth" == "false" && "$has_apikey" == "false" ]]; then
        log_error "No valid authentication found!"
        echo ""
        echo "This profile would not have working authentication."
        echo ""
        echo "Please set up authentication first."
        echo ""
        echo "Tip: Use 'claude-switch new [name]' for a guided setup."
        echo ""
        exit 1
    fi
    
    # Show what type of auth will be saved
    if [[ "$has_oauth" == "true" ]]; then
        log_info "Saving OAuth authentication profile"
        if command -v jq &> /dev/null; then
            local email=$(jq -r '.oauthAccount.emailAddress // .oauthAccount.email // "Unknown"' "$CLAUDE_AUTH" 2>/dev/null)
            echo "  Account: $email"
        fi
    fi
    
    if [[ "$has_apikey" == "true" ]]; then
        log_info "Saving API key authentication profile"
        if command -v jq &> /dev/null; then
            local api_url=$(jq -r '.env.ANTHROPIC_BASE_URL // "not set"' "$CLAUDE_SETTINGS" 2>/dev/null)
            echo "  API URL: $api_url"
        fi
    fi
    
    # Warn if both OAuth and API key exist (unusual)
    if [[ "$has_oauth" == "true" && "$has_apikey" == "true" ]]; then
        log_warning "Both OAuth and API key found!"
        echo ""
        echo "This is unusual. Claude will prioritize OAuth over API key."
        echo "Consider using 'claude-switch new [name]' to set up clean authentication."
        echo ""
        read -p "Continue saving this profile? (y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cancelled."
            exit 0
        fi
    fi
    
    local profile_dir="$PROFILES_DIR/${profile_name}"
    
    if [[ -d "$profile_dir" ]]; then
        log_warning "Profile '$profile_name' already exists."
        read -p "Overwrite? (y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cancelled."
            exit 0
        fi
    fi
    
    echo ""
    mkdir -p "$profile_dir"
    cp "$CLAUDE_AUTH" "$profile_dir/auth.json"
    if [[ -f "$CLAUDE_SETTINGS" ]]; then
        cp "$CLAUDE_SETTINGS" "$profile_dir/settings.json"
    fi
    
    # Activate the profile (create symlinks)
    switch_profile "$profile_name" > /dev/null
    
    log_success "Profile '$profile_name' saved and activated!"
}


# Helper function to check if profile uses OAuth or API key
is_oauth_profile() {
    local profile_dir="$1"
    
    if [[ ! -f "$profile_dir/auth.json" ]]; then
        return 1
    fi
    
    # If settings.json exists with API credentials, it's an API key profile
    if [[ -f "$profile_dir/settings.json" ]]; then
        if command -v jq &> /dev/null; then
            local has_api_key=$(jq -r '(.env.ANTHROPIC_API_KEY != null and .env.ANTHROPIC_API_KEY != "") or (.env.ANTHROPIC_AUTH_TOKEN != null and .env.ANTHROPIC_AUTH_TOKEN != "")' "$profile_dir/settings.json" 2>/dev/null)
            if [[ "$has_api_key" == "true" ]]; then
                return 1  # Not OAuth, it's API key
            fi
        else
            # If settings.json exists, assume it's API key
            return 1
        fi
    fi
    
    # Check if auth.json has valid OAuth data (sessionToken OR oauthAccount)
    if command -v jq &> /dev/null; then
        local has_oauth=$(jq -r '(.sessionToken != null and .sessionToken != "") or (.oauthAccount != null)' "$profile_dir/auth.json" 2>/dev/null)
        [[ "$has_oauth" == "true" ]]
    else
        # Fallback: check if file contains non-empty sessionToken
        grep -q '"sessionToken":"[^"]' "$profile_dir/auth.json"
    fi
}

# Helper function to clear OAuth tokens from auth.json
clear_oauth_tokens() {
    local auth_file="$1"
    
    if [[ ! -f "$auth_file" ]]; then
        return
    fi
    
    if command -v jq &> /dev/null; then
        # Clear OAuth-related fields while keeping other data
        local temp_file=$(mktemp)
        jq 'del(.sessionToken, .refreshToken, .oauthAccount)' "$auth_file" > "$temp_file"
        mv "$temp_file" "$auth_file"
    fi
}

# Switch to a different profile
switch_profile() {
    local profile_name="$1"
    
    if [[ -z "$profile_name" ]]; then
        log_error "Profile name is required"
        echo "Usage: $0 switch <profile-name>"
        exit 1
    fi
    
    local profile_dir="$PROFILES_DIR/${profile_name}"
    
    if [[ ! -d "$profile_dir" ]]; then
        log_error "Profile '$profile_name' not found"
        log_info "Available profiles:"
        list_profiles
        exit 1
    fi
    
    log_info "Switching to profile: $profile_name"

    # Backup current keychain credentials to the current active profile (if any)
    local current_profile=$(get_current_profile)
    if [[ "$current_profile" != "none" && "$current_profile" != "unknown" && -d "$PROFILES_DIR/$current_profile" ]]; then
        if has_keychain_credentials; then
            backup_keychain_to_profile "$PROFILES_DIR/$current_profile"
        fi
    fi

    # Ensure profile has an auth.json (create empty if missing)
    if [[ ! -f "$profile_dir/auth.json" ]]; then
        echo "{}" > "$profile_dir/auth.json"
    fi

    # Determine authentication type
    local uses_oauth="false"
    if is_oauth_profile "$profile_dir"; then
        uses_oauth="true"
    fi

    # 2. Configure Auth, Settings, and Keychain
    if [[ "$uses_oauth" == "true" ]]; then
        # OAuth: Symlink auth.json, remove settings.json, restore keychain
        rm -f "$CLAUDE_AUTH"
        ln -s "$profile_dir/auth.json" "$CLAUDE_AUTH"

        # Remove settings.json since OAuth doesn't need it
        rm -f "$CLAUDE_SETTINGS"

        # Restore keychain credentials for this OAuth profile
        if ! restore_keychain_from_profile "$profile_dir"; then
            log_warning "No saved keychain credentials. Run /login in Claude to authenticate."
        fi

    else
        # API Key: Create clean auth.json, symlink settings.json, clear keychain

        # IMPORTANT: Delete keychain credentials to prevent auth conflict
        delete_keychain_credentials

        # Remove settings symlink first, then create new one
        rm -f "$CLAUDE_SETTINGS"
        if [[ -f "$profile_dir/settings.json" ]]; then
            ln -s "$profile_dir/settings.json" "$CLAUDE_SETTINGS"
        else
            log_error "Settings file not found in profile"
            exit 1
        fi

        # For auth.json: preserve user preferences but strip OAuth tokens
        if [[ -f "$CLAUDE_AUTH" ]] && command -v jq &> /dev/null; then
            # Read current auth, strip OAuth fields, ensure hasCompletedOnboarding and pre-approve API key
            local temp_auth=$(mktemp)
            jq 'del(.oauthAccount, .sessionToken, .refreshToken, .accessToken, .expiresAt, .claudeCodeFirstTokenDate) | .hasCompletedOnboarding = true | .customApiKeyResponses = {"approved": ["local"], "rejected": []}' "$CLAUDE_AUTH" > "$temp_auth" 2>/dev/null || echo '{"hasCompletedOnboarding": true, "customApiKeyResponses": {"approved": ["local"], "rejected": []}}' > "$temp_auth"
            rm -f "$CLAUDE_AUTH"
            mv "$temp_auth" "$CLAUDE_AUTH"
        else
            # No existing auth or no jq - create minimal auth with pre-approved API key
            rm -f "$CLAUDE_AUTH"
            cat > "$CLAUDE_AUTH" << 'AUTHEOF'
{
  "hasCompletedOnboarding": true,
  "customApiKeyResponses": {
    "approved": ["local"],
    "rejected": []
  }
}
AUTHEOF
        fi
    fi
    
    log_success "Switched to profile: $profile_name"
    
    # Show current configuration
    echo ""
    log_info "Current configuration:"
    if command -v jq &> /dev/null; then
        echo ""
        if [[ "$uses_oauth" == "true" ]]; then
            echo -e "  ${BLUE}Auth Type:${NC} OAuth"
            echo -e "  ${BLUE}Account:${NC} $(jq -r '.oauthAccount.emailAddress // .oauthAccount.email // "Unknown"' "$CLAUDE_AUTH" 2>/dev/null)"
        else
            echo -e "  ${BLUE}Auth Type:${NC} API Key"
            if [[ -f "$CLAUDE_SETTINGS" ]]; then
                local api_url=$(jq -r '.env.ANTHROPIC_BASE_URL // "not set"' "$CLAUDE_SETTINGS" 2>/dev/null)
                echo -e "  ${BLUE}API URL:${NC} $api_url"
            fi
        fi
    fi
}

# Delete a profile
delete_profile() {
    local profile_name="$1"
    
    if [[ -z "$profile_name" ]]; then
        log_error "Profile name is required"
        echo "Usage: $0 delete <profile-name>"
        exit 1
    fi
    
    local profile_dir="$PROFILES_DIR/${profile_name}"
    
    if [[ ! -d "$profile_dir" ]]; then
        log_error "Profile '$profile_name' not found"
        exit 1
    fi
    
    log_warning "Are you sure you want to delete profile '$profile_name'?"
    read -p "This cannot be undone (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$profile_dir"
        log_success "Profile '$profile_name' deleted"
    else
        log_info "Cancelled"
    fi
}

# Show current active profile
show_current() {
    local current=$(get_current_profile)
    echo ""
    log_info "Current profile: $current"
    
    if [[ -f "$CLAUDE_AUTH" ]]; then
        echo ""
        if command -v jq &> /dev/null; then
            echo -e "  ${BLUE}Account:${NC} $(jq -r '.oauthAccount.emailAddress // .oauthAccount.email // "API Key"' "$CLAUDE_AUTH" 2>/dev/null)"
            
            if [[ -f "$CLAUDE_SETTINGS" ]]; then
                echo ""
                jq -r '.env | to_entries[] | "  \(.key): \(.value)"' "$CLAUDE_SETTINGS" 2>/dev/null
                echo ""
                echo -e "  ${BLUE}Model:${NC} $(jq -r '.model // "default"' "$CLAUDE_SETTINGS" 2>/dev/null)"
            fi
        else
            cat "$CLAUDE_AUTH"
        fi
    fi
    echo ""
}

# Interactive profile creation
create_profile() {
    local profile_name="${1:-}"
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Create New Profile${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Ask for profile name if not provided
    if [[ -z "$profile_name" ]]; then
        read -p "Enter profile name (e.g., 'anthropic', 'z.ai'): " profile_name
        if [[ -z "$profile_name" ]]; then
            log_error "Profile name is required"
            exit 1
        fi
    fi
    
    # Check if profile already exists
    if [[ -d "$PROFILES_DIR/${profile_name}" ]]; then
        log_error "Profile '$profile_name' already exists"
        echo ""
        echo "Use 'claude-switch delete $profile_name' to remove it first,"
        echo "or choose a different name."
        exit 1
    fi
    
    echo ""
    log_info "Creating profile: $profile_name"
    echo ""
    
    # Create profile directory and empty auth file
    mkdir -p "$PROFILES_DIR/${profile_name}"
    echo "{}" > "$PROFILES_DIR/${profile_name}/auth.json"
    
    # Ask for authentication type
    echo "Choose authentication type:"
    echo "  1) OAuth (Anthropic account login)"
    echo "  2) API Key (z.ai or custom endpoint)"
    echo ""
    read -p "Enter choice (1 or 2): " -n 1 auth_choice
    echo ""
    echo ""
    
    case "$auth_choice" in
        1)
            log_info "Setting up OAuth authentication..."
            
            # Switch to the new empty profile immediately using symlinks
            # This ensures subsequent 'claude' login writes to the correct file
            switch_profile "$profile_name" > /dev/null
            
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${GREEN}Action Required:${NC}"
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            echo "Profile '$profile_name' is now active."
            echo ""
            echo "1. Run the following command to open Claude:"
            echo ""
            echo "   ${BLUE}claude${NC}"
            echo ""
            echo "2. Inside Claude, run the login command:"
            echo ""
            echo "   ${BLUE}/login${NC}"
            echo ""
            echo "3. Complete the login in your browser."
            echo "   The token will be saved automatically to this profile."
            echo ""
            echo "   No need to run 'save' again!"
            echo ""
            ;;
            
        2)
            log_info "Setting up API key authentication..."
            
            echo "Enter your API Key (hidden):"
            read -s api_key
            echo ""
            
            if [[ -z "$api_key" ]]; then
                log_error "API key cannot be empty"
                rm -rf "$PROFILES_DIR/${profile_name}"
                exit 1
            fi
            
            echo "Enter Base URL (default: https://api.z.ai/api/anthropic):"
            read base_url
            echo ""
            
            if [[ -z "$base_url" ]]; then
                base_url="https://api.z.ai/api/anthropic"
            fi
            
            # Create auth.json for API key profile (with minimal data to prevent OAuth)
            cat > "$PROFILES_DIR/${profile_name}/auth.json" << 'EOF'
{
  "hasCompletedOnboarding": true,
  "cachedStatsigGates": {},
  "cachedGrowthBookFeatures": {}
}
EOF

            # Create settings.json in profile with API key configuration
            cat > "$PROFILES_DIR/${profile_name}/settings.json" << EOF
{
  "env": {
    "ANTHROPIC_API_KEY": "$api_key",
    "ANTHROPIC_BASE_URL": "$base_url",
    "API_TIMEOUT_MS": "3000000"
  }
}
EOF
            
            # Switch to the new profile (links auth and settings)
            switch_profile "$profile_name" > /dev/null
            
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${GREEN}Success!${NC}"
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            echo "Profile '$profile_name' created and activated."
            echo ""
            ;;
            
        *)
            log_error "Invalid choice"
            rm -rf "$PROFILES_DIR/${profile_name}"
            exit 1
            ;;
    esac
}



# Show help
show_help() {
    cat << EOF
${BLUE}Claude Account Switcher v1.0.2${NC}

Usage: csw <command> [arguments]
       (or claude-switch)

Commands:
  ${GREEN}list${NC}                    List all available profiles
  ${GREEN}current${NC}                 Show current active profile
  ${GREEN}new${NC} [name]              Create a new profile (interactive)
  ${GREEN}save${NC} <name>             Save current configuration as a profile
  ${GREEN}use${NC} <name>              Switch to a different profile
  ${GREEN}delete${NC} <name>           Delete a profile
  ${GREEN}help${NC}                    Show this help message

Examples:
  csw new                   # Create a new profile (interactive)
  csw new anthropic         # Create 'anthropic' profile (skip name prompt)
  csw list                  # List all profiles
  csw use z.ai              # Switch to z.ai profile
  csw current               # Show current active profile

Notes:
  - Your original configuration is automatically backed up on first run
  - Profiles are stored in: $PROFILES_DIR
  - Backups are stored in: $BACKUP_DIR

EOF
}

# Main script
main() {
    # Initialize
    init_profiles
    first_time_setup
    
    # Parse command
    local command="${1:-help}"
    
    case "$command" in
        list|ls)
            list_profiles
            ;;
        current|show)
            show_current
            ;;
        create|new)
            create_profile "${2:-}"
            ;;
        save|add)
            save_profile "${2:-}"
            ;;
        switch|use)
            switch_profile "${2:-}"
            ;;
        delete|rm)
            delete_profile "${2:-}"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

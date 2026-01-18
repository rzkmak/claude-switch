#!/usr/bin/env bash

# Claude Account Switcher
# Safely switch between multiple Claude CLI accounts
# Version: 1.0.0

set -euo pipefail

# Configuration
CLAUDE_DIR="$HOME/.claude"
CLAUDE_AUTH="$HOME/.claude.json"
CLAUDE_SETTINGS="$CLAUDE_DIR/settings.json"
PROFILES_DIR="$CLAUDE_DIR/profiles"
BACKUP_DIR="$CLAUDE_DIR/backups"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# First-time setup: backup current configuration
first_time_setup() {
    local original_auth_backup="$BACKUP_DIR/original-auth.json"
    local original_settings_backup="$BACKUP_DIR/original-settings.json"
    
    if [[ -f "$original_auth_backup" ]]; then
        log_info "Original configuration already backed up."
        return 0
    fi
    
    if [[ ! -f "$CLAUDE_AUTH" ]]; then
        log_error "No existing Claude auth found at $CLAUDE_AUTH"
        log_error "Please run 'claude auth' at least once to initialize."
        exit 1
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
        log_warning "No profiles found. Create one with: $0 save <profile-name>"
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
                local email=$(jq -r '.oauthAccount.email // "API Key"' "$profile_dir/auth.json" 2>/dev/null)
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
    
    mkdir -p "$profile_dir"
    cp "$CLAUDE_AUTH" "$profile_dir/auth.json"
    if [[ -f "$CLAUDE_SETTINGS" ]]; then
        cp "$CLAUDE_SETTINGS" "$profile_dir/settings.json"
    fi
    log_success "Profile '$profile_name' saved successfully!"
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
    
    # Create backup before switching
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_auth="$BACKUP_DIR/auth-${timestamp}.json"
    local backup_settings="$BACKUP_DIR/settings-${timestamp}.json"
    
    if [[ -f "$CLAUDE_AUTH" ]]; then
        cp "$CLAUDE_AUTH" "$backup_auth"
        log_info "Current auth backed up to: $backup_auth"
    fi
    
    if [[ -f "$CLAUDE_SETTINGS" ]]; then
        cp "$CLAUDE_SETTINGS" "$backup_settings"
        log_info "Current settings backed up to: $backup_settings"
    fi
    
    # Switch to new profile
    cp "$profile_dir/auth.json" "$CLAUDE_AUTH"
    if [[ -f "$profile_dir/settings.json" ]]; then
        cp "$profile_dir/settings.json" "$CLAUDE_SETTINGS"
    fi
    log_success "Switched to profile: $profile_name"
    
    # Show current configuration
    echo ""
    log_info "Current configuration:"
    if command -v jq &> /dev/null; then
        echo ""
        echo -e "  ${BLUE}Account:${NC} $(jq -r '.oauthAccount.email // "API Key"' "$CLAUDE_AUTH" 2>/dev/null)"
        if [[ -f "$CLAUDE_SETTINGS" ]]; then
            jq -r '.env | to_entries[] | "  \(.key): \(.value)"' "$CLAUDE_SETTINGS" 2>/dev/null
            echo ""
            echo -e "  ${BLUE}Model:${NC} $(jq -r '.model // "default"' "$CLAUDE_SETTINGS" 2>/dev/null)"
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
            echo -e "  ${BLUE}Account:${NC} $(jq -r '.oauthAccount.email // "API Key"' "$CLAUDE_AUTH" 2>/dev/null)"
            
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

# Show help
show_help() {
    cat << EOF
${BLUE}Claude Account Switcher${NC}

Usage: $0 <command> [arguments]

Commands:
  ${GREEN}list${NC}                    List all available profiles
  ${GREEN}current${NC}                 Show current active profile
  ${GREEN}save${NC} <name>             Save current configuration as a profile
  ${GREEN}switch${NC} <name>           Switch to a different profile
  ${GREEN}delete${NC} <name>           Delete a profile
  ${GREEN}help${NC}                    Show this help message

Examples:
  $0 save anthropic       # Save current config as 'anthropic' profile
  $0 save z.ai            # Save current config as 'z.ai' profile
  $0 list                 # List all profiles
  $0 switch z.ai          # Switch to z.ai profile
  $0 current              # Show current active profile

Notes:
  - Your original configuration is automatically backed up on first run
  - Each switch creates a timestamped backup
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

main "$@"

#!/usr/bin/env bash

# Claude Account Switcher - Uninstaller
# Usage: curl -fsSL https://raw.githubusercontent.com/rzkmak/claude-switch/main/uninstall.sh | bash

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
SCRIPT_NAME="claude-switch"
CLAUDE_DIR="$HOME/.claude"
PROFILES_DIR="$CLAUDE_DIR/profiles"
BACKUP_DIR="$CLAUDE_DIR/backups"

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

# Check if installed
check_installation() {
    if [[ ! -f "$INSTALL_DIR/$SCRIPT_NAME" ]]; then
        log_error "Claude Account Switcher is not installed"
        echo ""
        echo "Expected location: $INSTALL_DIR/$SCRIPT_NAME"
        exit 1
    fi
    
    log_info "Found installation at: $INSTALL_DIR/$SCRIPT_NAME"
}

# Get profile and backup info
get_data_info() {
    local profile_count=0
    local backup_count=0
    
    if [[ -d "$PROFILES_DIR" ]]; then
        profile_count=$(find "$PROFILES_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | xargs)
    fi
    
    if [[ -d "$BACKUP_DIR" ]]; then
        backup_count=$(find "$BACKUP_DIR" -type f -name "*.json" 2>/dev/null | wc -l | xargs)
    fi
    
    echo "$profile_count:$backup_count"
}

# Remove the script
remove_script() {
    if [[ -f "$INSTALL_DIR/$SCRIPT_NAME" ]]; then
        rm "$INSTALL_DIR/$SCRIPT_NAME"
        log_success "Removed script from: $INSTALL_DIR/$SCRIPT_NAME"
    fi
}

# Remove profiles
remove_profiles() {
    if [[ -d "$PROFILES_DIR" ]]; then
        local count=$(find "$PROFILES_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | xargs)
        rm -rf "$PROFILES_DIR"
        log_success "Removed $count profile(s)"
    fi
}

# Remove backups
remove_backups() {
    if [[ -d "$BACKUP_DIR" ]]; then
        local count=$(find "$BACKUP_DIR" -type f -name "*.json" 2>/dev/null | wc -l | xargs)
        rm -rf "$BACKUP_DIR"
        log_success "Removed $count backup(s)"
    fi
}

# Interactive uninstall
interactive_uninstall() {
    local data_info=$(get_data_info)
    local profile_count=$(echo "$data_info" | cut -d: -f1)
    local backup_count=$(echo "$data_info" | cut -d: -f2)
    
    echo ""
    log_warning "This will uninstall Claude Account Switcher"
    echo ""
    echo "Current data:"
    echo "  • Profiles: $profile_count"
    echo "  • Backups: $backup_count"
    echo ""
    
    # Ask about script removal
    read -p "Remove the claude-switch script? (y/n): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Uninstallation cancelled"
        exit 0
    fi
    
    local remove_data=false
    
    # Ask about data removal if there is any
    if [[ $profile_count -gt 0 || $backup_count -gt 0 ]]; then
        echo ""
        log_warning "Do you also want to remove your profiles and backups?"
        echo ""
        echo "  • This will delete all saved account profiles"
        echo "  • This will delete all configuration backups"
        echo "  • Your active Claude configuration (~/.claude.json) will NOT be touched"
        echo ""
        read -p "Remove profiles and backups? (y/n): " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            remove_data=true
        fi
    fi
    
    # Perform uninstallation
    echo ""
    log_info "Uninstalling..."
    echo ""
    
    remove_script
    
    if [[ $remove_data == true ]]; then
        remove_profiles
        remove_backups
    else
        log_info "Keeping profiles and backups"
        echo ""
        echo "  Profiles: $PROFILES_DIR"
        echo "  Backups: $BACKUP_DIR"
    fi
}

# Non-interactive uninstall
non_interactive_uninstall() {
    local keep_data="${KEEP_DATA:-true}"
    
    log_info "Running in non-interactive mode"
    echo ""
    
    remove_script
    
    if [[ "$keep_data" == "false" ]]; then
        remove_profiles
        remove_backups
    else
        log_info "Keeping profiles and backups (set KEEP_DATA=false to remove)"
    fi
}

# Show completion message
show_completion() {
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Uninstallation Complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Claude Account Switcher has been removed."
    echo ""
    
    if [[ -d "$PROFILES_DIR" || -d "$BACKUP_DIR" ]]; then
        echo "Your data is still available at:"
        if [[ -d "$PROFILES_DIR" ]]; then
            echo "  • Profiles: $PROFILES_DIR"
        fi
        if [[ -d "$BACKUP_DIR" ]]; then
            echo "  • Backups: $BACKUP_DIR"
        fi
        echo ""
        echo "To remove manually:"
        echo "  rm -rf ~/.claude/profiles ~/.claude/backups"
        echo ""
    fi
    
    echo "To reinstall:"
    echo "  curl -fsSL https://raw.githubusercontent.com/rzkmak/claude-switch/main/install.sh | bash"
    echo ""
}

# Main uninstall flow
main() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Claude Account Switcher - Uninstaller${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    check_installation
    
    # Check if running interactively
    if [[ -t 0 ]]; then
        interactive_uninstall
    else
        non_interactive_uninstall
    fi
    
    show_completion
}

main "$@"

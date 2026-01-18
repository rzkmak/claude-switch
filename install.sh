#!/usr/bin/env bash

# Claude Account Switcher - Self-Installing Script
# Usage: curl -fsSL https://raw.githubusercontent.com/rzkmak/claude-switch/main/install.sh | bash

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
REPO_URL="https://raw.githubusercontent.com/rzkmak/claude-switch/main"
VERSION_URL="$REPO_URL/VERSION"

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

# Get installed version
get_installed_version() {
    if [[ -f "$INSTALL_DIR/$SCRIPT_NAME" ]]; then
        # Try to extract version from script
        grep -m1 "^# Version:" "$INSTALL_DIR/$SCRIPT_NAME" 2>/dev/null | cut -d: -f2 | xargs || echo "unknown"
    else
        echo "none"
    fi
}

# Check if already installed
check_existing_installation() {
    if [[ -f "$INSTALL_DIR/$SCRIPT_NAME" ]]; then
        local installed_version=$(get_installed_version)
        log_warning "Claude Account Switcher is already installed"
        echo ""
        echo "  Installed version: $installed_version"
        echo "  Location: $INSTALL_DIR/$SCRIPT_NAME"
        echo ""
        
        # Non-interactive mode - always upgrade
        if [[ ! -t 0 ]]; then
            log_info "Running in non-interactive mode, upgrading..."
            return 0
        fi
        
        read -p "Do you want to upgrade/reinstall? (y/n): " -n 1 -r
        echo ""
        
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled"
            exit 0
        fi
        
        log_info "Upgrading installation..."
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Claude CLI is installed
    if ! command -v claude &> /dev/null; then
        log_warning "Claude CLI not found. Please install it first:"
        echo "  Visit: https://claude.ai/download"
        exit 1
    fi
    
    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        log_error "curl is required but not installed."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Create installation directory
setup_install_dir() {
    if [[ ! -d "$INSTALL_DIR" ]]; then
        log_info "Creating installation directory: $INSTALL_DIR"
        mkdir -p "$INSTALL_DIR"
    fi
}

# Download and install the script
install_script() {
    log_info "Downloading claude-switch.sh..."
    
    local temp_file=$(mktemp)
    
    if curl -fsSL "$REPO_URL/claude-switch.sh" -o "$temp_file"; then
        chmod +x "$temp_file"
        mv "$temp_file" "$INSTALL_DIR/$SCRIPT_NAME"
        log_success "Installed to: $INSTALL_DIR/$SCRIPT_NAME"
    else
        log_error "Failed to download script"
        rm -f "$temp_file"
        exit 1
    fi
}

# Check if install directory is in PATH
check_path() {
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        log_warning "Installation directory is not in your PATH"
        echo ""
        echo "Add this to your shell profile (~/.zshrc or ~/.bashrc):"
        echo ""
        echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
        echo ""
        echo "Or create an alias:"
        echo ""
        echo "  alias claude-switch=\"$INSTALL_DIR/$SCRIPT_NAME\""
        echo ""
    else
        log_success "Installation directory is in PATH"
    fi
}

# Show next steps
show_next_steps() {
    local installed_version=$(get_installed_version)
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Installation Complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [[ "$installed_version" != "none" && "$installed_version" != "unknown" ]]; then
        echo "Version: $installed_version"
        echo ""
    fi
    
    echo "Quick Start:"
    echo ""
    echo "  1. Save your current account:"
    echo "     $SCRIPT_NAME save anthropic"
    echo ""
    echo "  2. Login to your second account:"
    echo "     claude auth"
    echo ""
    echo "  3. Save your second account:"
    echo "     $SCRIPT_NAME save z.ai"
    echo ""
    echo "  4. Switch between accounts:"
    echo "     $SCRIPT_NAME switch anthropic"
    echo "     $SCRIPT_NAME switch z.ai"
    echo ""
    echo "For help:"
    echo "  $SCRIPT_NAME help"
    echo ""
    echo "Documentation:"
    echo "  https://github.com/rzkmak/claude-switch"
    echo ""
}

# Main installation flow
main() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Claude Account Switcher - Installer${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    check_existing_installation
    check_prerequisites
    setup_install_dir
    install_script
    check_path
    show_next_steps
}

main "$@"


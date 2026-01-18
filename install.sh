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

# Configure shell environment (PATH and Alias)
setup_shell_env() {
    local shell_rc=""
    local user_shell=$(basename "$SHELL")
    
    if [[ "$user_shell" == "zsh" ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ "$user_shell" == "bash" ]]; then
        shell_rc="$HOME/.bashrc"
    else
        log_warning "Unsupported shell: $user_shell. Manual configuration required."
        return
    fi
    
    if [[ ! -f "$shell_rc" ]]; then
        touch "$shell_rc"
    fi
    
    # 1. PATH setup
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        if ! grep -q "export PATH=.*$INSTALL_DIR" "$shell_rc"; then
            log_info "Adding $INSTALL_DIR to PATH in $shell_rc..."
            echo "" >> "$shell_rc"
            echo "# Claude Account Switcher" >> "$shell_rc"
            echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$shell_rc"
        fi
    fi
    
    # 2. Alias setup (csw)
    # Remove old function-based csw if exists
    if grep -q "csw() {" "$shell_rc"; then
        log_info "Removing old 'csw' function from $shell_rc..."
        # Create backup
        cp "$shell_rc" "$shell_rc.bak"
        # Remove the function block (from csw() { to the closing })
        sed '/^# Claude Account Switcher Function$/,/^}$/d' "$shell_rc.bak" > "$shell_rc"
    fi

    # Add alias if not exists
    if ! grep -q "alias csw=" "$shell_rc"; then
        log_info "Adding 'csw' alias to $shell_rc..."
        echo "" >> "$shell_rc"
        echo "# Claude Account Switcher" >> "$shell_rc"
        echo "alias csw='claude-switch'" >> "$shell_rc"
    fi
    
    log_success "Shell configuration updated."
    echo "To use 'csw' immediately, run:"
    echo ""
    echo "  source $shell_rc"
    echo ""
}

# Check installations
check_install() {
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        log_warning "Installation directory is not currently in PATH"
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
    echo "     csw save anthropic"
    echo ""
    echo "  2. Login to your second account:"
    echo "     claude"
    echo "     > /login"
    echo ""
    echo "  3. Save your second account:"
    echo "     csw save z.ai"
    echo ""
    echo "  4. Switch between accounts:"
    echo "     csw use anthropic"
    echo "     csw use z.ai"
    echo ""
    echo "For help:"
    echo "  csw help"
    echo ""
    echo "Documentation:"
    echo "  https://github.com/rzkmak/claude-switch"
    echo ""
    echo "Note: 'csw' is an alias for 'claude-switch'"
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
    setup_shell_env
    check_install
    show_next_steps
}

main "$@"


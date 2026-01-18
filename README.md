# Claude Account Switcher

**Easily switch between multiple Claude CLI subscription accounts (e.g., z.ai and Anthropic)**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> **⚠️ Platform Compatibility**: This tool is currently tested on macOS only. The keychain integration feature (for OAuth credential management) is macOS-specific and may not work on Windows or Linux. We welcome contributions from the community to add support for other platforms!

---

## ✨ Features

- 🔒 **Safe & Secure** - Automatic backup of original config
- 🚀 **One-Line Install** - Install with a single curl command
- 🔄 **Easy Switching** - Switch between accounts in seconds
- 🔗 **Auto-Sync** - Profiles utilize symlinks so tokens stay fresh automatically
- 📦 **Profile Management** - Save unlimited account profiles
- 🎨 **Beautiful CLI** - Color-coded output for better UX

---

## 🚀 Quick Start

### Installation

Install with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/rzkmak/claude-switch/main/install.sh | bash
```

This will install `claude-switch` to `~/.local/bin/` and make it available system-wide.

> **💡 Tip**: To upgrade to the latest version, simply run the same command again!

### Setup Your Accounts

### Setup Your Accounts

The easiest way to set up profiles is using the interactive `new` command:

```bash
# 1. Create your first profile (e.g., Anthropic)
csw new anthropic
# Follow the interactive prompts to log in

# 2. Create your second profile (e.g., z.ai)
csw new z.ai
# Follow the interactive prompts to set your API key
```

### Switch Between Accounts

```bash
csw use anthropic     # Use Anthropic
csw use z.ai          # Use z.ai
csw current           # Check active account
csw list              # List all accounts
```

---

## 📋 Commands

| Command | Description | Example |
|---------|-------------|---------|
| `new [name]` | Create a new profile interactively | `csw new anthropic` |
| `save <name>` | Save current config as profile | `csw save anthropic` |
| `use <name>` | Use a different profile | `csw use z.ai` |
| `list` | List all profiles | `csw list` |
| `current` | Show active profile | `csw current` |
| `delete <name>` | Delete a profile | `csw delete old-account` |
| `help` | Show help message | `csw help` |

---

## 📖 Detailed Setup Guide

### First-Time Setup

When you run the script for the first time, it will:
1. Automatically back up your current authentication to `~/.claude/backups/original-auth.json`
2. Automatically back up your environment settings to `~/.claude/backups/original-settings.json` (if exists)
3. Ask if you want to save it as a profile
4. Create the necessary directories

**Your original configuration is always safe and never overwritten!**

> **Note**: The script handles both:
> - `~/.claude.json` - Authentication tokens (from `claude` -> `/login`)
> - `~/.claude/settings.json` - Environment variables and model settings

### Configuring Multiple Accounts

### Configuring Multiple Accounts

Use the `new` command for a guided setup:

#### Example: Anthropic Account

```bash
csw new anthropic
```

Select "OAuth" when prompted, then follow the instructions to:
1. Run `claude` to open the interface
2. Use the `/login` command
3. Save the profile

#### Example: z.ai Account

```bash
csw new z.ai
```

Select "API Key" when prompted, then follow the instructions to:
1. Get your API key
2. Create `~/.claude/settings.json`
3. Save the profile

### Complete Workflow Example

```bash
# Create profiles interactively
csw new anthropic
csw new z.ai

# Switch between accounts anytime
csw use anthropic
csw use z.ai

# Check which account is active
csw current

# List all your accounts
csw list
```

---

## 🔧 Installation Options

### Quick Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/rzkmak/claude-switch/main/install.sh | bash
```

### Custom Installation Directory

```bash
INSTALL_DIR=/usr/local/bin curl -fsSL https://raw.githubusercontent.com/rzkmak/claude-switch/main/install.sh | bash
```

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/rzkmak/claude-switch.git
cd claude-switch

# Make executable
chmod +x claude-switch.sh

# Copy to PATH
cp claude-switch.sh ~/.local/bin/claude-switch
```

### Download Single File

```bash
curl -fsSL https://raw.githubusercontent.com/rzkmak/claude-switch/main/claude-switch.sh -o claude-switch
chmod +x claude-switch
mv claude-switch ~/.local/bin/
```

---

## 🔒 Safety Features

### Automatic Backups

✅ **Original Backup** - First run creates:
  - `~/.claude/backups/original-auth.json` (authentication)
  - `~/.claude/backups/original-settings.json` (environment settings, if exists)



✅ **Confirmation Prompts** - Asks before overwriting or deleting profiles  
✅ **Separate Storage** - Profiles stored in `~/.claude/profiles/<profile-name>/`  

### File Locations

- **Active Auth**: `~/.claude.json` (symlink to active profile)
- **Active Settings**: `~/.claude/settings.json` (symlink or missing)
- **Profiles**: `~/.claude/profiles/<profile-name>/`
  - `auth.json` - Authentication tokens
  - `settings.json` - Environment variables (optional)
- **Backups**: `~/.claude/backups/`

### Restore Original Configuration

```bash
# Restore authentication
cp ~/.claude/backups/original-auth.json ~/.claude.json

# Restore settings (if exists)
cp ~/.claude/backups/original-settings.json ~/.claude/settings.json
```

---

## 💡 Pro Tips

### Create an Alias

For even quicker access:

The installer automatically adds the `csw` alias:

```bash
# Added automatically to your shell config:
alias csw="claude-switch"

# Now you can use:
csw use z.ai
csw list
csw current
```

### Install jq for Better Output

```bash
brew install jq
```

With jq installed, the output will be prettier and more readable.

### Integration with Shell Prompt

Show current Claude account in your prompt:

```bash
# Add to ~/.zshrc
claude_account() {
  local profile=$(claude-switch current 2>/dev/null | grep "Current profile:" | cut -d: -f2 | xargs)
  if [[ -n "$profile" && "$profile" != "unknown" ]]; then
    echo "[$profile]"
  fi
}

# Add to your PROMPT
PROMPT='$(claude_account) %~ %# '
```

---

## 🐛 Troubleshooting

### "claude-switch: command not found"

Your `~/.local/bin` might not be in your PATH. Add it:

```bash
# For zsh (macOS default)
echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.zshrc
source ~/.zshrc

# For bash
echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc
source ~/.bashrc
```

Or create an alias:

```bash
echo 'alias csw="~/.local/bin/claude-switch"' >> ~/.zshrc
source ~/.zshrc
```

### "Claude CLI not found"

Install Claude CLI first:
- Visit: https://claude.ai/download
- Or use: `npm install -g @anthropic-ai/claude-cli`

### Permission Denied

Make sure the script is executable:

```bash
chmod +x ~/.local/bin/claude-switch
```

### Profile Not Switching

Verify file permissions:

```bash
ls -la ~/.claude/settings.json
# Should show: -rw-r--r--
```

### Still Being Asked to Login After Switching to API Key Profile

If you're still being prompted to log in after switching to an API key profile (like z.ai):

1. **Delete and recreate the profile** - This ensures a clean setup:
   ```bash
   csw delete z.ai
   csw new z.ai
   ```

2. **Verify the profile is active**:
   ```bash
   csw current
   # Should show your API key profile
   ```

3. **Check settings.json is symlinked correctly**:
   ```bash
   ls -la ~/.claude/settings.json
   # Should show a symlink to the profile's settings.json
   ```

The script now automatically creates a minimal `auth.json` for API key profiles to prevent Claude CLI from attempting OAuth authentication.

---

## 📦 Requirements

- **Claude CLI** - Must be installed and configured
- **bash** 4.0 or higher
- **curl** - For installation
- **jq** - Optional, for prettier output

---

## 🗑️ Uninstallation

### Quick Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/rzkmak/claude-switch/main/uninstall.sh | bash
```

This will:
- Remove the `claude-switch` script
- Ask if you want to keep or remove profiles and backups
- Never touch your active Claude configuration (`~/.claude.json`)

### Manual Uninstallation

```bash
# Remove the script
rm ~/.local/bin/claude-switch

# Optionally remove profiles and backups
rm -rf ~/.claude/profiles
rm -rf ~/.claude/backups
```

### Non-Interactive Uninstall

```bash
# Keep profiles and backups (default)
curl -fsSL https://raw.githubusercontent.com/rzkmak/claude-switch/main/uninstall.sh | bash

# Remove everything including profiles and backups
curl -fsSL https://raw.githubusercontent.com/rzkmak/claude-switch/main/uninstall.sh | KEEP_DATA=false bash
```

Your active Claude configuration at `~/.claude.json` and `~/.claude/settings.json` remains untouched.

---

## 🎯 Use Cases

Perfect for:
- Developers with multiple Claude subscriptions
- Teams sharing different Claude accounts
- Testing between different API endpoints
- Switching between production and development configs
- Managing personal and work accounts

---

## 🧪 Testing

The project includes a comprehensive unit test suite to ensure the script works correctly.

### Running Tests

Run all tests from the project root:

```bash
./tests/run_tests.sh
```

### Test Coverage

The test suite covers:
- **Profile Creation** - Testing save profile functionality
- **Profile Switching** - Testing profile switching and symlink creation
- **Profile Listing** - Testing profile listing commands
- **Profile Deletion** - Testing profile deletion
- **Current Profile Detection** - Testing detection of active profile
- **First-Time Setup** - Testing initial backup and setup
- **OAuth/API Key Detection** - Testing authentication type detection
- **Auth Token Clearing** - Testing OAuth token removal for API key profiles

### Test Isolation

All tests run in a sandboxed environment using temporary directories. Your actual Claude configuration files are never touched during testing.

---

## 🤝 Contributing

Issues and pull requests are welcome!

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

MIT License - See [LICENSE](LICENSE) for details

---

## 🙏 Support

If you find this useful, please ⭐ star the repo!

---

**Made with ❤️ for the Claude community**

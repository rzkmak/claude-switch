# Claude Account Switcher

**Easily switch between multiple Claude CLI subscription accounts (e.g., z.ai and Anthropic)**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## ✨ Features

- 🔒 **Safe & Secure** - Automatic backups, never lose your original config
- 🚀 **One-Line Install** - Install with a single curl command
- 🔄 **Easy Switching** - Switch between accounts in seconds
- 📦 **Profile Management** - Save unlimited account profiles
- 💾 **Timestamped Backups** - Every switch creates a backup
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

```bash
# 1. Save your current account (e.g., Anthropic)
claude-switch save anthropic

# 2. Configure Claude for your second account
# Edit ~/.claude/settings.json with your z.ai credentials

# 3. Save your second account
claude-switch save z.ai
```

### Switch Between Accounts

```bash
claude-switch switch anthropic  # Use Anthropic
claude-switch switch z.ai       # Use z.ai
claude-switch current           # Check active account
claude-switch list              # List all accounts
```

---

## 📋 Commands

| Command | Description | Example |
|---------|-------------|---------|
| `save <name>` | Save current config as profile | `claude-switch save anthropic` |
| `switch <name>` | Switch to a profile | `claude-switch switch z.ai` |
| `list` | List all profiles | `claude-switch list` |
| `current` | Show active profile | `claude-switch current` |
| `delete <name>` | Delete a profile | `claude-switch delete old-account` |
| `help` | Show help message | `claude-switch help` |

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
> - `~/.claude.json` - Authentication tokens (from `claude auth`)
> - `~/.claude/settings.json` - Environment variables and model settings

### Configuring Multiple Accounts

#### Example: Anthropic Account

Your current settings might look like this:

```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "your-anthropic-token",
    "ANTHROPIC_BASE_URL": "https://api.anthropic.com",
    "API_TIMEOUT_MS": "3000000",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-3-haiku-20240307",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-3-5-sonnet-20241022",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-3-opus-20240229"
  },
  "model": "opus"
}
```

Save this as a profile:
```bash
claude-switch save anthropic
```

#### Example: z.ai Account

Edit `~/.claude/settings.json` for your z.ai account:

```bash
nano ~/.claude/settings.json
# or
code ~/.claude/settings.json
```

Update with your z.ai credentials:

```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "your-z-ai-token",
    "ANTHROPIC_BASE_URL": "https://z.ai/api/v1",
    "API_TIMEOUT_MS": "3000000",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-3-haiku-20240307",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-3-5-sonnet-20241022",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-3-opus-20240229"
  },
  "model": "sonnet"
}
```

Save this as a profile:
```bash
claude-switch save z.ai
```

### Complete Workflow Example

```bash
# Save current account
claude-switch save anthropic

# Configure for second account, then save
claude-switch save z.ai

# Switch between accounts anytime
claude-switch switch anthropic
claude-switch switch z.ai

# Check which account is active
claude-switch current

# List all your accounts
claude-switch list
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

✅ **Timestamped Backups** - Every switch creates:
  - `auth-YYYYMMDD_HHMMSS.json`
  - `settings-YYYYMMDD_HHMMSS.json`

✅ **Confirmation Prompts** - Asks before overwriting or deleting profiles  
✅ **Separate Storage** - Profiles stored in `~/.claude/profiles/<profile-name>/`  

### File Locations

- **Active Auth**: `~/.claude.json`
- **Active Settings**: `~/.claude/settings.json`
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

```bash
# Add to ~/.zshrc or ~/.bashrc
echo 'alias cs="claude-switch"' >> ~/.zshrc
source ~/.zshrc

# Now you can use:
cs switch z.ai
cs list
cs current
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
echo 'alias claude-switch="~/.local/bin/claude-switch"' >> ~/.zshrc
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

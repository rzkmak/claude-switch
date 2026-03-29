# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a bash-based CLI tool for switching between multiple Claude CLI subscription accounts (e.g., Anthropic, z.ai, OpenRouter, DeepSeek, Kimi). It uses a profile-based architecture with symlinks to manage authentication and settings.

## Architecture

### Core Design

- **Single-script architecture**: All functionality is in `claude-switch.sh` (~1070 lines)
- **Profile-based storage**: Each profile is a directory under `~/.claude/profiles/<name>/`
- **Symlink-based activation**: Active profile files are symlinks from `~/.claude.json` and `~/.claude/settings.json` to the profile directory
- **macOS keychain integration**: OAuth credentials are backed up/restored from macOS keychain (service: "Claude Code-credentials", account: "user")

### Authentication Types

1. **OAuth (Anthropic)**: Uses `~/.claude.json` symlink, no settings.json, keychain credentials restored from `keychain-credentials.b64`
2. **API Key (z.ai, etc.)**: Uses `~/.claude.json` (minimal auth) + `~/.claude/settings.json` (symlink), keychain credentials deleted to prevent conflicts

### File Structure

```
~/.claude/
├── profiles/
│   └── <profile-name>/
│       ├── auth.json          # Authentication data
│       ├── settings.json      # API key config (API profiles only)
│       └── keychain-credentials.b64  # OAuth tokens (OAuth profiles only)
└── backups/
    ├── original-auth.json     # First-run backup
    └── original-settings.json
```

### Key Functions

- `create_profile()` - Interactive profile creation (lines 764-895)
- `switch_profile()` - Symlink switching with keychain management (lines 500-641)
- `save_profile()` - Copy current config to profile (lines 270-497)
- `backup_keychain_to_profile()` / `restore_keychain_from_profile()` - macOS keychain sync

## Development Commands

### Testing

Run all tests:
```bash
./tests/run_tests.sh
```

Run a single test (by pattern):
```bash
./tests/run_tests.sh -f "test_profile_creation"
```

The test suite uses bash-bats (built into the test file) and runs in a sandboxed temp directory.

### Installation/Testing Locally

Install from local clone:
```bash
./install.sh
```

The script installs to `~/.local/bin/` and creates a `csw` alias in shell config.

### Version Bump

Update the version string in:
- `claude-switch.sh` (line 5): `# Version: X.Y.Z`

## Platform Notes

- **macOS only**: Keychain integration is macOS-specific
- **jq optional**: Used for prettier output and JSON manipulation; gracefully degrades without it
- **Claude CLI dependency**: Requires `claude` CLI to be installed for OAuth login flow

## Common Commands Reference

| Command | Description |
|---------|-------------|
| `csw new` | Create profile interactively |
| `csw use <name>` | Switch to profile |
| `csw list` | List all profiles |
| `csw current` | Show active profile |
| `csw save <name>` | Save current config as profile |
| `csw delete <name>` | Delete a profile |

## Testing Notes

- Tests run in isolated temp directories and do not touch real Claude config
- Tests mock the `security` keychain command
- Tests require bash 4.0+ but do not require jq

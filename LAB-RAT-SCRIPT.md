# Lab Rat Script

## Overview

**ONE SCRIPT TO RULE THEM ALL!** 🔬

The lab rat functionality has been simplified into a single smart script: `lab-rat.sh`

## The Script: `lab-rat.sh` 🔬

This script will:

1. **Checks if labrat user exists**
   - If **NO**: Creates the user as admin with Homebrew and Ansible
   - If **YES**: Wipes it clean by removing all playbook installations

2. **Smart Cleanup** (when user exists):
   - Removes Nix installation completely (system-wide)
   - Cleans all user Nix configurations and caches
   - Removes cloned repositories (`~/nix-setup-ansible`)
   - Resets shell configuration to clean state
   - Optionally cleans Homebrew packages (preserves Homebrew & Ansible)
   - Clears external logs

3. **Smart Creation** (when user missing):
   - Creates labrat user with admin privileges
   - Installs Homebrew (macOS) or updates package manager (Linux)
   - Installs Ansible and required collections
   - Sets up clean shell environment

## Usage

### Simple Workflow

```bash
# See what would be done first (recommended)
sudo ./lab-rat.sh --dry-run

# Always run this before testing - it does the right thing automatically
sudo ./lab-rat.sh

# Then run your test
sudo -u labrat bash -c 'cd && ./bootstrap-macos.sh <repo-url>'
```

### Command Options

```bash
# Dry run - see what would be done without making changes
sudo ./lab-rat.sh --dry-run
# or
sudo ./lab-rat.sh -n

# Show help
./lab-rat.sh --help
# or  
./lab-rat.sh -h

# Run normally
sudo ./lab-rat.sh
```

### What It Does

- **First time**: Creates user, installs tools
- **Subsequent times**: Cleans up previous installations
- **Always**: Ensures you have a clean testing environment

## Benefits

- ✅ **One Script**: No more confusion about which script to use
- ✅ **Intelligent**: Automatically detects what needs to be done
- ✅ **Fast**: No unnecessary user recreation
- ✅ **Clean**: Complete removal of all installations
- ✅ **Reliable**: Handles both macOS and Linux
- ✅ **Simple**: Just run it every time before testing
- ✅ **Safe**: Dry run mode to preview changes before execution

## What Gets Cleaned (when user exists)

- ✅ Complete Nix installation and configurations
- ✅ User's Nix profiles, caches, and state
- ✅ Cloned repositories
- ✅ Bootstrap completion markers and logs
- ✅ Shell configuration (reset to clean state with Homebrew support)
- ✅ External logs
- ⚪ Homebrew packages (optional, preserves Homebrew & Ansible)

## What Gets Preserved

- ✅ User account and home directory
- ✅ User permissions and admin status  
- ✅ Homebrew installation and Ansible
- ✅ Basic system settings

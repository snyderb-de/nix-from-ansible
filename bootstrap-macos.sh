#!/bin/bash

set -e

# Parse command line arguments
DRY_RUN=false
REPO_URL=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run|-n)
      DRY_RUN=true
      shift
      ;;
    --help|-h)
      echo "🍎 Bootstrap macOS - Nix Development Environment Setup"
      echo "===================================================="
      echo ""
      echo "Usage: $0 [OPTIONS] <git-repo-url>"
      echo ""
      echo "Options:"
      echo "  --dry-run, -n    Show what would be done without making changes"
      echo "  --help, -h       Show this help message"
      echo ""
      echo "Description:"
      echo "  Sets up a complete Nix development environment by:"
      echo "  • Installing Xcode Command Line Tools"
      echo "  • Installing Homebrew package manager"
      echo "  • Installing Ansible automation tool"
      echo "  • Cloning the nix-setup-ansible repository"
      echo "  • Running the Ansible playbook to install Nix"
      echo ""
      echo "Examples:"
      echo "  $0 https://github.com/user/nix-setup-ansible.git"
      echo "  $0 --dry-run https://github.com/user/nix-setup-ansible.git"
      echo ""
      exit 0
      ;;
    -*)
      echo "❌ Unknown option: $1"
      echo "💡 Use --help for usage information"
      exit 1
      ;;
    *)
      REPO_URL="$1"
      shift
      ;;
  esac
done

# Prevent Homebrew from upgrading or cleaning anything automatically
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

# Prevent DS_Store files on network shares
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool TRUE

# Enhanced logging function
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

REPO_URL="$1"
mkdir -p "$HOME/.config"
LOGFILE="$HOME/.config/bootstrap.log"

if [[ -z "$REPO_URL" ]]; then
  echo "❌ Missing required argument: git-repo-url"
  log "📦 Usage: $0 [OPTIONS] <git-repo-url>"
  echo "💡 Use --help for more information"
  exit 1
fi

if [ "$DRY_RUN" = true ]; then
  echo "🔍 DRY RUN MODE - No changes will be made"
  echo "========================================"
fi

# Helper function for dry run output
dry_run_msg() {
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY RUN] Would: $1"
    else
        echo "  $1"
    fi
}

# Helper function to conditionally execute commands
maybe_exec() {
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY RUN] Would execute: $1"
    else
        eval "$1"
    fi
}

# Helper function for command checks in dry run
check_command() {
    local cmd="$1"
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY RUN] Would check if '$cmd' is installed"
        return 1  # Assume not installed for dry run demo
    else
        command -v "$cmd" &>/dev/null
    fi
}

# Exit if bootstrap has already been completed
if [[ -f "$HOME/.bootstrap_complete" ]]; then
  if [ "$DRY_RUN" = true ]; then
    echo "🔍 Found existing bootstrap marker - would normally exit here"
    echo "🔍 Continuing dry run to show what would happen on fresh system..."
  else
    log "🛑 Bootstrap already completed. Exiting."
    exit 0
  fi
fi

if [ "$DRY_RUN" = false ]; then
  exec > >(tee -a "$LOGFILE") 2>&1
else
  echo "🔍 Dry run - output would be logged to: $LOGFILE"
fi

# Check which shell is being used
SHELL_NAME=$(basename "$SHELL")
if [[ "$SHELL_NAME" != "zsh" ]]; then
  log "⚠️ Warning: You're not using zsh (current: $SHELL_NAME). Some features may not work as expected."
fi

# Check internet connectivity before proceeding
log "🌐 Checking internet connectivity..."
if ! ping -c 1 github.com &>/dev/null; then
  log "❌ No internet connection. Please connect and try again."
  exit 1
fi

# Ensure sufficient disk space (5GB minimum)
log "💾 Checking available disk space..."
if [[ $(df -k / | awk 'NR==2 {print $4}') -lt 5242880 ]]; then
  log "❌ Insufficient disk space. At least 5GB free space required."
  exit 1
fi

# Ensure Xcode Command Line Tools are installed
if [ "$DRY_RUN" = true ] || ! xcode-select -p &>/dev/null; then
  if [ "$DRY_RUN" = true ]; then
    echo "🛠️ [DRY RUN] Would install Xcode Command Line Tools..."
    echo "  [DRY RUN] Would execute: xcode-select --install"
    echo "  [DRY RUN] Would wait for installation to complete"
  else
    log "🛠️ Installing Xcode Command Line Tools..."
    xcode-select --install

    log "⏳ Waiting for Xcode Command Line Tools to finish installing..."
    until xcode-select -p &>/dev/null; do
      sleep 5
    done
  fi
else
  echo "✅ Xcode Command Line Tools already installed"
fi

# Install Homebrew
log "🍺 Installing Homebrew..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Backup user configuration files before modifying
if [[ -f ~/.zprofile ]]; then
  log "📑 Backing up existing .zprofile..."
  cp ~/.zprofile ~/.zprofile.backup."$(date +%Y%m%d%H%M%S)"
fi

# Add Homebrew to shell environment
log "➕ Adding Homebrew to shell..."
if [[ -d /opt/homebrew ]]; then
  echo "eval \"\$(/opt/homebrew/bin/brew shellenv)\"" >> ~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "eval \"\$(/usr/local/bin/brew shellenv)\"" >> ~/.zprofile
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Install Ghostty Terminal if not installed
log "🖥️ Checking for Ghostty terminal..."
if ! brew list --cask ghostty &>/dev/null; then
  log "📥 Installing Ghostty terminal..."
  brew install --cask ghostty
else
  log "✅ Ghostty terminal already installed."
fi

# Install Lazygit if not installed
log "🔄 Checking for Lazygit..."
if ! brew list lazygit &>/dev/null; then
  log "📥 Installing Lazygit..."
  brew install lazygit
else
  log "✅ Lazygit already installed."
fi

# Install Lazygit if not installed
log "🔄 Checking for Lazygit..."
if ! brew list lazygit &>/dev/null; then
  log "📥 Installing Lazygit..."
  brew install lazygit
else
  log "✅ Lazygit already installed."
fi

# Install PowerShell if not installed
log "🔄 Checking for PowerShell..."
if ! brew list --cask powershell &>/dev/null; then
  log "📥 Installing PowerShell..."
  brew install --cask powershell
else
  log "✅ PowerShell already installed."
fi


# Check and install Ansible if needed
log "🔄 Checking for Ansible..."
if ! command -v ansible &>/dev/null; then
  log "📥 Installing Ansible..."
  brew install ansible
else
  log "✅ Ansible already installed."
fi

# Check and install required Ansible Galaxy collection if needed
log "🔄 Checking for required Ansible Galaxy collections..."
if ! ansible-galaxy collection list | grep -q "community.general"; then
  log "📥 Installing required Ansible Galaxy collections..."
  ansible-galaxy collection install community.general
else
  log "✅ Ansible Galaxy collection community.general already installed."
fi

# Clone the repo
log "📥 Cloning repo from $REPO_URL..."
if [ -d "$HOME/nix-setup-ansible" ]; then
  log "🔄 Repo already exists, pulling latest..."
  cd ~/nix-setup-ansible && git pull
else
  git clone "$REPO_URL" ~/nix-setup-ansible
  cd ~/nix-setup-ansible
fi

# Ask user before running the playbook
read -p "🤔 Run the Ansible playbook now? (Y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ -n $REPLY ]]; then
  log "❌ Exiting without running the playbook. You can run it manually later."
  exit 0
fi

# Run the Ansible playbook
log "▶️ Running Ansible playbook..."
ansible-playbook -i inventory playbook.yml --ask-become-pass

# Mark bootstrap as completed
if [ "$DRY_RUN" = false ]; then
  touch "$HOME/.bootstrap_complete"
  log "✅ Bootstrap complete! Output logged to $LOGFILE"
else
  echo "  [DRY RUN] Would create completion marker: ~/.bootstrap_complete"
  echo ""
  echo "🔍 DRY RUN COMPLETE - No changes were made"
  echo "💡 To actually run: $0 $REPO_URL"
  echo "💡 All output would be logged to: $LOGFILE"
fi
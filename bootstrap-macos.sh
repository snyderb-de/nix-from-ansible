#!/bin/bash

set -e

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
  log "📦 Usage: $0 <git-repo-url>"
  exit 1
fi

# Exit if bootstrap has already been completed
if [[ -f "$HOME/.bootstrap_complete" ]]; then
  log "🛑 Bootstrap already completed. Exiting."
  exit 0
fi

exec > >(tee -a "$LOGFILE") 2>&1

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
if ! xcode-select -p &>/dev/null; then
  log "🛠️ Installing Xcode Command Line Tools..."
  xcode-select --install

  log "⏳ Waiting for Xcode Command Line Tools to finish installing..."
  until xcode-select -p &>/dev/null; do
    sleep 5
  done
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
touch "$HOME/.bootstrap_complete"

log "✅ Bootstrap complete! Output logged to $LOGFILE"
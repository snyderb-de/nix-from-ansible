#!/bin/bash

set -e

# Prevent Homebrew from upgrading or cleaning anything automatically
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

# Prevent DS_Store files on network shares
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool TRUE

REPO_URL="$1"
mkdir -p "$HOME/.config"
LOGFILE="$HOME/.config/bootstrap.log"

if [[ -z "$REPO_URL" ]]; then
  echo "📦 Usage: $0 <git-repo-url>"
  exit 1
fi

# Exit if bootstrap has already been completed
if [[ -f "$HOME/.bootstrap_complete" ]]; then
  echo "🛑 Bootstrap already completed. Exiting."
  exit 0
fi

exec > >(tee -a "$LOGFILE") 2>&1

# Ensure Xcode Command Line Tools are installed
if ! xcode-select -p &>/dev/null; then
  echo "🛠️ Installing Xcode Command Line Tools..."
  xcode-select --install

  echo "⏳ Waiting for Xcode Command Line Tools to finish installing..."
  until xcode-select -p &>/dev/null; do
    sleep 5
  done
fi

# Install Homebrew
echo "🍺 Installing Homebrew..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to shell environment
echo "➕ Adding Homebrew to shell..."
if [[ -d /opt/homebrew ]]; then
  echo "eval \"\$(/opt/homebrew/bin/brew shellenv)\"" >> ~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "eval \"\$(/usr/local/bin/brew shellenv)\"" >> ~/.zprofile
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Install Ghostty Terminal if not installed
echo "🖥️ Checking for Ghostty terminal..."
if ! brew list --cask ghostty &>/dev/null; then
  echo "📥 Installing Ghostty terminal..."
  brew install --cask ghostty
else
  echo "✅ Ghostty terminal already installed."
fi

# Install Lazygit if not installed
echo "🔄 Checking for Lazygit..."
if ! brew list lazygit &>/dev/null; then
  echo "📥 Installing Lazygit..."
  brew install lazygit
else
  echo "✅ Lazygit already installed."
fi

# Check and install Ansible if needed
echo "🔄 Checking for Ansible..."
if ! command -v ansible &>/dev/null; then
  echo "📥 Installing Ansible..."
  brew install ansible
else
  echo "✅ Ansible already installed."
fi

# Check and install required Ansible Galaxy collection if needed
echo "🔄 Checking for required Ansible Galaxy collections..."
if ! ansible-galaxy collection list | grep -q "community.general"; then
  echo "📥 Installing required Ansible Galaxy collections..."
  ansible-galaxy collection install community.general
else
  echo "✅ Ansible Galaxy collection community.general already installed."
fi

# Clone the repo
echo "📥 Cloning repo from $REPO_URL..."
if [ -d "$HOME/nix-setup-ansible" ]; then
  echo "🔄 Repo already exists, pulling latest..."
  cd ~/nix-setup-ansible && git pull
else
  git clone "$REPO_URL" ~/nix-setup-ansible
  cd ~/nix-setup-ansible
fi

# Ask user before running the playbook
read -p "🤔 Run the Ansible playbook now? (Y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! -z $REPLY ]]; then
  echo "❌ Exiting without running the playbook. You can run it manually later."
  exit 0
fi

# Run the Ansible playbook
echo "▶️ Running Ansible playbook..."
ansible-playbook -i inventory playbook.yml --ask-become-pass


# Mark bootstrap as completed
touch "$HOME/.bootstrap_complete"

echo "✅ Bootstrap complete! Output logged to $LOGFILE"
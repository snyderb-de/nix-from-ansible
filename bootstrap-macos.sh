#!/bin/bash

set -e

# Prevent Homebrew from upgrading or cleaning anything automatically
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

REPO_URL="$1"
LOGFILE="$HOME/bootstrap.log"

if [[ -z "$REPO_URL" ]]; then
  echo "Usage: $0 <git-repo-url>"
  exit 1
fi

exec > >(tee -a "$LOGFILE") 2>&1

# Step 0: Ensure Xcode Command Line Tools are installed
if ! xcode-select -p &>/dev/null; then
  echo ">>> Installing Xcode Command Line Tools..."
  xcode-select --install

  echo ">>> Waiting for Xcode Command Line Tools to finish installing..."
  until xcode-select -p &>/dev/null; do
    sleep 5
  done
fi

# Step 1: Install Homebrew
echo ">>> Installing Homebrew..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Step 2: Add Homebrew to shell environment
echo ">>> Adding Homebrew to shell..."
if [[ -d /opt/homebrew ]]; then
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Step 3: Install Ansible
echo ">>> Installing Ansible..."
brew install ansible

# Step 4: Install required Ansible Galaxy collection
echo ">>> Installing required Ansible collections..."
ansible-galaxy collection install community.general

# Step 5: Clone the repo
echo ">>> Cloning repo from $REPO_URL..."
if [ -d "$HOME/nix-setup-ansible" ]; then
  echo ">>> Repo already exists, pulling latest..."
  cd ~/nix-setup-ansible && git pull
else
  git clone "$REPO_URL" ~/nix-setup-ansible
  cd ~/nix-setup-ansible
fi

# Step 6: Run the Ansible playbook
echo ">>> Running Ansible playbook..."
ansible-playbook -i inventory playbook.yml

echo "✅ Done. Output logged to $LOGFILE"

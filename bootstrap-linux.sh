#!/bin/bash

set -e

REPO_URL="$1"
LOGFILE="$HOME/bootstrap.log"

if [[ -z "$REPO_URL" ]]; then
  echo "Usage: $0 <git-repo-url>"
  exit 1
fi

exec > >(tee -a "$LOGFILE") 2>&1

# Step 1: Handle NixOS separately
if [[ -f /etc/NIXOS ]]; then
  echo ">>> NixOS detected."
  echo ">>> Please make sure the following packages are declared in your configuration.nix:"
  echo "    environment.systemPackages = with pkgs; [ git curl ansible ];"
  echo ">>> Then run: sudo nixos-rebuild switch"
  echo ">>> Skipping package installation..."
else
  echo ">>> Detecting package manager..."

  if command -v apt &> /dev/null; then
    PKG_MANAGER="apt"
    INSTALL_CMD="sudo apt update && sudo apt install -y ansible git curl"
  elif command -v dnf &> /dev/null; then
    PKG_MANAGER="dnf"
    INSTALL_CMD="sudo dnf install -y ansible git curl"
  elif command -v pacman &> /dev/null; then
    PKG_MANAGER="pacman"
    INSTALL_CMD="sudo pacman -Sy --noconfirm ansible git curl"
  elif command -v zypper &> /dev/null; then
    PKG_MANAGER="zypper"
    INSTALL_CMD="sudo zypper install -y ansible git curl"
  else
    echo "❌ Unsupported package manager. Please install ansible, git, and curl manually."
    exit 1
  fi

  echo ">>> Using $PKG_MANAGER to install Ansible, Git, and Curl..."
  eval "$INSTALL_CMD"
fi

# Step 2: Install Ansible Galaxy collection
echo ">>> Installing required Ansible Galaxy collections..."
ansible-galaxy collection install community.general

# Step 3: Clone or update the repo
echo ">>> Cloning repo from $REPO_URL..."
if [ -d "$HOME/nix-setup-ansible" ]; then
  echo ">>> Repo already exists, pulling latest..."
  cd ~/nix-setup-ansible && git pull
else
  git clone "$REPO_URL" ~/nix-setup-ansible
  cd ~/nix-setup-ansible
fi

# Step 4: Run playbook
echo ">>> Running Ansible playbook..."
ansible-playbook -i inventory playbook.yml --ask-become-pass

echo "✅ Done. Output logged to $LOGFILE"

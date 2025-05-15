#!/bin/bash

set -e

REPO_URL="$1"
LOGFILE="$HOME/bootstrap.log"

if [[ -z "$REPO_URL" ]]; then
  echo "Usage: $0 <git-repo-url>"
  exit 1
fi

exec > >(tee -a "$LOGFILE") 2>&1

# Detect package manager
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

echo ">>> Detected package manager: $PKG_MANAGER"
echo ">>> Installing Ansible, Git, and Curl..."
eval "$INSTALL_CMD"

echo ">>> Installing required Ansible collections..."
ansible-galaxy collection install community.general

echo ">>> Cloning repo from $REPO_URL..."
git clone "$REPO_URL" ~/nix-setup-ansible || {
  echo "Repo already exists, pulling latest..."
  cd ~/nix-setup-ansible && git pull
}

cd ~/nix-setup-ansible

echo ">>> Running Ansible playbook..."
ansible-playbook -i inventory playbook.yml

echo "✅ Done. Output logged to $LOGFILE"

#!/bin/bash

set -e

REPO_URL="$1"
LOGFILE="$HOME/bootstrap.log"

if [[ -z "$REPO_URL" ]]; then
  echo "Usage: $0 <git-repo-url>"
  exit 1
fi

exec > >(tee -a "$LOGFILE") 2>&1

echo ">>> Installing Homebrew..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

echo ">>> Adding Homebrew to shell..."
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

echo ">>> Installing Ansible..."
brew install ansible

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

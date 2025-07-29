#!/bin/bash

set -e

# Enhanced logging function
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

# Add command line flags for non-interactive mode
INTERACTIVE=true
while getopts "y" opt; do
  case $opt in
    y) INTERACTIVE=false ;;
    *) echo "Invalid option: -$OPTARG" >&2
       echo "Usage: $0 [-y] <git-repo-url>" >&2
       exit 1 ;;
  esac
done
shift $((OPTIND-1))

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

# Check internet connectivity before proceeding
log "🌐 Checking internet connectivity..."
if ! ping -c 1 github.com &>/dev/null; then
  log "❌ No internet connection. Please connect and try again."
  exit 1
fi

# Check disk space (2GB minimum)
log "💾 Checking available disk space..."
if [[ $(df -k / | awk 'NR==2 {print $4}') -lt 2097152 ]]; then
  log "❌ Insufficient disk space. At least 2GB free space required."
  exit 1
fi

# Step 1: Handle NixOS separately
if [[ -f /etc/NIXOS ]]; then
  log "🔍 NixOS detected."
  log "ℹ️ Please make sure the following packages are declared in your configuration.nix:"
  log "   environment.systemPackages = with pkgs; [ git curl ansible ];"
  log "🔄 Then run: sudo nixos-rebuild switch"
  log "⏩ Skipping package installation..."
else
  log "🔍 Detecting package manager..."

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
    log "❌ Unsupported package manager. Please install ansible, git, and curl manually."
    exit 1
  fi

  log "📦 Using $PKG_MANAGER to install Ansible, Git, and Curl..."
  eval "$INSTALL_CMD"
fi

# Backup user configuration files before modifying
if [[ -f ~/.bashrc ]]; then
  log "📑 Backing up existing .bashrc..."
  cp ~/.bashrc ~/.bashrc.backup."$(date +%Y%m%d%H%M%S)"
fi

if [[ -f ~/.zshrc ]]; then
  log "📑 Backing up existing .zshrc..."
  cp ~/.zshrc ~/.zshrc.backup."$(date +%Y%m%d%H%M%S)"
fi

# Check for Ansible
log "🔄 Checking for Ansible..."
if ! command -v ansible &>/dev/null; then
  log "❌ Ansible not found. Please install it manually."
  exit 1
else
  log "✅ Ansible is installed."
fi

# Step 2: Install Ansible Galaxy collection
log "🌍 Installing required Ansible Galaxy collections..."
if ! ansible-galaxy collection list | grep -q "community.general"; then
  ansible-galaxy collection install community.general
else
  log "✅ Ansible Galaxy collection community.general already installed."
fi

# Step 3: Clone or update the repo
log "📥 Cloning repo from $REPO_URL..."
if [ -d "$HOME/nix-setup-ansible" ]; then
  log "🔄 Repo already exists, pulling latest..."
  cd ~/nix-setup-ansible && git pull
else
  git clone "$REPO_URL" ~/nix-setup-ansible
  cd ~/nix-setup-ansible
fi

# Ask user before running the playbook
if $INTERACTIVE; then
  read -p "🤔 Run the Ansible playbook now? (Y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ -n $REPLY ]]; then
    log "❌ Exiting without running the playbook. You can run it manually later."
    exit 0
  fi
else
  log "🔄 Running in non-interactive mode, continuing automatically..."
fi

# Step 4: Run playbook
log "▶️ Running Ansible playbook..."
ansible-playbook -i inventory playbook.yml --ask-become-pass

# Mark bootstrap as completed
touch "$HOME/.bootstrap_complete"

log "✅ Done. Output logged to $LOGFILE"
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

mkdir -p "$HOME/.config"
LOGFILE="$HOME/.config/bootstrap.log"

if [[ -z "$REPO_URL" ]]; then
  echo "❌ Missing required argument: git-repo-url"
  echo "📦 Usage: $0 [OPTIONS] <git-repo-url>"
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
    echo "🛑 Bootstrap already completed. Exiting."
    exit 0
  fi
fi

if [ "$DRY_RUN" = false ]; then
  exec > >(tee -a "$LOGFILE") 2>&1
else
  echo "🔍 Dry run - output would be logged to: $LOGFILE"
fi

# Step 0: Ensure Xcode Command Line Tools are installed
if [ "$DRY_RUN" = true ] || ! xcode-select -p &>/dev/null; then
  if [ "$DRY_RUN" = true ]; then
    echo "🛠️ [DRY RUN] Would install Xcode Command Line Tools..."
    echo "  [DRY RUN] Would execute: xcode-select --install"
    echo "  [DRY RUN] Would wait for installation to complete"
  else
    echo "🛠️ Installing Xcode Command Line Tools..."
    xcode-select --install

    echo "⏳ Waiting for Xcode Command Line Tools to finish installing..."
    until xcode-select -p &>/dev/null; do
      sleep 5
    done
  fi
else
  echo "✅ Xcode Command Line Tools already installed"
fi

# Step 1: Install Homebrew
if ! check_command brew; then
  dry_run_msg "Installing Homebrew..."
  if [ "$DRY_RUN" = false ]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    echo "  [DRY RUN] Would download and run: curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
  fi
else
  echo "✅ Homebrew already installed"
fi

# Step 2: Add Homebrew to shell environment
dry_run_msg "Adding Homebrew to shell..."
if [ "$DRY_RUN" = false ]; then
  if [[ -d /opt/homebrew ]]; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/usr/local/bin/brew shellenv)"
  fi
else
  echo "  [DRY RUN] Would add Homebrew to ~/.zprofile and current shell environment"
  if [[ -d /opt/homebrew ]] || [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would add: eval \"\$(/opt/homebrew/bin/brew shellenv)\""
  else
    echo "  [DRY RUN] Would add: eval \"\$(/usr/local/bin/brew shellenv)\""
  fi
fi

# Step 3: Install Ansible
if ! check_command ansible; then
  dry_run_msg "Installing Ansible..."
  maybe_exec "brew install ansible"
else
  echo "✅ Ansible already installed"
fi

# Step 4: Install required Ansible Galaxy collection
dry_run_msg "Installing required Ansible Galaxy collections..."
maybe_exec "ansible-galaxy collection install community.general"

# Step 5: Clone the repo
dry_run_msg "Cloning repo from $REPO_URL..."
if [ "$DRY_RUN" = false ]; then
  if [ -d "$HOME/nix-setup-ansible" ]; then
    echo "🔄 Repo already exists, pulling latest..."
    cd ~/nix-setup-ansible && git pull
  else
    git clone "$REPO_URL" ~/nix-setup-ansible
    cd ~/nix-setup-ansible
  fi
else
  if [ -d "$HOME/nix-setup-ansible" ]; then
    echo "  [DRY RUN] Would update existing repo: cd ~/nix-setup-ansible && git pull"
  else
    echo "  [DRY RUN] Would clone: git clone $REPO_URL ~/nix-setup-ansible"
  fi
  echo "  [DRY RUN] Would change to: ~/nix-setup-ansible"
fi

# Step 6: Run the Ansible playbook
dry_run_msg "Running Ansible playbook..."
if [ "$DRY_RUN" = false ]; then
  ansible-playbook -i inventory playbook.yml --ask-become-pass
else
  echo "  [DRY RUN] Would execute: ansible-playbook -i inventory playbook.yml --ask-become-pass"
  echo "  [DRY RUN] This would:"
  echo "    - Install Nix package manager"
  echo "    - Configure Nix settings and channels"
  echo "    - Set up development tools"
  echo "    - Configure shell environment"
fi

# Mark bootstrap as completed
if [ "$DRY_RUN" = false ]; then
  touch "$HOME/.bootstrap_complete"
  echo "✅ Bootstrap complete! Output logged to $LOGFILE"
else
  echo "  [DRY RUN] Would create completion marker: ~/.bootstrap_complete"
  echo ""
  echo "🔍 DRY RUN COMPLETE - No changes were made"
  echo "💡 To actually run: $0 $REPO_URL"
  echo "💡 All output would be logged to: $LOGFILE"
fi
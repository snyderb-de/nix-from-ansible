#!/bin/bash

set -e

# Parse command line arguments
DRY_RUN=false
REPO_URL=""
SKIP_REPO=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run|-n)
      DRY_RUN=true
      shift
      ;;
    --skip-repo)
      SKIP_REPO=true
      shift
      ;;
    --help|-h)
      echo "🍎 Bootstrap macOS - Nix Development Environment Setup"
      echo "===================================================="
      echo ""
      echo "Usage: $0 [OPTIONS] <git-repo-url>"
      echo ""
      echo "Options:"
      echo "  --dry-run, -n     Show what would be done without making changes"
      echo "  --skip-repo       Skip cloning/updating repo and running playbook"
      echo "  --help, -h        Show this help message"
      echo ""
      echo "Description:"
      echo "  Sets up a complete Nix development environment by:"
      echo "  • Installing Xcode Command Line Tools"
      echo "  • Installing Homebrew package manager"
      echo "  • Installing Ansible automation tool"
      echo "  • (Optional) Cloning the nix-setup-ansible repository"
      echo "  • (Optional) Running the Ansible playbook to install Nix"
      echo ""
      echo "Examples:"
      echo "  $0 https://github.com/user/nix-setup-ansible.git"
      echo "  $0 --dry-run https://github.com/user/nix-setup-ansible.git"
      echo "  $0 --skip-repo --dry-run"
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

# --- Helper functions ---
# Logging (avoid creating file in dry run)
log() {
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN LOG] $1"
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
  fi
}

# Conditional execution wrapper
maybe_exec() {
  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would execute: $1"
  else
    eval "$1"
  fi
}

# Command presence helpers (always real checks for accurate reporting)
have_cmd() { command -v "$1" >/dev/null 2>&1; }
have_cask() { have_cmd brew && brew list --cask "$1" >/dev/null 2>&1; }
have_brew_pkg() { have_cmd brew && brew list --formula "$1" >/dev/null 2>&1; }
have_collection() { have_cmd ansible-galaxy && ansible-galaxy collection list 2>/dev/null | LC_ALL=C grep -Eq '^community\.general(\s|$)'; }

# Status accumulation (used only in dry run)
STATUS_ITEMS=()
add_status() { STATUS_ITEMS+=("$1:$2"); }

# Prevent DS_Store files on network shares (wrap for dry run)
maybe_exec "defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool TRUE"

LOGFILE="$HOME/.config/bootstrap.log"
# Ensure config dir (wrap)
maybe_exec "mkdir -p \"$HOME/.config\""

# Validate repo argument unless skipping
if [[ -z "$REPO_URL" && "$SKIP_REPO" = false ]]; then
  echo "❌ Missing required argument: git-repo-url (or use --skip-repo)"
  echo "📦 Usage: $0 [OPTIONS] <git-repo-url>"
  echo "💡 Use --help for more information"
  exit 1
fi

if [ "$DRY_RUN" = true ]; then
  echo "🔍 DRY RUN MODE - No changes will be made"
  echo "========================================"
fi

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

# Only redirect logs in real run
if [ "$DRY_RUN" = false ]; then
  exec > >(tee -a "$LOGFILE") 2>&1
else
  echo "🔍 Dry run - output would be logged to: $LOGFILE"
fi

# Pre-run status detection (dry run only) BEFORE any installs
if [ "$DRY_RUN" = true ]; then
  add_status "Xcode Command Line Tools" "$(xcode-select -p &>/dev/null && echo yes || echo no)"
  add_status "Homebrew" "$(have_cmd brew && echo yes || echo no)"
  add_status "Ghostty (cask)" "$(have_cask ghostty && echo yes || echo no)"
  add_status "Lazygit" "$(have_cmd brew && brew list lazygit &>/dev/null && echo yes || echo no)"
  add_status "PowerShell (cask)" "$(have_cask powershell && echo yes || echo no)"
  add_status "Ansible" "$(have_cmd ansible && echo yes || echo no)"
  add_status "community.general collection" "$(have_collection && echo yes || echo no)"
  if [ "$SKIP_REPO" = true ]; then
    add_status "Repository step" "skipped"
  else
    add_status "Repo directory ~/nix-setup-ansible" "$( [ -d "$HOME/nix-setup-ansible" ] && echo yes || echo no)"
  fi
  add_status "Bootstrap marker" "$( [ -f "$HOME/.bootstrap_complete" ] && echo yes || echo no)"
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
  [ "$DRY_RUN" = true ] && echo "(Would exit here)" || exit 1
fi

# Ensure sufficient disk space (5GB minimum)
log "💾 Checking available disk space..."
if [[ $(df -k / | awk 'NR==2 {print $4}') -lt 5242880 ]]; then
  log "❌ Insufficient disk space. At least 5GB free space required."
  [ "$DRY_RUN" = true ] && echo "(Would exit here)" || exit 1
fi

# Ensure Xcode Command Line Tools are installed
if ! xcode-select -p &>/dev/null; then
  log "🛠️ Xcode Command Line Tools missing"
  maybe_exec "xcode-select --install"
  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would wait for installation to complete"
  else
    log "⏳ Waiting for Xcode Command Line Tools to finish installing..."
    until xcode-select -p &>/dev/null; do sleep 5; done
  fi
else
  log "✅ Xcode Command Line Tools already installed"
fi

# Homebrew install (only if missing)
if ! have_cmd brew; then
  log "🍺 Homebrew not found"
  maybe_exec "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
else
  log "✅ Homebrew already installed"
fi

# Backup user configuration files before modifying
if [[ -f ~/.zprofile ]]; then
  maybe_exec "cp ~/.zprofile ~/.zprofile.backup.\"$(date +%Y%m%d%H%M%S)\""
  log "📑 Existing .zprofile backed up (or would be in dry run)"
fi

# Add Homebrew to shell environment (only if brew exists now)
if have_cmd brew; then
  log "➕ Ensuring Homebrew shellenv in ~/.zprofile"
  if [[ -d /opt/homebrew ]]; then
    maybe_exec "grep -q 'brew shellenv' ~/.zprofile || echo 'eval \"$(/opt/homebrew/bin/brew shellenv)\"' >> ~/.zprofile"
    [ "$DRY_RUN" = false ] && eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    maybe_exec "grep -q 'brew shellenv' ~/.zprofile || echo 'eval \"$(/usr/local/bin/brew shellenv)\"' >> ~/.zprofile"
    [ "$DRY_RUN" = false ] && eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

# Install Ghostty Terminal if not installed
log "🖥️ Checking for Ghostty terminal..."
if have_cask ghostty; then
  log "✅ Ghostty terminal already installed."
else
  maybe_exec "brew install --cask ghostty"
fi

# Install Lazygit if not installed
log "🔄 Checking for Lazygit..."
if have_cmd brew && brew list lazygit &>/dev/null; then
  log "✅ Lazygit already installed."
else
  maybe_exec "brew install lazygit"
fi

# Install PowerShell if not installed
log "🔄 Checking for PowerShell..."
if have_cask powershell; then
  log "✅ PowerShell already installed."
else
  maybe_exec "brew install --cask powershell"
fi

# Check and install Ansible if needed
log "🔄 Checking for Ansible..."
if have_cmd ansible; then
  log "✅ Ansible already installed."
else
  maybe_exec "brew install ansible"
fi

# Check and install required Ansible Galaxy collection if needed
log "🔄 Checking for required Ansible Galaxy collection community.general..."
if have_collection; then
  log "✅ Ansible Galaxy collection community.general already installed."
else
  maybe_exec "ansible-galaxy collection install community.general"
fi

# Clone / update repo (only if not skipped)
if [ "$SKIP_REPO" = false ]; then
  log "📥 Preparing repository from $REPO_URL..."
  if [ -d "$HOME/nix-setup-ansible" ]; then
    log "🔄 Repo already exists"
    if [ "$DRY_RUN" = true ]; then
      echo "  [DRY RUN] Would: cd ~/nix-setup-ansible && git pull"
    else
      cd ~/nix-setup-ansible && git pull
    fi
  else
    maybe_exec "git clone \"$REPO_URL\" ~/nix-setup-ansible"
    if [ "$DRY_RUN" = false ]; then cd ~/nix-setup-ansible; fi
  fi
else
  log "⏭️ Skipping repository clone/update per --skip-repo"
fi

# Prompt / run playbook (only if repo not skipped)
if [ "$SKIP_REPO" = false ]; then
  if [ "$DRY_RUN" = true ]; then
    echo "🤔 [DRY RUN] Would prompt to run the Ansible playbook now (default Yes)"
    echo "  [DRY RUN] Would execute: ansible-playbook -i inventory playbook.yml --ask-become-pass"
  else
    read -p "🤔 Run the Ansible playbook now? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ -n $REPLY ]]; then
      log "❌ Exiting without running the playbook. You can run it manually later."
      exit 0
    fi
    log "▶️ Running Ansible playbook..."
    ansible-playbook -i inventory playbook.yml --ask-become-pass
  fi
else
  log "⏭️ Skipping playbook execution per --skip-repo"
fi

# Mark bootstrap as completed
if [ "$DRY_RUN" = false ]; then
  maybe_exec "touch \"$HOME/.bootstrap_complete\""
  log "✅ Bootstrap complete! Output logged to $LOGFILE"
else
  echo "  [DRY RUN] Would create completion marker: ~/.bootstrap_complete"
  echo ""
  echo "===== DRY RUN STATUS REPORT (Pre-existing State) ====="
  for item in "${STATUS_ITEMS[@]}"; do
    label="${item%%:*}"; val="${item##*:}";
    if [ "$val" = yes ]; then
      echo "✅ $label"
    elif [ "$val" = skipped ]; then
      echo "⏭️ $label (skipped)"
    else
      echo "⚠️ $label (missing)"
    fi
  done
  echo "======================================================"
  echo ""
  echo "🔍 DRY RUN COMPLETE - No changes were made"
  if [ "$SKIP_REPO" = true ]; then
    echo "💡 Repo/playbook skipped: re-run without --skip-repo and add a URL to include them"
  fi
  echo "💡 To run for real: $0 ${SKIP_REPO:+--skip-repo }${DRY_RUN:+} ${REPO_URL}"
  echo "💡 Output will be logged to: $LOGFILE"
fi
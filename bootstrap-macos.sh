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
      echo "🍎 Bootstrap macOS - Nix Development Environment Setup (delegates installs to Ansible)"
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
      echo "  Minimal bootstrap: ensures Xcode Command Line Tools, clones repo, runs Ansible playbook."
      echo "  All Homebrew / app / Ansible collection installs now handled inside playbook roles."
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

# Prevent Homebrew auto update/cleanup if used later by user shell
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

# --- Helper functions ---
log() {
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN LOG] $1" | sed 's/.*/&/' >/dev/null 2>&1 || true # placeholder to retain structure
    echo "[DRY RUN LOG] $1" | sed '0,/\[DRY RUN LOG\]/ s//[DRY RUN LOG]/' >/dev/null 2>&1 || true
    echo "[DRY RUN LOG] $1" # quoted $1 (SC2086)
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE" # quoted $1 (SC2086)
  fi
}

maybe_exec() {
  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would execute: $1" # quoted $1 (SC2086)
  else
    eval "$1"
  fi
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

# Status accumulation (dry run only)
STATUS_ITEMS=()
add_status() { STATUS_ITEMS+=("$1:$2"); }

# Apply system defaults tweak (delegated earlier but harmless here)
maybe_exec "defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool TRUE"

LOGFILE="$HOME/.config/bootstrap.log"
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

# Exit early if already bootstrapped
if [[ -f "$HOME/.bootstrap_complete" ]]; then
  if [ "$DRY_RUN" = true ]; then
    echo "🔍 Found existing bootstrap marker - would exit (continuing for preview)"
  else
    log "🛑 Bootstrap already completed. Exiting."
    exit 0
  fi
fi

# Redirect logs only in real run
if [ "$DRY_RUN" = false ]; then
  exec > >(tee -a "$LOGFILE") 2>&1
else
  echo "🔍 Dry run - output would be logged to: $LOGFILE"
fi

# Pre-run status detection (dry run only)
if [ "$DRY_RUN" = true ]; then
  add_status "Xcode Command Line Tools" "$(xcode-select -p &>/dev/null && echo yes || echo no)"
  add_status "Ansible (host)" "$(have_cmd ansible && echo yes || echo no)"
  add_status "Repo directory ~/nix-setup-ansible" "$( [ -d \"$HOME/nix-setup-ansible\" ] && echo yes || echo no)"
  add_status "Bootstrap marker" "$( [ -f \"$HOME/.bootstrap_complete\" ] && echo yes || echo no)"
fi

# Shell check (advisory)
SHELL_NAME=$(basename "$SHELL")
if [[ "$SHELL_NAME" != "zsh" ]]; then
  log "⚠️ Non-zsh shell detected ($SHELL_NAME). zsh config applied by playbook may not load immediately."
fi

# Disk space check (5GB)
log "💾 Checking available disk space..."
if [[ $(df -k / | awk 'NR==2 {print $4}') -lt 5242880 ]]; then
  log "❌ Insufficient disk space. At least 5GB required."
  [ "$DRY_RUN" = true ] && echo "(Would exit here)" || exit 1
fi

# Ensure Xcode Command Line Tools
if ! xcode-select -p &>/dev/null; then
  log "🛠️ Xcode Command Line Tools missing"
  maybe_exec "xcode-select --install"
  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would wait for installation to finish"
  else
    log "⏳ Waiting for Xcode Command Line Tools to finish installing..."
    until xcode-select -p &>/dev/null; do sleep 5; done
  fi
else
  log "✅ Xcode Command Line Tools already installed"
fi

# NOTE: Homebrew / Ghostty / Lazygit / PowerShell / Ansible installations now handled by Ansible roles.
# We only need Ansible present locally to invoke the playbook; if absent we warn and exit.

if ! have_cmd ansible; then
  log "❌ Ansible not found on host. Install it first (e.g. 'brew install ansible' or 'pipx install ansible') then re-run."
  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would stop before cloning / running playbook"
  fi
  [ "$DRY_RUN" = false ] && exit 1
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
    if [ "$DRY_RUN" = false ]; then
      cd "$HOME/nix-setup-ansible" || true
    fi
  fi
else
  log "⏭️ Skipping repository clone/update per --skip-repo"
fi

# Prompt / run playbook
if [ "$SKIP_REPO" = false ]; then
  if [ "$DRY_RUN" = true ]; then
    echo "🤔 [DRY RUN] Would run: ansible-playbook -i inventory playbook.yml --check --ask-become-pass"
    echo "  [DRY RUN] (Use --check for Ansible dry-run; real run omits --check)"
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
  [ "$SKIP_REPO" = true ] && echo "💡 Repo/playbook skipped: re-run without --skip-repo and add a URL to include them"
  echo "💡 To run for real: $0 ${SKIP_REPO:+--skip-repo }${DRY_RUN:+} ${REPO_URL}"
  echo "💡 Output will be logged to: $LOGFILE"
fi
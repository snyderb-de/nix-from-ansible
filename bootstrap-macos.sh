#!/bin/bash

set -e

# Parse command line arguments
DRY_RUN=false
FULL_SIM=false # full simulation (clone + ansible --check)
REPO_URL=""
SKIP_REPO=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run|-n)
      DRY_RUN=true
      shift
      ;;
    --dry-run-full|--simulate)
      DRY_RUN=true
      FULL_SIM=true
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
      echo "  --dry-run, -n        Show what would be done (no clone, no ansible)"
      echo "  --dry-run-full       Perform shallow clone (or pull) and run ansible --check" \
           " (no system changes)"
      echo "  --skip-repo          Skip cloning/updating repo and running playbook"
      echo "  --help, -h           Show this help message"
      echo ""
      echo "Description:"
      echo "  Minimal bootstrap: ensures Xcode Command Line Tools, clones repo, runs Ansible playbook."
      echo "  All Homebrew / app / Ansible collection installs now handled inside playbook roles."
      echo "  --dry-run          : Only prints planned actions."
      echo "  --dry-run-full     : Actually clones/pulls repo then runs ansible in --check mode."
      echo ""
      echo "Examples:"
      echo "  $0 https://github.com/user/nix-setup-ansible.git"
      echo "  $0 --dry-run https://github.com/user/nix-setup-ansible.git"
      echo "  $0 --dry-run-full https://github.com/user/nix-setup-ansible.git"
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

# Prevent Homebrew auto update/cleanup
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

# --- Helper functions ---
log() { if [ "$DRY_RUN" = true ]; then echo "[DRY RUN LOG] $1"; else echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"; fi; }
run_or_echo() { if [ "$DRY_RUN" = true ]; then echo "  [DRY RUN] Would: $*"; else "$@"; fi; }

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
  if [ "$FULL_SIM" = true ]; then
    echo "🔍 FULL SIMULATION MODE (--dry-run-full)"
    echo "   Will clone/pull repo and run ansible in --check (no system changes)."
  else
    echo "🔍 DRY RUN MODE - No changes will be made"
  fi
  echo "========================================"
fi

# Exit early if already bootstrapped (skip only in normal run; full sim still proceeds for preview)
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
  add_status "Repo directory ~/nix-setup-ansible" "$( [ -d "$HOME/nix-setup-ansible" ] && echo yes || echo no)"
  add_status "Bootstrap marker" "$( [ -f "$HOME/.bootstrap_complete" ] && echo yes || echo no)"
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

# Ensure Xcode Command Line Tools (skip actual install in any dry-run variant)
if ! xcode-select -p &>/dev/null; then
  log "🛠️ Xcode Command Line Tools missing"
  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would trigger: xcode-select --install"
    echo "  [DRY RUN] Would wait for installation to finish"
  else
    maybe_exec "xcode-select --install"
    log "⏳ Waiting for Xcode Command Line Tools to finish installing..."
    until xcode-select -p &>/dev/null; do sleep 5; done
  fi
else
  log "✅ Xcode Command Line Tools already installed"
fi

# Host dependency: Homebrew (install here to remove playbook duplication)
if ! have_cmd brew; then
  log "🍺 Homebrew not found"
  if [ "$DRY_RUN" = true ] && [ "$FULL_SIM" = false ]; then
    echo "  [DRY RUN] Would install Homebrew via official script"
  else
    if [ "$DRY_RUN" = true ] && [ "$FULL_SIM" = true ]; then
      echo "  [FULL SIM] Installing Homebrew (real network + file changes)"
    fi
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
      log "❌ Homebrew install failed"; [ "$FULL_SIM" = true ] && exit 1; [ "$DRY_RUN" = false ] && exit 1; }
  fi
else
  log "✅ Homebrew present"
fi

# Ensure brew shellenv line for real or full sim (so ansible in full simulation can find brew-installed ansible)
if have_cmd brew; then
  BREW_PREFIX=$( ( [ -d /opt/homebrew ] && echo /opt/homebrew ) || echo /usr/local )
  if [ "$DRY_RUN" = true ] && [ "$FULL_SIM" = false ]; then
    grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null || echo "  [DRY RUN] Would append brew shellenv to ~/.zprofile"
  else
    if ! grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
      echo "eval \"$($BREW_PREFIX/bin/brew shellenv)\"" >> "$HOME/.zprofile"
      log "➕ Added brew shellenv to ~/.zprofile"
    else
      log "ℹ️ brew shellenv already in ~/.zprofile"
    fi
  fi
fi

# Host dependency: Ansible via Homebrew
if ! have_cmd ansible; then
  log "📦 Ansible not found (host)"
  if [ "$DRY_RUN" = true ] && [ "$FULL_SIM" = false ]; then
    echo "  [DRY RUN] Would run: brew install ansible"
  else
    if ! have_cmd brew; then
      log "❌ Cannot install Ansible: Homebrew missing"
      exit 1
    fi
    log "📥 Installing Ansible (brew)"
    if [ "$DRY_RUN" = true ] && [ "$FULL_SIM" = true ]; then
      echo "  [FULL SIM] Executing: brew install ansible"
    fi
    brew install ansible || { log "❌ Ansible install failed"; exit 1; }
  fi
else
  log "✅ Ansible present (host)"
fi

# Clone / update repo logic
if [ "$SKIP_REPO" = false ]; then
  log "📥 Preparing repository from $REPO_URL..."
  if [ -d "$HOME/nix-setup-ansible" ]; then
    if [ "$DRY_RUN" = true ] && [ "$FULL_SIM" = false ]; then
      log "🔄 Repo already exists (no pull in basic dry run)"
      echo "  [DRY RUN] Would: git -C ~/nix-setup-ansible pull --ff-only"
    else
      log "🔄 Repo already exists - updating"
      if [ "$DRY_RUN" = true ] && [ "$FULL_SIM" = true ]; then
        git -C "$HOME/nix-setup-ansible" pull --ff-only
      elif [ "$DRY_RUN" = false ]; then
        git -C "$HOME/nix-setup-ansible" pull --ff-only
      fi
    fi
  else
    if [ "$DRY_RUN" = true ] && [ "$FULL_SIM" = false ]; then
      echo "  [DRY RUN] Would clone (shallow): git clone --depth 1 \"$REPO_URL\" ~/nix-setup-ansible"
    else
      log "📥 Cloning repository (shallow)"
      git clone --depth 1 "$REPO_URL" "$HOME/nix-setup-ansible"
    fi
  fi
  # Enter directory if actually present (full sim or real)
  if [ -d "$HOME/nix-setup-ansible" ] && { [ "$FULL_SIM" = true ] || [ "$DRY_RUN" = false ]; }; then
    cd "$HOME/nix-setup-ansible" || true
  fi
else
  log "⏭️ Skipping repository clone/update per --skip-repo"
fi

# Run playbook
if [ "$SKIP_REPO" = false ]; then
  if [ "$FULL_SIM" = true ]; then
    if [ -d "$HOME/nix-setup-ansible" ]; then
      log "🧪 Running Ansible in check mode (simulation)"
      ansible-playbook -i inventory playbook.yml --check --ask-become-pass || true
    else
      log "⚠️ Repo directory missing; cannot run ansible simulation"
    fi
  elif [ "$DRY_RUN" = true ]; then
    echo "🤔 [DRY RUN] Would run: ansible-playbook -i inventory playbook.yml --check --ask-become-pass"
  else
    read -p "🤔 Run the Ansible playbook now? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ -n $REPLY ]]; then
      log "❌ Exiting without running the playbook. You can run it manually later."
      exit 0
    fi
    log "▶️ Running Ansible playbook..."
    ansible-playbook -i inventory playbook.yml --ask-become-pass
    PLAY_STATUS=$?
  fi
else
  log "⏭️ Skipping playbook execution per --skip-repo"
fi

# Mark bootstrap as completed (only if real run succeeded)
if [ "$DRY_RUN" = false ]; then
  if [ "${PLAY_STATUS:-0}" -eq 0 ]; then
    touch "$HOME/.bootstrap_complete"
    log "✅ Bootstrap complete! Output logged to $LOGFILE"
  else
    log "⚠️ Playbook failed (rc=${PLAY_STATUS:-?}); not writing completion marker."
  fi
else
  if [ "$FULL_SIM" = true ]; then
    echo "  [FULL SIM] Did shallow clone/pull and ansible --check (no persistent marker created)"
  else
    echo "  [DRY RUN] Would create completion marker: ~/.bootstrap_complete"
  fi
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
  if [ "$FULL_SIM" = true ]; then
    echo "🔍 FULL SIMULATION COMPLETE - System state unchanged"
  else
    echo "🔍 DRY RUN COMPLETE - No changes were made"
  fi
  [ "$SKIP_REPO" = true ] && echo "💡 Repo/playbook skipped: re-run without --skip-repo and add a URL to include them"
  if [ "$FULL_SIM" = true ]; then
    echo "💡 To perform a real run: $0 ${SKIP_REPO:+--skip-repo } $REPO_URL"
  else
    echo "💡 To run full simulation: $0 --dry-run-full ${SKIP_REPO:+--skip-repo } $REPO_URL"
    echo "💡 To run for real: $0 ${SKIP_REPO:+--skip-repo } $REPO_URL"
  fi
  echo "💡 Output (real runs) will be logged to: $LOGFILE"
fi
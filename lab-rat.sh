#!/bin/bash

set -e

# Parse command line arguments
DRY_RUN=false
if [[ "$1" == "--dry-run" ]] || [[ "$1" == "-n" ]]; then
    DRY_RUN=true
    echo "🔍 DRY RUN MODE - No changes will be made"
    echo "========================================"
elif [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "🔬 Lab Rat - Smart Setup & Cleanup"
    echo "=================================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --dry-run, -n    Show what would be done without making changes"
    echo "  --help, -h       Show this help message"
    echo ""
    echo "Description:"
    echo "  Smart script that automatically:"
    echo "  • If labrat user missing: Creates user with admin privileges + tools"
    echo "  • If labrat user exists: Cleans up all Nix installations and configs"
    echo ""
    echo "Examples:"
    echo "  sudo $0                    # Run normally"
    echo "  sudo $0 --dry-run         # See what would be done"
    echo ""
    exit 0
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

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    IS_MACOS=true
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    IS_MACOS=false
else
    echo "❌ Unsupported OS: $OSTYPE"
    exit 1
fi

echo "🖥️ Detected OS: $([ "$IS_MACOS" = true ] && echo "macOS" || echo "Linux")"

# Require root (unless dry run)
if [[ "$EUID" -ne 0 ]] && [[ "$DRY_RUN" = false ]]; then
  echo "🛑 This script must be run as root."
  echo "👉 Try again with: sudo $0"
  exit 1
elif [[ "$EUID" -ne 0 ]] && [[ "$DRY_RUN" = true ]]; then
  echo "🔍 DRY RUN: Running without root (some checks may be inaccurate)"
fi

echo "🔬 Lab Rat - Smart Setup & Cleanup $([ "$DRY_RUN" = true ] && echo "(DRY RUN)" || echo "")"
echo "=================================="

USERNAME="labrat"
FULLNAME="Lab Rat Test User"
USER_UID=502

# Check if user exists
echo "🔍 Checking if user '$USERNAME' exists..."
USER_EXISTS=false
if [ "$IS_MACOS" = true ]; then
  if dscl . -read "/Users/$USERNAME" &>/dev/null; then
    USER_EXISTS=true
    USER_HOME=$(dscl . -read "/Users/$USERNAME" NFSHomeDirectory 2>/dev/null | awk '{print $2}' || echo "/Users/$USERNAME")
  else
    USER_HOME="/Users/$USERNAME"
  fi
else
  if id "$USERNAME" &>/dev/null; then
    USER_EXISTS=true
    USER_HOME=$(getent passwd "$USERNAME" | cut -d: -f6)
  else
    USER_HOME="/home/$USERNAME"
  fi
fi

if [ "$USER_EXISTS" = false ]; then
  echo "👤 User '$USERNAME' not found - $([ "$DRY_RUN" = true ] && echo "would create" || echo "creating") new user..."
  
  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would prompt for password for new user '$USERNAME'"
    echo "  [DRY RUN] Would create user with:"
    echo "    - Username: $USERNAME"
    echo "    - Full name: $FULLNAME"
    echo "    - UID: $USER_UID"
    echo "    - Home: $USER_HOME"
    echo "    - Shell: /bin/zsh"
    echo "    - Admin privileges: Yes"
    if [ "$IS_MACOS" = true ]; then
      echo "    - Groups: admin, _appserveradm, _appserverusr"
    else
      echo "    - Groups: sudo/wheel, adm, staff, users"
    fi
    echo "  [DRY RUN] Would install Homebrew (macOS) or update package manager (Linux)"
    echo "  [DRY RUN] Would install Ansible and community.general collection"
  else
    # Prompt for password
    read -r -s -p "🔐 Enter password for new user '$USERNAME': " PASSWORD
    echo
    read -r -s -p "🔁 Confirm password: " PASSWORD_CONFIRM
    echo

    if [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
      echo "❌ Passwords do not match."
      exit 1
    fi
  fi

  # Create the user
  dry_run_msg "Creating new admin user: $USERNAME"
  if [ "$IS_MACOS" = true ]; then
    # macOS user creation
    maybe_exec "dscl . -create \"/Users/$USERNAME\""
    maybe_exec "dscl . -create \"/Users/$USERNAME\" UserShell /bin/zsh"
    maybe_exec "dscl . -create \"/Users/$USERNAME\" RealName \"$FULLNAME\""
    maybe_exec "dscl . -create \"/Users/$USERNAME\" UniqueID \"$USER_UID\""
    maybe_exec "dscl . -create \"/Users/$USERNAME\" PrimaryGroupID 80"
    if [ "$DRY_RUN" = false ]; then
      maybe_exec "dscl . -create \"/Users/$USERNAME\" NFSHomeDirectory \"$USER_HOME\""
      maybe_exec "dscl . -passwd \"/Users/$USERNAME\" \"$PASSWORD\""
      maybe_exec "createhomedir -c -u \"$USERNAME\" > /dev/null"
    fi
    
    # Add admin privileges
    maybe_exec "dseditgroup -o edit -a \"$USERNAME\" -t user admin"
    maybe_exec "dseditgroup -o edit -a \"$USERNAME\" -t user _appserveradm 2>/dev/null || true"
    maybe_exec "dseditgroup -o edit -a \"$USERNAME\" -t user _appserverusr 2>/dev/null || true"
  else
    # Linux user creation
    if [ "$DRY_RUN" = false ]; then
      maybe_exec "useradd -m -s /bin/zsh -c \"$FULLNAME\" -u \"$USER_UID\" \"$USERNAME\""
      maybe_exec "echo \"$USERNAME:\$PASSWORD\" | chpasswd"
    fi
    
    # Add admin privileges
    dry_run_msg "Adding user to admin groups..."
    maybe_exec "if getent group sudo >/dev/null 2>&1; then usermod -aG sudo \"$USERNAME\"; elif getent group wheel >/dev/null 2>&1; then usermod -aG wheel \"$USERNAME\"; fi"
    
    # Add to common admin groups
    for group in adm staff users; do
      maybe_exec "if getent group \"$group\" >/dev/null 2>&1; then usermod -aG \"$group\" \"$USERNAME\" 2>/dev/null || true; fi"
    done
  fi

  # Create default config files
  dry_run_msg "Setting up user home directory..."
  if [ "$DRY_RUN" = false ]; then
    mkdir -p "$USER_HOME/.config"
    cat > "$USER_HOME/.zshrc" << 'EOF'
# Fresh lab rat user setup
# Basic shell configuration

# Add Homebrew to PATH (will be set up during installation)
if [ -f /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -f /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Add any custom configurations below this line

EOF

    # Set ownership
    if [ "$IS_MACOS" = true ]; then
      chown -R "$USERNAME:staff" "$USER_HOME/.config"
      chown "$USERNAME:staff" "$USER_HOME/.zshrc"
    else
      chown -R "$USERNAME:$USERNAME" "$USER_HOME/.config"
      chown "$USERNAME:$USERNAME" "$USER_HOME/.zshrc"
    fi
  fi

  # Install package manager and Ansible
  dry_run_msg "Installing package manager and Ansible..."
  if [ "$DRY_RUN" = false ]; then
    if [ "$IS_MACOS" = true ]; then
      # Install Homebrew as the new user, but from their home directory
      echo "📦 Installing Homebrew for user $USERNAME..."
      sudo -u "$USERNAME" -i bash << 'EOF'
# Change to home directory to avoid permission issues
cd ~

# Install Homebrew
if ! command -v brew &> /dev/null; then
    echo "📦 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for current session
    if [ -f /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -f /usr/local/bin/brew ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
    
    # Add Homebrew to shell profile
    if [ -f /opt/homebrew/bin/brew ]; then
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
    elif [ -f /usr/local/bin/brew ]; then
      echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zshrc
    fi
else
    echo "✅ Homebrew already installed"
    # Ensure it's in PATH
    if [ -f /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -f /usr/local/bin/brew ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

# Install Ansible
if ! command -v ansible &> /dev/null; then
    echo "🤖 Installing Ansible..."
    brew install ansible
else
    echo "✅ Ansible already installed"
fi

# Install Ansible community collection
echo "📚 Installing Ansible community.general collection..."
ansible-galaxy collection install community.general --force
EOF
    else
      # Linux - install ansible via package manager
      echo "📦 Installing Ansible via package manager..."
      if command -v apt &> /dev/null; then
        apt update && apt install -y ansible
      elif command -v dnf &> /dev/null; then
        dnf install -y ansible
      elif command -v pacman &> /dev/null; then
        pacman -Sy --noconfirm ansible
      elif command -v zypper &> /dev/null; then
        zypper install -y ansible
      fi
      
      # Install Ansible community collection as the user
      echo "📚 Installing Ansible community.general collection..."
      sudo -u "$USERNAME" -i ansible-galaxy collection install community.general --force
    fi
  fi

  # Verify user creation and permissions
  echo "🔍 Verifying user creation..."
  if [ "$DRY_RUN" = false ]; then
    if [ "$IS_MACOS" = true ]; then
      if dseditgroup -o checkmember -m "$USERNAME" admin | grep -q "yes"; then
        echo "✅ User '$USERNAME' successfully created with admin privileges"
      else
        echo "⚠️ Warning: User created but admin privileges may not be set correctly"
        echo "🔧 Attempting to fix admin privileges..."
        dseditgroup -o edit -a "$USERNAME" -t user admin 2>/dev/null || true
      fi
    else
      if groups "$USERNAME" | grep -qE "(sudo|wheel)"; then
        echo "✅ User '$USERNAME' successfully created with admin privileges"
      else
        echo "⚠️ Warning: User created but admin privileges may not be set correctly"
      fi
    fi
    
    # Test if user can access their home directory
    if sudo -u "$USERNAME" -i test -w ~; then
      echo "✅ User home directory accessible"
    else
      echo "⚠️ Warning: User home directory access issues"
    fi
  fi

  echo "✅ User '$USERNAME' created and configured successfully!"

else
  echo "✅ Found existing user '$USERNAME'"
  
  # Check if user has Homebrew and Ansible installed
  USER_HAS_BREW=false
  USER_HAS_ANSIBLE=false
  
  if [ "$DRY_RUN" = false ]; then
    if sudo -u "$USERNAME" -i bash -c 'command -v brew &> /dev/null'; then
      USER_HAS_BREW=true
    fi
    if sudo -u "$USERNAME" -i bash -c 'command -v ansible &> /dev/null'; then
      USER_HAS_ANSIBLE=true
    fi
  fi
  
  if [ "$USER_HAS_BREW" = true ] && [ "$USER_HAS_ANSIBLE" = true ]; then
    echo "🔧 User has tools installed - $([ "$DRY_RUN" = true ] && echo "would clean" || echo "cleaning") up installations..."
    
    # Proceed with cleanup logic (existing code)
    
    # 1. Remove Nix installation
  echo ""
  dry_run_msg "Removing Nix installation..."
  if [ -d /nix ]; then
    if [ -x /nix/nix-installer ]; then
      dry_run_msg "Using nix-installer uninstall..."
      maybe_exec "/nix/nix-installer uninstall --no-confirm || /nix/nix-installer uninstall || true"
    else
      dry_run_msg "Performing manual Nix cleanup..."
      
      if [ "$IS_MACOS" = true ]; then
        # Stop and remove Nix daemon
        maybe_exec "launchctl remove org.nixos.nix-daemon 2>/dev/null || true"
        
        # Remove Nix users and groups (preserve labrat user)
        maybe_exec "dscl . -delete /Users/nixbld 2>/dev/null || true"
        maybe_exec "dscl . -delete /Groups/nixbld 2>/dev/null || true"
        
        # Remove individual nixbld users
        dry_run_msg "Removing nixbld users (1-32)..."
        if [ "$DRY_RUN" = false ]; then
          for i in {1..32}; do
            if dscl . -read "/Users/nixbld$i" &>/dev/null; then
              dscl . -delete "/Users/nixbld$i" 2>/dev/null || true
            fi
          done
        fi
        
        # Unmount Nix volume and clean up
        maybe_exec "diskutil unmount force /nix 2>/dev/null || true"
        maybe_exec "sed -i '' '/^nix/d' /etc/synthetic.conf 2>/dev/null || true"
      else
        # Linux Nix cleanup
        maybe_exec "systemctl stop nix-daemon 2>/dev/null || true"
        maybe_exec "systemctl disable nix-daemon 2>/dev/null || true"
        
        # Remove nixbld users and group
        dry_run_msg "Removing nixbld users and group..."
        if [ "$DRY_RUN" = false ]; then
          for i in {1..32}; do
            userdel "nixbld$i" 2>/dev/null || true
          done
          groupdel nixbld 2>/dev/null || true
        fi
      fi
      
      # Remove profile scripts
      maybe_exec "rm -f /etc/profile.d/nix.sh /etc/paths.d/nix"
      
      # Remove /nix directory
      dry_run_msg "Removing /nix directory..."
      if [ "$DRY_RUN" = false ]; then
        if ! rm -rf /nix 2>/dev/null; then
          find /nix -mindepth 1 -delete 2>/dev/null || true
          rmdir /nix 2>/dev/null || true
        fi
      fi
    fi
    
    if [ -d /nix ]; then
      dry_run_msg "/nix directory still exists $([ "$IS_MACOS" = true ] && echo "(normal on macOS with SIP)")"
    else
      dry_run_msg "Nix installation removed successfully"
    fi
  else
    dry_run_msg "No Nix installation found"
  fi

  # 2. Clean up user's configurations and installations
  echo ""
  dry_run_msg "Cleaning user's configurations..."
  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would remove:"
    echo "    - ~/.nix-profile, ~/.nix-defexpr, ~/.nix-channels"
    echo "    - ~/.config/nix, ~/.cache/nix" 
    echo "    - ~/.local/state/nix, ~/.local/share/nix"
    echo "    - ~/nix-setup-ansible repository"
    echo "    - ~/.bootstrap_complete marker"
    echo "    - ~/.config/bootstrap.log"
    echo "    - Nix entries from ~/.zshrc"
  else
    sudo -u "$USERNAME" -i bash << 'EOF'
# Change to home directory to avoid permission issues
cd ~

# Remove Nix-related directories and files
rm -rf ~/.nix-profile ~/.nix-defexpr ~/.nix-channels ~/.config/nix ~/.cache/nix
rm -rf ~/.local/state/nix ~/.local/share/nix

# Remove cloned repositories
rm -rf ~/nix-setup-ansible

# Remove bootstrap markers and logs
rm -f ~/.bootstrap_complete ~/.config/bootstrap.log

# Clean shell configuration
cat > ~/.zshrc << 'ZSHRC_EOF'
# Fresh lab rat user setup - cleaned on $(date)
# Basic shell configuration

# Add Homebrew to PATH if it exists
if [ -f /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -f /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Add any custom configurations below this line

ZSHRC_EOF

echo "  ✅ User configurations cleaned"
EOF
  fi

  # 3. Optional: Clean up Homebrew packages
  echo ""
  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would ask: Clean up Homebrew packages (keeps Homebrew & Ansible)? (y/N)"
    echo "  [DRY RUN] If yes, would remove all Homebrew packages except Ansible"
  else
    read -r -p "🍺 Clean up Homebrew packages (keeps Homebrew & Ansible)? (y/N): " clean_brew
    if [[ "$clean_brew" =~ ^[Yy]$ ]]; then
      dry_run_msg "Cleaning up Homebrew packages..."
      sudo -u "$USERNAME" -i bash << 'EOF'
# Change to home directory to avoid permission issues
cd ~

if command -v brew &> /dev/null; then
  # Get list of installed packages (excluding ansible)
  PACKAGES=$(brew list --formula | grep -v '^ansible$' | head -20)
  
  if [ -n "$PACKAGES" ]; then
    echo "  📦 Removing packages: $PACKAGES"
    brew uninstall --ignore-dependencies $PACKAGES 2>/dev/null || true
  fi
  
  brew cleanup 2>/dev/null || true
  echo "  ✅ Homebrew packages cleaned (kept Homebrew & Ansible)"
else
  echo "  ℹ️ Homebrew not found"
fi
EOF
    else
      dry_run_msg "Skipping Homebrew package cleanup"
    fi
  fi

  # 4. Clear external logs
  echo ""
  dry_run_msg "Cleaning up external logs..."
  if [ -d "/Volumes/F9/logs" ]; then
    maybe_exec "rm -f /Volumes/F9/logs/nix-bootstrap-*.log"
    dry_run_msg "Removed external bootstrap logs"
  else
    dry_run_msg "No external log directory found"
  fi

  echo ""
  echo "✅ User '$USERNAME' $([ "$DRY_RUN" = true ] && echo "would be cleaned" || echo "cleaned") successfully!"

  else
    echo "🛠️ User exists but missing tools - $([ "$DRY_RUN" = true ] && echo "would set up" || echo "setting up") Homebrew and Ansible..."
    
    # First, ensure the user has admin privileges
    echo "🔧 Verifying admin privileges for existing user..."
    if [ "$DRY_RUN" = false ]; then
      if [ "$IS_MACOS" = true ]; then
        if ! dseditgroup -o checkmember -m "$USERNAME" admin | grep -q "yes"; then
          echo "⚠️ User lacks admin privileges - adding to admin group..."
          dseditgroup -o edit -a "$USERNAME" -t user admin
          dseditgroup -o edit -a "$USERNAME" -t user _appserveradm 2>/dev/null || true
          dseditgroup -o edit -a "$USERNAME" -t user _appserverusr 2>/dev/null || true
        else
          echo "✅ User has admin privileges"
        fi
        
        # Test if user can actually sudo
        echo "🔧 Testing sudo access..."
        if sudo -u "$USERNAME" -i sudo -n true 2>/dev/null; then
          echo "✅ User can use sudo without password"
        else
          echo "⚠️ User needs password for sudo - setting up passwordless sudo for Homebrew install..."
          # Temporarily allow passwordless sudo for this user
          echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/temp_$USERNAME"
          echo "🔧 Temporary passwordless sudo enabled"
        fi
      fi
    fi
    
    # Install package manager and Ansible for existing user
    dry_run_msg "Installing package manager and Ansible..."
    if [ "$DRY_RUN" = false ]; then
      if [ "$IS_MACOS" = true ]; then
        # Install Homebrew as the existing user
        echo "📦 Installing Homebrew for existing user $USERNAME..."
        sudo -u "$USERNAME" -i bash << 'EOF'
# Change to home directory to avoid permission issues
cd ~

# Install Homebrew
if ! command -v brew &> /dev/null; then
    echo "📦 Installing Homebrew..."
    
    # Verify we can sudo (for Homebrew installation)
    if ! sudo -n true 2>/dev/null; then
        echo "⚠️ User needs sudo access for Homebrew installation"
        echo "💡 Homebrew requires admin privileges to install"
        exit 1
    fi
    
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for current session
    if [ -f /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -f /usr/local/bin/brew ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
    
    # Add Homebrew to shell profile
    if [ -f /opt/homebrew/bin/brew ]; then
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
    elif [ -f /usr/local/bin/brew ]; then
      echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zshrc
    fi
else
    echo "✅ Homebrew already installed"
    # Ensure it's in PATH
    if [ -f /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -f /usr/local/bin/brew ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

# Install Ansible
if ! command -v ansible &> /dev/null; then
    echo "🤖 Installing Ansible..."
    brew install ansible
else
    echo "✅ Ansible already installed"
fi

# Install Ansible community collection
echo "📚 Installing Ansible community.general collection..."
ansible-galaxy collection install community.general --force
EOF
      else
        # Linux - install ansible via package manager
        echo "📦 Installing Ansible via package manager..."
        if command -v apt &> /dev/null; then
          apt update && apt install -y ansible
        elif command -v dnf &> /dev/null; then
          dnf install -y ansible
        elif command -v pacman &> /dev/null; then
          pacman -Sy --noconfirm ansible
        elif command -v zypper &> /dev/null; then
          zypper install -y ansible
        fi
        
        # Install Ansible community collection as the user
        echo "📚 Installing Ansible community.general collection..."
        sudo -u "$USERNAME" -i ansible-galaxy collection install community.general --force
      fi
    fi
    
    # Clean up temporary sudo rule if it was created
    if [ -f "/etc/sudoers.d/temp_$USERNAME" ]; then
      echo "🔧 Removing temporary sudo rule..."
      rm -f "/etc/sudoers.d/temp_$USERNAME"
    fi
    
    echo "✅ User '$USERNAME' set up with Homebrew and Ansible!"
  fi
fi

echo ""
echo "🚀 Lab rat environment $([ "$DRY_RUN" = true ] && echo "would be" || echo "is") ready!"
if [ "$DRY_RUN" = true ]; then
  echo "💡 To actually run: sudo $0"
  echo "💡 Then test with: sudo -u $USERNAME bash -c 'cd && ./bootstrap-$([ "$IS_MACOS" = true ] && echo "macos" || echo "linux").sh <repo-url>'"
else
  echo "💡 To run tests: sudo -u $USERNAME bash -c 'cd && ./bootstrap-$([ "$IS_MACOS" = true ] && echo "macos" || echo "linux").sh <repo-url>'"
fi

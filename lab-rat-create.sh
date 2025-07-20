#!/bin/bash

set -e

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

# Require root
if [[ "$EUID" -ne 0 ]]; then
  echo "🛑 This script must be run as root."
  echo "👉 Try again with: sudo $0"
  exit 1
fi

echo "👤 Lab Rat User Creation Script"
echo "==============================="

USERNAME="labrat"
FULLNAME="Lab Rat Test User"
USER_UID=502

# Check if user already exists
echo "🔍 Checking if user '$USERNAME' already exists..."
USER_EXISTS=false
if [ "$IS_MACOS" = true ]; then
  if dscl . -read "/Users/$USERNAME" &>/dev/null; then
    USER_EXISTS=true
  fi
else
  if id "$USERNAME" &>/dev/null; then
    USER_EXISTS=true
  fi
fi

if [ "$USER_EXISTS" = true ]; then
  echo "❌ User '$USERNAME' already exists!"
  echo "💡 Run the lab-rat-delete.sh script first to remove existing users"
  exit 1
fi

# Set platform-specific home directory
if [ "$IS_MACOS" = true ]; then
  USER_HOME="/Users/$USERNAME"
else
  USER_HOME="/home/$USERNAME"
fi

# Prompt for password
read -r -s -p "🔐 Enter password for new user '$USERNAME': " PASSWORD
echo
read -r -s -p "🔁 Confirm password: " PASSWORD_CONFIRM
echo

if [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
  echo "❌ Passwords do not match."
  exit 1
fi

# Create the user
echo "👤 Creating new admin user: $USERNAME"
if [ "$IS_MACOS" = true ]; then
  # macOS user creation
  dscl . -create "/Users/$USERNAME"
  dscl . -create "/Users/$USERNAME" UserShell /bin/zsh
  dscl . -create "/Users/$USERNAME" RealName "$FULLNAME"
  dscl . -create "/Users/$USERNAME" UniqueID "$USER_UID"
  dscl . -create "/Users/$USERNAME" PrimaryGroupID 80
  dscl . -create "/Users/$USERNAME" NFSHomeDirectory "$USER_HOME"
  dscl . -passwd "/Users/$USERNAME" "$PASSWORD"
  createhomedir -c -u "$USERNAME" > /dev/null
else
  # Linux user creation
  useradd -m -s /bin/zsh -c "$FULLNAME" -u "$USER_UID" "$USERNAME"
  echo "$USERNAME:$PASSWORD" | chpasswd
fi

echo "✅ User created successfully"

# Add admin privileges
echo "🔑 Adding admin privileges..."
if [ "$IS_MACOS" = true ]; then
  # macOS admin setup
  dseditgroup -o edit -a "$USERNAME" -t user admin
  # Also add to _appserveradm and _appserverusr for broader admin access
  dseditgroup -o edit -a "$USERNAME" -t user _appserveradm 2>/dev/null || true
  dseditgroup -o edit -a "$USERNAME" -t user _appserverusr 2>/dev/null || true

  # Verify admin status
  if dseditgroup -o checkmember -m "$USERNAME" admin | grep -q "yes"; then
    echo "✅ User '$USERNAME' successfully added to admin group"
  else
    echo "⚠️ Warning: Failed to add '$USERNAME' to admin group"
    echo "🔧 Attempting alternative admin setup..."
    # Try alternative method
    dscl . -append /Groups/admin GroupMembership "$USERNAME"
  fi
else
  # Linux admin setup
  # Add to sudo group (Debian/Ubuntu) or wheel group (RHEL/CentOS/Arch)
  if getent group sudo >/dev/null 2>&1; then
    usermod -aG sudo "$USERNAME"
    echo "✅ User '$USERNAME' added to sudo group"
  elif getent group wheel >/dev/null 2>&1; then
    usermod -aG wheel "$USERNAME"
    echo "✅ User '$USERNAME' added to wheel group"
  else
    echo "⚠️ Warning: Neither sudo nor wheel group found. User may not have admin privileges."
  fi
  
  # Also add to common admin groups
  for group in adm staff users; do
    if getent group "$group" >/dev/null 2>&1; then
      usermod -aG "$group" "$USERNAME" 2>/dev/null || true
    fi
  done
fi

if [ "$IS_MACOS" = true ]; then
  # Prevent setup assistant
  defaults write /Library/Preferences/com.apple.SetupAssistant DidSeeCloudSetup -bool TRUE
  defaults write /Library/Preferences/com.apple.SetupAssistant DidSeeSetup -bool TRUE
  defaults write /Library/Preferences/com.apple.SetupAssistant DidSeePrivacy -bool TRUE
fi

# Create default config files
echo "📁 Creating .config and .zshrc in $USER_HOME"
mkdir -p "$USER_HOME/.config"
touch "$USER_HOME/.zshrc"
echo "# fresh test user setup on $(date)" >> "$USER_HOME/.zshrc"

# Set ownership
if [ "$IS_MACOS" = true ]; then
  chown -R "$USERNAME:staff" "$USER_HOME/.config"
  chown "$USERNAME:staff" "$USER_HOME/.zshrc"
else
  chown -R "$USERNAME:$USERNAME" "$USER_HOME/.config"
  chown "$USERNAME:$USERNAME" "$USER_HOME/.zshrc"
fi

# Install essential tools for the lab rat user
echo "🛠️ Installing package manager and Ansible for user '$USERNAME'..."

# Switch to the new user context for installations
if [ "$IS_MACOS" = true ]; then
  sudo -u "$USERNAME" bash << 'EOF'
# Install Homebrew
if ! command -v brew &> /dev/null; then
    echo "📦 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for current session
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "✅ Homebrew already installed"
fi

# Install Ansible via Homebrew
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
  # Linux - update package manager and install ansible
  echo "📦 Updating package manager and installing Ansible..."
  
  # Detect package manager and install ansible
  if command -v apt &> /dev/null; then
    apt update
    apt install -y ansible
  elif command -v dnf &> /dev/null; then
    dnf install -y ansible
  elif command -v pacman &> /dev/null; then
    pacman -Sy --noconfirm ansible
  elif command -v zypper &> /dev/null; then
    zypper install -y ansible
  else
    echo "❌ Unsupported package manager. Please install Ansible manually."
    exit 1
  fi
  
  # Install Ansible community collection as the user
  sudo -u "$USERNAME" bash << 'EOF'
echo "📚 Installing Ansible community.general collection..."
ansible-galaxy collection install community.general --force
EOF
fi

echo ""
echo "✅ User '$USERNAME' created successfully!"
echo "ℹ️ You can now log in as '$USERNAME' with the password you provided."
echo "🚀 Homebrew and Ansible are ready for running the playbook!"

#!/bin/bash

set -e

# Require root
if [[ "$EUID" -ne 0 ]]; then
  echo "🛑 This script must be run as root."
  echo "👉 Try again with: sudo $0"
  exit 1
fi

USERNAME="labrat"
FULLNAME="Lab Rat Test User"
USER_HOME="/Users/$USERNAME"
USER_UID=502

# Prompt for password
read -s -p "🔐 Enter password for new user '$USERNAME': " PASSWORD
echo
read -s -p "🔁 Confirm password: " PASSWORD_CONFIRM
echo

if [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
  echo "❌ Passwords do not match."
  exit 1
fi

echo "🔁 Resetting user: $USERNAME"

# Delete user if it exists
if id "$USERNAME" &>/dev/null; then
  echo "🗑️ Deleting existing user: $USERNAME"
  dscl . -delete "/Users/$USERNAME" || true
  rm -rf "$USER_HOME"
else
  echo "ℹ️ No existing user found."
fi

# Create the user
echo "👤 Creating new admin user: $USERNAME"
dscl . -create "/Users/$USERNAME"
dscl . -create "/Users/$USERNAME" UserShell /bin/zsh
dscl . -create "/Users/$USERNAME" RealName "$FULLNAME"
dscl . -create "/Users/$USERNAME" UniqueID "$USER_UID"
dscl . -create "/Users/$USERNAME" PrimaryGroupID 80
dscl . -create "/Users/$USERNAME" NFSHomeDirectory "$USER_HOME"
dscl . -passwd "/Users/$USERNAME" "$PASSWORD"
createhomedir -c -u "$USERNAME" > /dev/null

# Ensure user is admin
dseditgroup -o edit -a "$USERNAME" -t user admin

# Prevent setup assistant
defaults write /Library/Preferences/com.apple.SetupAssistant DidSeeCloudSetup -bool TRUE
defaults write /Library/Preferences/com.apple.SetupAssistant DidSeeSetup -bool TRUE
defaults write /Library/Preferences/com.apple.SetupAssistant DidSeePrivacy -bool TRUE

# Create default config files
echo "📁 Creating .config and .zshrc in $USER_HOME"
mkdir -p "$USER_HOME/.config"
touch "$USER_HOME/.zshrc"
echo "# fresh test user setup on $(date)" >> "$USER_HOME/.zshrc"

# Set ownership
chown -R "$USERNAME:staff" "$USER_HOME/.config"
chown "$USERNAME:staff" "$USER_HOME/.zshrc"

echo "✅ User '$USERNAME' reset complete."
echo "ℹ️ You can now log in as '$USERNAME' with the password you provided."

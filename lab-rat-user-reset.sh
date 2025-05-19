#!/bin/bash

set -e

USERNAME="labrat"
FULLNAME="Lab Rat Test User"
PASSWORD="testpass"

echo "🔁 Resetting user: $USERNAME"

# Check if user exists
if id "$USERNAME" &>/dev/null; then
  echo "🗑️ Deleting existing user: $USERNAME"
  sudo sysadminctl -deleteUser "$USERNAME" -secure
  sudo rm -rf "/Users/$USERNAME"
else
  echo "ℹ️ No existing user found."
fi

# Create the user
echo "👤 Creating new admin user: $USERNAME"
sudo sysadminctl -addUser "$USERNAME" -fullName "$FULLNAME" -password "$PASSWORD" -admin

# Prevent macOS setup assistant from launching
sudo defaults write /Library/Preferences/com.apple.SetupAssistant DidSeeCloudSetup -bool TRUE
sudo defaults write /Library/Preferences/com.apple.SetupAssistant DidSeeSetup -bool TRUE
sudo defaults write /Library/Preferences/com.apple.SetupAssistant DidSeePrivacy -bool TRUE

# Create default files
USER_HOME="/Users/$USERNAME"
sudo mkdir -p "$USER_HOME/.config"
sudo touch "$USER_HOME/.zshrc"
sudo chown -R "$USERNAME:staff" "$USER_HOME"

# Add marker to .zshrc
echo "# fresh test user setup on $(date)" | sudo tee -a "$USER_HOME/.zshrc" > /dev/null
sudo chown "$USERNAME" "$USER_HOME/.zshrc"

echo "✅ User '$USERNAME' reset complete."
echo "ℹ️ You can now log in as '$USERNAME' with password: $PASSWORD"
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

echo "🗑️ Lab Rat User Deletion Script"
echo "================================"

# Find all labrat users
echo "🔍 Searching for labrat users..."

LABRAT_USERS=()
if [ "$IS_MACOS" = true ]; then
  # macOS: search Directory Services
  while IFS= read -r user; do
    if [[ "$user" == labrat* ]]; then
      LABRAT_USERS+=("$user")
    fi
  done < <(dscl . -list /Users | grep "^labrat")
else
  # Linux: search /etc/passwd
  while IFS=: read -r user _; do
    if [[ "$user" == labrat* ]]; then
      LABRAT_USERS+=("$user")
    fi
  done < /etc/passwd
fi

if [ ${#LABRAT_USERS[@]} -eq 0 ]; then
  echo "ℹ️ No labrat users found."
  exit 0
fi

echo "📋 Found ${#LABRAT_USERS[@]} labrat user(s):"
for user in "${LABRAT_USERS[@]}"; do
  echo "  - $user"
done

echo ""
read -r -p "❓ Delete all these users? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "❌ Cancelled."
  exit 0
fi

# Delete each user
for user in "${LABRAT_USERS[@]}"; do
  echo ""
  echo "🗑️ Deleting user: $user"
  
  if [ "$IS_MACOS" = true ]; then
    # macOS deletion
    # Remove from all groups first
    echo "  📤 Removing from groups..."
    dseditgroup -o edit -d "$user" -t user admin 2>/dev/null || true
    dseditgroup -o edit -d "$user" -t user _appserveradm 2>/dev/null || true
    dseditgroup -o edit -d "$user" -t user _appserverusr 2>/dev/null || true
    
    # Delete home directory first
    user_home=$(dscl . -read "/Users/$user" NFSHomeDirectory 2>/dev/null | awk '{print $2}' || echo "/Users/$user")
    if [ -d "$user_home" ]; then
      echo "  🏠 Removing home directory: $user_home"
      rm -rf "$user_home"
    fi
    
    # Delete user record
    echo "  👤 Removing user record..."
    dscl . -delete "/Users/$user" 2>/dev/null || true
    
  else
    # Linux deletion
    echo "  👤 Removing user and home directory..."
    userdel -r "$user" 2>/dev/null || true
  fi
  
  echo "  ✅ User $user deleted"
done

if [ "$IS_MACOS" = true ]; then
  echo ""
  echo "🔄 Flushing Directory Services cache..."
  dscacheutil -flushcache 2>/dev/null || true
  killall DirectoryService 2>/dev/null || true
  killall opendirectoryd 2>/dev/null || true
  
  echo ""
  echo "🚨 IMPORTANT: macOS Directory Services can be stubborn!"
  echo "📋 The users should be deleted, but may still appear in System Settings"
  echo "💡 A reboot will completely clear the Directory Services cache"
  echo ""
  read -r -p "🔄 Reboot now to ensure clean deletion? (y/N): " reboot_confirm
  
  if [[ "$reboot_confirm" =~ ^[Yy]$ ]]; then
    echo "🔄 Rebooting in 5 seconds... (Ctrl+C to cancel)"
    sleep 5
    reboot
  else
    echo "⚠️ Manual reboot recommended before creating new labrat users"
  fi
else
  echo ""
  echo "✅ All labrat users deleted successfully!"
fi

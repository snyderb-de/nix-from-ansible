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

echo "🔄 Complete Lab Rat Environment Reset"
echo "===================================="

# Remove any existing Nix installation
if [ -d /nix ]; then
  echo "🗑️ Removing existing Nix installation..."
  if [ -x /nix/nix-installer ]; then
    /nix/nix-installer uninstall --no-confirm || /nix/nix-installer uninstall || true
  else
    # Fallback manual cleanup for unknown install method
    echo "🔧 Performing manual Nix cleanup..."
    
    if [ "$IS_MACOS" = true ]; then
      # Stop and remove Nix daemon
      launchctl remove org.nixos.nix-daemon 2>/dev/null || true
      
      # Remove Nix users and groups
      dscl . -delete /Users/nixbld 2>/dev/null || true
      dscl . -delete /Groups/nixbld 2>/dev/null || true
      
      # Remove individual nixbld users (there might be multiple)
      echo "🧹 Cleaning up nixbld users..."
      for i in {1..32}; do
        if dscl . -read "/Users/nixbld$i" &>/dev/null; then
          dscl . -delete "/Users/nixbld$i" 2>/dev/null || true
        fi
      done
    else
      # Linux Nix cleanup
      systemctl stop nix-daemon 2>/dev/null || true
      systemctl disable nix-daemon 2>/dev/null || true
      
      # Remove nixbld users and group
      for i in {1..32}; do
        userdel "nixbld$i" 2>/dev/null || true
      done
      groupdel nixbld 2>/dev/null || true
    fi
    
    # Remove profile scripts
    rm -f /etc/profile.d/nix.sh /etc/paths.d/nix
    
    # Remove /nix with special handling for macOS
    if [ "$IS_MACOS" = true ]; then
      # On macOS, /nix might be a volume mount point
      diskutil unmount force /nix 2>/dev/null || true
      # Remove the synthetic.conf entry if it exists
      sed -i '' '/^nix/d' /etc/synthetic.conf 2>/dev/null || true
    fi
    
    # Try to remove /nix directory with better error handling
    if ! rm -rf /nix 2>/dev/null; then
      echo "⚠️ Could not remove /nix completely. Trying alternative methods..."
      # Use find to remove contents first
      find /nix -mindepth 1 -delete 2>/dev/null || true
      # Then try to remove the directory
      rmdir /nix 2>/dev/null || true
    fi
  fi
  
  # Verify removal
  if [ -d /nix ]; then
    echo "⚠️ Warning: /nix directory still exists after cleanup."
    if [ "$IS_MACOS" = true ]; then
      echo "📋 This is normal on modern macOS due to System Integrity Protection."
      echo "📱 The Nix volume has been unmounted, so Nix is effectively disabled."
      echo "💡 If you want to completely remove /nix, reboot your Mac and run:"
      echo "   sudo rm -rf /nix"
    fi
    echo ""
    echo "🎯 Continuing with user setup (Nix is disabled)..."
  else
    echo "✅ Nix installation removed successfully"
  fi
fi

# Delete existing labrat users
echo ""
echo "🗑️ Removing any existing labrat users..."
./lab-rat-delete.sh

echo ""
echo "👤 Creating new labrat user..."
./lab-rat-create.sh

echo ""
echo "✅ Complete lab rat environment reset finished!"
echo "🚀 Ready for clean testing!"

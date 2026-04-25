#!/bin/bash
set -e

# Ensure we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "Please run this script from the flutterm project root."
    exit 1
fi

echo "Building flutterm..."
flutter build linux --release

echo "Installing flutterm system-wide (requires sudo)..."
INSTALL_DIR="/opt/flutterm"
BIN_DIR="/usr/local/bin"
APP_DIR="/usr/share/applications"
ICON_DIR="/usr/share/icons/hicolor/512x512/apps"

sudo mkdir -p "$INSTALL_DIR"
sudo mkdir -p "$BIN_DIR"
sudo mkdir -p "$APP_DIR"
sudo mkdir -p "$ICON_DIR"

# Copy binary and data
sudo rm -rf "$INSTALL_DIR"/*
sudo cp -r build/linux/x64/release/bundle/* "$INSTALL_DIR/"

# Create a symlink to CLI
sudo ln -sf "$INSTALL_DIR/flutterm" "$BIN_DIR/flutterm"

# Copy icon
if [ -f "assets/icons/flutterm.png" ]; then
    sudo cp assets/icons/flutterm.png "$ICON_DIR/flutterm.png"
fi

# Create a .desktop file
sudo bash -c "cat <<EOF > $APP_DIR/flutterm.desktop
[Desktop Entry]
Version=1.0
Name=Flutterm
GenericName=Terminal Emulator
Comment=A flutter terminal emulator
Exec=$BIN_DIR/flutterm
Icon=flutterm
Terminal=false
Type=Application
Categories=System;TerminalEmulator;
EOF"

# Update desktop database
if command -v update-desktop-database &> /dev/null; then
    sudo update-desktop-database "$APP_DIR" || true
fi

# Update icon cache
if command -v gtk-update-icon-cache &> /dev/null; then
    sudo gtk-update-icon-cache -f -t /usr/share/icons/hicolor || true
fi

echo "Flutterm installed successfully!"
echo "You can now run 'flutterm' from the CLI or find it in your application launcher."

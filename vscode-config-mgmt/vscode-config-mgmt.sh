#!/bin/bash

# Script to backup and restore VS Code configuration

# --- Configuration ---
BACKUP_DIR="$HOME/Documents/vscode_backup"  # Directory to store backups

# Detect OS and set appropriate paths
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
else
    # Linux
    VSCODE_USER_DIR="$HOME/.config/Code/User"
fi

SETTINGS_FILE="$VSCODE_USER_DIR/settings.json"
KEYBINDINGS_FILE="$VSCODE_USER_DIR/keybindings.json"
JAVASCRIPT_SNIPPETS="$VSCODE_USER_DIR/snippets/javascript.json"
EXTENSIONS_FILE="$BACKUP_DIR/vscode_extensions.txt"

# --- Functions ---

backup_config() {
  echo "Backing up VS Code configuration to $BACKUP_DIR..."

  # Create backup directory if it doesn't exist
  mkdir -p "$BACKUP_DIR"

  # Backup settings
  if [ -f "$SETTINGS_FILE" ]; then
    cp "$SETTINGS_FILE" "$BACKUP_DIR/settings.json"
    echo "  - Settings backed up."
  else
    echo "  - Settings file not found: $SETTINGS_FILE"
  fi

  # Backup keybindings
  if [ -f "$KEYBINDINGS_FILE" ]; then
    cp "$KEYBINDINGS_FILE" "$BACKUP_DIR/keybindings.json"
    echo "  - Keybindings backed up."
  else
    echo "  - Keybindings file not found: $KEYBINDINGS_FILE"
  fi

  # Backup extensions list
  code --list-extensions > "$EXTENSIONS_FILE"
  echo "  - Extensions list backed up to $EXTENSIONS_FILE."

  # Backup JavaScript snippets (example)
  if [ -f "$JAVASCRIPT_SNIPPETS" ]; then
    cp "$JAVASCRIPT_SNIPPETS" "$BACKUP_DIR/javascript.json"
    echo "  - JavaScript snippets backed up."
  else
    echo "  - JavaScript snippets file not found: $JAVASCRIPT_SNIPPETS"
  fi

  echo "Backup complete."
}

restore_config() {
  echo "Restoring VS Code configuration from $BACKUP_DIR..."

  # Restore settings
  if [ -f "$BACKUP_DIR/settings.json" ]; then
    cp "$BACKUP_DIR/settings.json" "$SETTINGS_FILE"
    echo "  - Settings restored."
  else
    echo "  - Settings backup not found."
  fi

  # Restore keybindings
  if [ -f "$BACKUP_DIR/keybindings.json" ]; then
    cp "$BACKUP_DIR/keybindings.json" "$KEYBINDINGS_FILE"
    echo "  - Keybindings restored."
  else
    echo "  - Keybindings backup not found."
  fi

  # Restore extensions
  if [ -f "$EXTENSIONS_FILE" ]; then
    echo "  - Installing extensions from $EXTENSIONS_FILE..."
    cat "$EXTENSIONS_FILE" | xargs -L 1 code --install-extension
    echo "  - Extensions restored.  VS Code restart may be required."
  else
    echo "  - Extensions list backup not found."
  fi

  # Restore JavaScript snippets (example)
  if [ -f "$BACKUP_DIR/javascript.json" ]; then
    cp "$BACKUP_DIR/javascript.json" "$JAVASCRIPT_SNIPPETS"
    echo "  - JavaScript snippets restored."
  else
    echo "  - JavaScript snippets backup not found."
  fi
  echo "Restore complete."
}

# --- Main Script ---

if [ "$1" == "backup" ]; then
  backup_config
elif [ "$1" == "restore" ]; then
  restore_config
else
  echo "Usage: $0 [backup|restore]"
  exit 1
fi

exit 0

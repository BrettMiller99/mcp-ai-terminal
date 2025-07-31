#!/bin/bash
# AI-Terminal System-Wide Installation Script

set -e

# Configuration
INSTALL_DIR="$HOME/.local/bin"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create install directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

echo "🚀 Installing AI-Safe Terminal System..."

# Copy files
echo "📁 Copying files to $INSTALL_DIR"
cp "$SOURCE_DIR/ai-terminal" "$INSTALL_DIR/"
cp "$SOURCE_DIR/unified-terminal-system.sh" "$INSTALL_DIR/"
cp "$SOURCE_DIR/unified-terminal-system.ps1" "$INSTALL_DIR/"

# Make executable
chmod +x "$INSTALL_DIR/ai-terminal"
chmod +x "$INSTALL_DIR/unified-terminal-system.sh"

echo "✅ Files installed to $INSTALL_DIR"

# Check if directory is in PATH
if [[ ":$PATH:" == *":$INSTALL_DIR:"* ]]; then
    echo "✅ $INSTALL_DIR is already in PATH"
else
    echo "⚠️  $INSTALL_DIR is not in PATH"
    echo "Add this to your shell profile (~/.bashrc, ~/.zshrc, ~/.profile):"
    echo ""
    echo "export PATH=\"\$PATH:$INSTALL_DIR\""
    echo ""
    echo "Then reload your shell: source ~/.zshrc"
fi

# Test installation
echo ""
echo "🧪 Testing installation..."
if "$INSTALL_DIR/ai-terminal" help >/dev/null 2>&1; then
    echo "✅ Installation successful!"
    echo ""
    echo "Usage:"
    echo "  ai-terminal exec 'mvn clean test'    # From anywhere"
    echo "  ai-terminal context                  # Get terminal context"
    echo "  ai-terminal status                   # Check background commands"
else
    echo "❌ Installation test failed"
    exit 1
fi

echo ""
echo "🎉 AI-Safe Terminal System installed successfully!"
echo "   You can now use 'ai-terminal' from anywhere in your system."

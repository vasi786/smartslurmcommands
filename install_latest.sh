#!/usr/bin/env bash
set -e

echo "🔍 Fetching latest release tag for smartslurmcommands..."

LATEST=$(curl -s https://api.github.com/repos/vasi786/smartslurmcommands/releases/latest | grep tag_name | cut -d '"' -f 4)

if [ -z "$LATEST" ]; then
    echo "❌ Could not determine latest release tag."
    exit 1
fi

echo "📦 Latest release: $LATEST"
echo "⬇️  Cloning repository..."

git clone --quiet --depth 1 --branch "$LATEST" https://github.com/vasi786/smartslurmcommands.git

echo "📂 Entering scripts directory..."
cd smartslurmcommands/scripts

echo "⚙️  Running installer..."
chmod +x install.sh
./install.sh

echo "✅ smartslurmcommands installed successfully!"

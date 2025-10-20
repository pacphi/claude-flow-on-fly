#!/bin/bash
# Setup Message of the Day (MOTD) for Sindri
# Displays ASCII art banner when users SSH into the development environment

set -e

MOTD_FILE="/etc/motd"

echo "Setting up Sindri MOTD banner..."

cat > "$MOTD_FILE" << 'EOF'
   ███████╗██╗███╗   ██╗██████╗ ██████╗ ██╗
   ██╔════╝██║████╗  ██║██╔══██╗██╔══██╗██║
   ███████╗██║██╔██╗ ██║██║  ██║██████╔╝██║
   ╚════██║██║██║╚██╗██║██║  ██║██╔══██╗██║
   ███████║██║██║ ╚████║██████╔╝██║  ██║██║
   ╚══════╝╚═╝╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝╚═╝

    Forging Software with AI • Running on Fly.io
      https://github.com/pacphi/sindri

EOF

chmod 644 "$MOTD_FILE"

echo "✅ MOTD banner configured successfully"

#!/bin/bash

# ------------------------------------------------------------
# OpenVPN Manager Installer with WebSocket Bridge (Port 443)
# ------------------------------------------------------------

MANAGER_URL="https://raw.githubusercontent.com/noelrubio143/ovpn/refs/heads/main/openvpn-manager.sh"
INSTALL_PATH="/usr/local/bin/ovpn"
AUTH_CONF="/etc/openvpn/auth.conf"  # Path to store username and password
WEBSOCKIFY_PORT=443  # WebSocket port (standard HTTPS port)
OPENVPN_PORT=1194  # Default OpenVPN port
WEBSOCKIFY_PATH="/usr/local/bin/websockify"

echo "Installing OVPN Manager with WebSocket Support on Port $WEBSOCKIFY_PORT..."

# Check for root
if [[ "$EUID" -ne 0 ]]; then
    echo "Error: This script must be run as root."
    exit 1
fi

# Install websockify
echo "Installing Websockify..."
sudo apt update
sudo apt install -y python3-websockify

# Download OpenVPN Manager script
echo "Downloading manager script from $MANAGER_URL..."
curl -s -L "$MANAGER_URL" -o "$INSTALL_PATH"

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to download the script. Please check the URL."
    exit 1
fi

# Make OpenVPN Manager script executable
chmod +x "$INSTALL_PATH"

# Save OpenVPN credentials to a file
echo "Please provide your OpenVPN credentials."
read -p "Enter your OpenVPN username: " OVPN_USERNAME
read -s -p "Enter your OpenVPN password: " OVPN_PASSWORD
echo ""

echo "Saving credentials to $AUTH_CONF..."

# Create a directory if it doesn't exist
mkdir -p /etc/openvpn

# Store credentials securely in auth.conf
echo "username=$OVPN_USERNAME" > "$AUTH_CONF"
echo "password=$OVPN_PASSWORD" >> "$AUTH_CONF"

# Make the file readable only by root for security
chmod 600 "$AUTH_CONF"

# OpenVPN Manager installed successfully
echo "Success! OVPN Manager has been installed."
echo "Type 'ovpn' to start the installer or manage clients."
echo ""

# Ask to run Websockify on Port 443
echo "Do you want to set up WebSocket (Websockify) to forward OpenVPN traffic to Port $WEBSOCKIFY_PORT?"
read -p "[y/N]: " SETUP_WEBSOCKIFY

if [[ "$SETUP_WEBSOCKIFY" =~ ^[yY]$ ]]; then
    # Set up Websockify to forward OpenVPN traffic to WebSocket port 443
    echo "Setting up Websockify to forward OpenVPN traffic to WebSocket (port $WEBSOCKIFY_PORT)..."

    # Allow WebSocket port in the firewall
    echo "Opening WebSocket port ($WEBSOCKIFY_PORT) in the firewall..."
    sudo ufw allow $WEBSOCKIFY_PORT/tcp
    sudo ufw reload

    # Start Websockify to forward OpenVPN traffic to port 443 (WebSocket)
    echo "Starting Websockify on port $WEBSOCKIFY_PORT..."

    # Run Websockify as a background process
    sudo nohup websockify --web /usr/share/novnc $WEBSOCKIFY_PORT 127.0.0.1:$OPENVPN_PORT &

    # Check if Websockify is running
    if [[ $? -eq 0 ]]; then
        echo "Websockify started successfully on port $WEBSOCKIFY_PORT!"
    else
        echo "Error: Failed to start Websockify."
        exit 1
    fi
fi

# Automatically run it for the first time
read -p "Do you want to run the installer now? [y/N]: " RUN_NOW
if [[ "$RUN_NOW" =~ ^[yY]$ ]]; then
    "$INSTALL_PATH"
fi

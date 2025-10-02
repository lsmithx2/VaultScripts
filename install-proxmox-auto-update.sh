#!/bin/bash
# ============================================================
# NRFK Proxmox Auto Update Installer
# Downloads, installs, and schedules the update script
# ============================================================

set -e

# Define the URL of the update script
SCRIPT_URL="https://raw.githubusercontent.com/lsmithx2/VaultScripts/refs/heads/main/proxmox-auto-update.sh"
SCRIPT_PATH="/usr/local/bin/proxmox-auto-update.sh"

# Download the update script
echo "[*] Downloading the update script..."
curl -fsSL "$SCRIPT_URL" -o "$SCRIPT_PATH"

# Make the script executable
chmod +x "$SCRIPT_PATH"
echo "[*] Update script downloaded to $SCRIPT_PATH and made executable."

# Prompt for reboot time
read -rp "Enter the reboot time for updates (HH:MM, 24-hour format, e.g., 03:30): " reboot_time
if [[ ! "$reboot_time" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]; then
    echo "Invalid time format. Please use HH:MM 24-hour format."
    exit 1
fi

# Create systemd service
SERVICE_FILE="/etc/systemd/system/proxmox-auto-update.service"
cat << EOF > "$SERVICE_FILE"
[Unit]
Description=NRFK Proxmox Auto Update Service
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH
EOF

echo "[*] Systemd service created at $SERVICE_FILE"

# Create systemd timer
TIMER_FILE="/etc/systemd/system/proxmox-auto-update.timer"
cat << EOF > "$TIMER_FILE"
[Unit]
Description=Run NRFK Proxmox Auto Update daily at $reboot_time

[Timer]
OnCalendar=*-*-* $reboot_time:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

echo "[*] Systemd timer created at $TIMER_FILE"

# Enable and start the timer
systemctl daemon-reload
systemctl enable --now proxmox-auto-update.timer

echo
echo "[*] NRFK Proxmox Auto Update setup complete!"
echo "[*] Your server will automatically update and reboot daily at $reboot_time."

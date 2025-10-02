#!/bin/bash
# ============================================================
# NRFK Proxmox Auto Update Script
# Refreshes packages, installs updates, and schedules reboot
# ============================================================

set -e

echo "=========================================="
echo "       NRFK Proxmox Auto Update"
echo "=========================================="
echo

# Prompt for reboot time
read -rp "Do you want to schedule a reboot after updates? (Y/N) [Y]: " reboot_choice
reboot_choice="${reboot_choice:-Y}"

if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
    read -rp "Enter reboot time (HH:MM, 24-hour format) or 'now' to reboot immediately [now]: " reboot_time
    reboot_time="${reboot_time:-now}"
fi

# Update package lists
echo "[*] Updating package lists..."
apt update

# Upgrade all packages
echo "[*] Installing available updates..."
apt full-upgrade -y

# Optional autoremove and clean
echo "[*] Cleaning up unused packages..."
apt autoremove -y
apt clean

# Schedule reboot if requested
if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
    if [[ "$reboot_time" == "now" ]]; then
        echo "[*] Rebooting now..."
        reboot
    else
        # Schedule reboot at specific time using 'at'
        if ! command -v at &> /dev/null; then
            echo "[*] Installing 'at' package..."
            apt install at -y
            systemctl enable --now atd
        fi
        echo "[*] Scheduling reboot at $reboot_time..."
        echo "reboot" | at $reboot_time
        echo "[*] Reboot scheduled."
    fi
else
    echo "[*] Updates completed. Reboot not scheduled."
fi

echo "[*] Update process finished."

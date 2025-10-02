#!/bin/bash
# ============================================================
# NRFK Proxmox Auto Update Script
# Updates packages and reboots
# ============================================================

set -e

echo "[*] Updating package lists..."
apt update

echo "[*] Installing available updates..."
apt full-upgrade -y

echo "[*] Cleaning up unused packages..."
apt autoremove -y
apt clean

echo "[*] Rebooting system..."
reboot

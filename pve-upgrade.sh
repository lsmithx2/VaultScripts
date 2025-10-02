#!/bin/bash
# ============================================================
#  NRFK Proxmox VE 8 to 9 Upgrade Script
#  Automates the upgrade process from Proxmox VE 8 to 9
# ============================================================

set -e

echo "=========================================="
echo "     NRFK Proxmox VE 8 to 9 Upgrade"
echo "=========================================="
echo

# Helper prompt function
ask() {
    local prompt="$1"
    local default="$2"
    local response

    read -rp "$prompt [$default]: " response
    response="${response:-$default}"

    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# 1. Backup essential configurations
echo "[*] Backing up essential configurations..."
mkdir -p /root/pve-backups
cp -r /etc/pve /root/pve-backups/
cp /etc/network/interfaces /root/pve-backups/
cp /etc/resolv.conf /root/pve-backups/

# 2. Update system to the latest Proxmox VE 8.x
echo "[*] Updating system to the latest Proxmox VE 8.x..."
apt update && apt full-upgrade -y
pveversion

# 3. Run the upgrade check tool
echo "[*] Running the upgrade check tool..."
pve8to9 --full

# 4. Update APT sources to Debian Trixie
echo "[*] Updating APT sources to Debian Trixie..."
sed -i 's/bookworm/trixie/g' /etc/apt/sources.list
sed -i 's/bookworm/trixie/g' /etc/apt/sources.list.d/*.list

# 5. Update Proxmox VE repositories
echo "[*] Updating Proxmox VE repositories..."
if [ -f /etc/apt/sources.list.d/pve-enterprise.list ]; then
    sed -i 's/bookworm/trixie/g' /etc/apt/sources.list.d/pve-enterprise.list
else
    echo "deb http://download.proxmox.com/debian/pve trixie pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list
fi

# 6. Update package lists and upgrade to Proxmox VE 9
echo "[*] Updating package lists and upgrading to Proxmox VE 9..."
apt update && apt full-upgrade -y

# 7. Reboot the system
echo "[*] Rebooting the system..."
reboot

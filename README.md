# VaultScripts

**VaultScripts** is a collection of useful server and Proxmox automation scripts maintained by NRFK.  
It includes scripts for Proxmox setup, hardening, upgrades, networking, and more.  

This repository is designed to make managing Proxmox servers and Linux systems easier with secure, automated scripts.

---

## 🔹 Available Scripts

### 1. `proxmox-setup.sh`
**Purpose:** Interactive setup and hardening of a fresh Proxmox node.  
**Features:**
- Disable enterprise repository, enable no-subscription repo  
- Install security tools (`fail2ban`, `unattended-upgrades`, `logwatch`)  
- SSH hardening and sysctl tweaks  
- Optional IPv6 disable, firewall enable, subscription nag removal  
- Optional email notifications for updates and logs  
- Optional ZeroTier installation and network join  

**Usage:**
```bash
chmod +x proxmox-configurator.sh
sudo ./proxmox-configurator.sh
```

## 2. `pve-upgrade.sh`
**Purpose:** Automates the upgrade from Proxmox VE 8 to 9.
**Features:**
- Backup essential configs (/etc/pve, network, resolv.conf)
- Update Proxmox VE 8.x to latest version
- Run pve8to9 upgrade check tool
- Update APT sources to Debian Trixie and Proxmox VE 9 repos
- Full system upgrade and reboot
- 
**Usage:**
```bash
chmod +x pve-upgrade.sh
sudo ./pve-upgrade.sh
```

⚠️ Notes:
Backup all VMs and containers before upgrading
Ceph users must upgrade to Ceph Squid first
Test upgrades on non-production nodes if possible

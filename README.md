# VaultScripts

**VaultScripts** is a collection of useful server and Proxmox automation scripts maintained by NRFK.  
It includes scripts for Proxmox setup, hardening, upgrades, networking, and more.  

This repository is designed to make managing Proxmox servers and Linux systems easier with secure, automated scripts.

---

## 🔹 Available Scripts

### 1. `nrfk-proxmox-configurator.sh`
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
chmod +x nrfk-proxmox-configurator.sh
sudo ./nrfk-proxmox-configurator.sh

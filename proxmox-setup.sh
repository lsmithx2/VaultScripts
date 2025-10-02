#!/bin/bash
# ============================================================
#  NRFK Proxmox Configurator
#  Interactive Proxmox setup & hardening script
# ============================================================

set -e

echo "=========================================="
echo "     NRFK Proxmox Configurator"
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

# Ask for email
read -rp "Enter an email address for system reports (leave blank to skip): " ADMIN_EMAIL

# 1. Disable enterprise repository
echo "[*] Disabling Enterprise Repository..."
if [ -f /etc/apt/sources.list.d/pve-enterprise.list ]; then
    sed -i 's/^deb/#deb/g' /etc/apt/sources.list.d/pve-enterprise.list
fi

# 2. Enable no-subscription repository
echo "[*] Enabling No-Subscription Repository..."
cat <<EOF >/etc/apt/sources.list.d/pve-no-subscription.list
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF

# 3. Add Debian security updates
echo "[*] Ensuring Debian Security Updates are enabled..."
grep -q "security.debian.org" /etc/apt/sources.list || cat <<EOF >>/etc/apt/sources.list

# Debian Security Updates
deb http://security.debian.org/debian-security bookworm-security main contrib
deb http://ftp.debian.org/debian bookworm-updates main contrib
EOF

# 4. Update system
echo "[*] Updating system..."
apt update && apt -y full-upgrade

# 5. Install security tools
echo "[*] Installing security tools..."
apt install -y fail2ban unattended-upgrades apt-listchanges logwatch mailutils curl

# 6. Configure unattended upgrades
if ask "Enable unattended-upgrades for security updates?" "Y"; then
    dpkg-reconfigure -plow unattended-upgrades

    if [[ -n "$ADMIN_EMAIL" ]]; then
        echo "[*] Configuring unattended-upgrades to email $ADMIN_EMAIL..."
        sed -i "s|//Unattended-Upgrade::Mail \"\";|Unattended-Upgrade::Mail \"$ADMIN_EMAIL\";|" /etc/apt/apt.conf.d/50unattended-upgrades
    fi
fi

# 7. Fail2Ban for SSH
if ask "Enable Fail2Ban protection for SSH?" "Y"; then
    cat <<EOF >/etc/fail2ban/jail.local
[sshd]
enabled = true
port    = ssh
filter  = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
EOF
    systemctl enable fail2ban
    systemctl restart fail2ban
fi

# 8. Fail2Ban for Proxmox Web UI
if ask "Enable Fail2Ban protection for Proxmox Web UI (port 8006)?" "Y"; then
    cat <<'EOF' >/etc/fail2ban/filter.d/proxmox.conf
[Definition]
failregex = pveproxy\[.*authentication failure; rhost=<HOST> user=.* msg=.*
ignoreregex =
EOF

    cat <<EOF >>/etc/fail2ban/jail.local

[proxmox]
enabled = true
port    = 8006
filter  = proxmox
logpath = /var/log/daemon.log
maxretry = 5
bantime = 3600
EOF

    systemctl restart fail2ban
fi

# 9. SSH hardening
if ask "Disable root SSH login and password authentication?" "Y"; then
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/g' /etc/ssh/sshd_config
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/g' /etc/ssh/sshd_config
    systemctl restart ssh
fi

# 10. Sysctl hardening
if ask "Apply sysctl kernel/network hardening?" "Y"; then
    cat <<EOF >/etc/sysctl.d/99-proxmox-hardening.conf
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.tcp_syncookies = 1
EOF
    sysctl --system
fi

# 11. Disable IPv6
if ask "Disable IPv6 (if not needed)?" "N"; then
    cat <<EOF >/etc/sysctl.d/99-disable-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    sysctl --system
fi

# 12. Proxmox nag screen removal
if ask "Remove Proxmox subscription nag popup?" "Y"; then
    if [ -f /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js ]; then
        cp /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.bak
        sed -i "s/data.status !== 'Active'/false/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
        systemctl restart pveproxy
    fi
fi

# 13. Firewall
if ask "Enable Proxmox firewall at datacenter level?" "Y"; then
    pve-firewall enable
fi

# 14. Configure Logwatch email
if [[ -n "$ADMIN_EMAIL" ]]; then
    echo "[*] Configuring logwatch to email $ADMIN_EMAIL..."
    sed -i "s/^MailTo =.*/MailTo = $ADMIN_EMAIL/" /usr/share/logwatch/default.conf/logwatch.conf
    sed -i "s/^MailFrom =.*/MailFrom = logwatch@$(hostname -f)/" /usr/share/logwatch/default.conf/logwatch.conf
fi

# 15. Optional ZeroTier Installation
if ask "Install and configure ZeroTier?" "N"; then
    echo "[*] Installing ZeroTier..."
    curl -s https://install.zerotier.com | bash
    systemctl enable zerotier-one
    systemctl start zerotier-one

    read -rp "Enter ZeroTier Network ID to join: " ZT_NETWORK_ID
    if [[ -n "$ZT_NETWORK_ID" ]]; then
        zerotier-cli join "$ZT_NETWORK_ID"
        echo "[*] Joined ZeroTier network $ZT_NETWORK_ID"

        # Wait for connection to become active
        echo "[*] Waiting for ZeroTier to connect..."
        for i in {1..10}; do
            STATUS=$(zerotier-cli info | awk '{print $3}')
            if [[ "$STATUS" == "ONLINE" ]]; then
                echo "[*] ZeroTier is online."
                break
            fi
            sleep 2
        done

        # Ask for optional static IP assignment
        if ask "Assign a static IP on the ZeroTier network?" "N"; then
            read -rp "Enter the static IP (e.g., 10.147.17.10/24): " ZT_IP
            read -rp "Enter the ZeroTier interface name (default: zt$(zerotier-cli info | awk '{print $2}')): " ZT_IFACE
            ZT_IFACE=${ZT_IFACE:-zt$(zerotier-cli info | awk '{print $2}')}
            if [[ -n "$ZT_IP" ]]; then
                ip addr add "$ZT_IP" dev "$ZT_IFACE"
                echo "[*] Assigned static IP $ZT_IP to interface $ZT_IFACE"
            else
                echo "[!] No IP entered, skipping."
            fi
        fi
    else
        echo "[!] No network ID provided, skipping join."
    fi
fi

echo
echo "=========================================="
echo " NRFK Proxmox Configurator - Setup Complete"
echo "=========================================="

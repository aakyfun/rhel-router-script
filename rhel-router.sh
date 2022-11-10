#!/usr/bin/env bash

DEFAULTCOLOR='\033[0m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
msghead () {
        echo -e "${BOXCOLOR}[]${DEFAULTCOLOR} - $@"
}

#### CHECKS
#
if [ "$(whoami)" != "root" ]
then
        BOXCOLOR="$RED" msghead "Please run me as root, thanks. Exiting..."
        exit
fi
#
NM_NUM_CON=`nmcli --terse con show | wc -l`
if [ "${NM_NUM_CON}" != "2" ]
then
        BOXCOLOR="$RED" msghead "This script expects just two default NetworkManager connections."
        BOXCOLOR="$YELLOW" msghead "Please ensure you have one Internet and one LAN connection. Exiting..."
        exit
fi


#### DNSMASQ
#
BOXCOLOR="$YELLOW" msghead "Installing dnsmasq"
yum install -y dnsmasq > /dev/null 2>&1 && BOXCOLOR="$GREEN" msghead "Done!"
#
BOXCOLOR="$YELLOW" msghead "Installing dnsmasq static configuration"
echo "Backing up original dnsmasq.conf as dnsmasq.conf.old"
cp /etc/dnsmasq.conf /etc/dnsmasq.conf.old
echo "Writing new conf file"
cat > /etc/dnsmasq.conf <<EOF
user=dnsmasq
group=dnsmasq
interface=enp0s8
bind-dynamic
conf-dir=/etc/dnsmasq.d,.rpmnew,.rpmsave,.rpmorig
domain-needed
bogus-priv
no-resolv
server=8.8.8.8
local=/labnet/
listen-address=::1,127.0.0.1,10.0.0.1
expand-hosts
domain=labnet
dhcp-range=10.0.0.2,10.0.0.255,24h
dhcp-option=option:router,10.0.0.1
dhcp-authoritative
dhcp-leasefile=/var/lib/dnsmasq/dnsmasq.leases
EOF
#
BOXCOLOR="$YELLOW" msghead "Testing config"
dnsmasq --test && BOXCOLOR="$GREEN" msghead "Good!"
BOXCOLOR="$YELLOW" msghead "Adding an entry to /etc/hosts for your hostname"
if [ "$(grep -E "10.0.0.1.*$(hostname)" /etc/hosts | wc -l)" -eq "1" ]
then
        BOXCOLOR="$YELLOW" msghead "We already added the hostname to hosts"
else
        BOXCOLOR="$YELLOW" msghead "Adding hostname to hosts"
        echo -e "10.0.0.1\t$(hostname)" >> /etc/hosts
fi
BOXCOLOR="$YELLOW" msghead "Enabling and starting dnsmasq service"
systemctl enable --now dnsmasq && BOXCOLOR="$GREEN" msghead "Done!"


#### NETWORKMANAGER
#
BOXCOLOR="$YELLOW" msghead "Configuring LAN connection with static IPv4 and as non-default route"
BOXCOLOR="$YELLOW" msghead "Enabling and starting NetworkManager service"
systemctl enable --now NetworkManager
INET_IF=`ip route get 8.8.8.8 | grep dev | cut -d ' ' -f 5 | sed 's/\s//'`
BOXCOLOR="$YELLOW" msghead "Internet connected interface seems to be ${INET_IF}"
NM_INET_CON_UUID=`nmcli --terse con show | grep "${INET_IF}" | cut -d ':' -f 2`
NM_LAN_CON_UUID=`nmcli --terse con show | grep -v "${INET_IF}" | cut -d ':' -f 2`
BOXCOLOR="$YELLOW" msghead "The current Internet connection is: ${NM_INET_CON_UUID}"
BOXCOLOR="$YELLOW" msghead "The current LAN connection is: ${NM_LAN_CON_UUID}"
BOXCOLOR="$YELLOW" msghead "Giving these connections names: External and Internal"
nmcli con mod uuid ${NM_INET_CON_UUID} connection.id "External"
nmcli con mod uuid ${NM_LAN_CON_UUID} connection.id "Internal"
BOXCOLOR="$YELLOW" msghead "Applying settings to LAN connection"
nmcli con mod uuid ${NM_LAN_CON_UUID} ipv4.method manual ipv4.addresses '10.0.0.1/24' ipv4.never-default yes ipv6.method ignore && BOXCOLOR="$GREEN" msghead "Done!"


#### FIREWALLD
#
BOXCOLOR="$YELLOW" msghead "Configuring firewalld"
BOXCOLOR="$YELLOW" msghead "Setting default zone to internal"
firewall-cmd --set-default-zone internal
BOXCOLOR="$YELLOW" msghead "Adding DNS and DHCP service exceptions"
firewall-cmd --permanent --zone=internal --add-service={dns,dhcp}
BOXCOLOR="$YELLOW" msghead "Enabling IP Masquerading/Source Network Address Translation"
firewall-cmd --permanent --zone internal --add-masquerade
BOXCOLOR="$YELLOW" msghead "Reloading firewall configuration"
firewall-cmd --reload && BOXCOLOR="$GREEN" msghead "Done!"

#### ENABLE IPv4 FORWARDING
#
BOXCOLOR="$YELLOW" msghead "Enabling IPv4 forwarding in sysctl.d/ip4fw.conf"
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/ip4fw.conf

#### FINISHING
#
BOXCOLOR="$YELLOW" msghead "It is recommended you reboot, but you don't have to ;)"
BOXCOLOR="$GREEN" msghead "Thank you. Bye!"
exit

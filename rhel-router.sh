#!/usr/bin/env bash

#### CHECKS
#
if [ "$(whoami)" != "root" ]
then
        echo "Please run me as root, thanks. Exiting..."
        exit
fi
#
NM_NUM_CON=`nmcli --terse con show | wc -l`
if [ "${NM_NUM_CON}" != "2" ]
then
        echo "[*] This script expects just two default NetworkManager connections."
        echo "Please ensure you have one Internet and one LAN connection. Exiting..."
        exit
fi


#### DNSMASQ
#
echo "[*] Installing dnsmasq"
yum install -y dnsmasq > /dev/null 2>&1 && echo "Done!"
#
echo "[*] Installing dnsmasq static configuration"
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
echo "Testing config"
dnsmasq --test && echo "Good!"
echo "Adding an entry to /etc/hosts for your hostname"
#echo -e "10.0.0.1\t$(hostname)\n" >> /etc/hosts
if [ "$(grep -E "10.0.0.1.*$(hostname)" /etc/hosts | wc -l)" -eq "1" ]
then
        echo "We already added the hostname to hosts"
else
        echo "Adding hostname to hosts"
        echo -e "10.0.0.1\t$(hostname)" >> /etc/hosts
fi
echo "Enabling and starting dnsmasq service"
systemctl enable --now dnsmasq && echo "Done!"


#### NETWORKMANAGER
#
echo "[*] Configuring LAN connection with static IPv4 and as non-default route"
echo "Enabling and starting NetworkManager service"
systemctl enable --now NetworkManager
#INET_IF=`ip a | grep -E inet.*brd | awk -F ' ' '{ print $NF }'`
INET_IF=`ip route get 8.8.8.8 | grep dev | cut -d ' ' -f 5 | sed 's/\s//'`
echo "Internet connected interface seems to be ${INET_IF}"
NM_INET_CON_UUID=`nmcli --terse con show | grep "${INET_IF}" | cut -d ':' -f 2`
NM_LAN_CON_UUID=`nmcli --terse con show | grep -v "${INET_IF}" | cut -d ':' -f 2`
echo "The current Internet connection is: ${NM_INET_CON_UUID}"
echo "The current LAN connection is: ${NM_LAN_CON_UUID}"
echo "Giving these connections names: External and Internal"
nmcli con mod uuid ${NM_INET_CON_UUID} connection.id "External"
nmcli con mod uuid ${NM_LAN_CON_UUID} connection.id "Internal"
echo "Applying settings to LAN connection"
nmcli con mod uuid ${NM_LAN_CON_UUID} ipv4.method manual ipv4.addresses '10.0.0.1/24' ipv4.never-default yes ipv6.method ignore && echo "Done!"


#### FIREWALLD
#
echo "[*] Configuring firewalld"
echo "Setting default zone to internal"
firewall-cmd --set-default-zone internal
echo "Adding DNS and DHCP service exceptions"
firewall-cmd --permanent --zone=internal --add-service={dns,dhcp}
echo "Enabling IP Masquerading/Source Network Address Translation"
firewall-cmd --permanent --zone internal --add-masquerade
firewall-cmd --reload && echo "Done!"

#### ENABLE IPv4 FORWARDING
#
echo "[*] Enabling IPv4 forwarding in sysctl.d/ip4fw.conf"
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/ip4fw.conf

#### FINISHING
#
echo "It is recommended you reboot, but you don't have to ;)"
echo "Thank you. Bye!"
exit

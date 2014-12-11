#!/bin/bash

### Declare some variables
IPT=$(which iptables)

EXT_IF=$(/sbin/ip route | grep default | awk '{print $5}')
INT_IF=$(ip link show | grep "state UP" | grep -v $EXT_IF | awk '{print $2}' | cut -d':' -f1)

### List incoming and outgoing TCP & UDP ports
IN_TCP="53 80 443"
IN_UDP=""
OUT_TCP="22 53"
OUT_UDP="53 123"

### Set default chain policies
$IPT -P INPUT DROP
$IPT -P FORWARD DROP
$IPT -P OUTPUT DROP

### Delete all existing rules
$IPT -F
$IPT -X
$IPT -t nat -F
$IPT -t nat -X
$IPT -t mangle -F
$IPT -t mangle -X

### Allow loopback
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A OUTPUT -o lo -j ACCEPT

### Allow LAN connection
for eth in $INT_IF; do
	$IPT -A INPUT -i $eth -j ACCEPT
	$IPT -A OUTPUT -o $eth -j ACCEPT
done

### Allow current established and related connections
$IPT -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT 
$IPT -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT 

### Drop bad packages
$IPT -A INPUT -f -j DROP # Drop packages with incoming fragments
$IPT -A INPUT -p tcp --tcp-flags ALL ALL -j DROP # Drop incoming malformed XMAS packets
$IPT -A INPUT -p tcp --tcp-flags ALL NONE -j DROP # Drop all NULL packets
$IPT -A INPUT -p tcp ! --syn -m state --state NEW -j DROP # Drop all new connection are not SYN packets

### ICMP (PING) - Ping flood projection 1 per second
$IPT -A INPUT -p icmp -m limit --limit 5/s --limit-burst 5 -j ACCEPT
$IPT -A OUTPUT -p icmp -m limit --limit 5/s --limit-burst 5 -j ACCEPT
$IPT -A INPUT -p icmp -j DROP
$IPT -A OUTPUT -p icmp -j DROP

### Log and drop syn flooding
$IPT -N syn-flood
$IPT -A syn-flood -m limit --limit 100/second --limit-burst 150 -j RETURN
$IPT -A syn-flood -j LOG --log-prefix "SYN flood: "
$IPT -A syn-flood -j DROP

### Allow incoming SSH
$IPT -A INPUT -i $EXT_IF -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
$IPT -A OUTPUT -o $EXT_IF -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT

### Allow incoming TCP & UDP
for port in $IN_TCP; do
	$IPT -A INPUT -i $EXT_IF -p tcp --dport $port -m state --state NEW,ESTABLISHED -j ACCEPT
	$IPT -A OUTPUT -o $EXT_IF -p tcp --sport $port -m state --state ESTABLISHED -j ACCEPT
done

for port in $IN_TCP; do
	$IPT -A INPUT -i $EXT_IF -p udp --dport $port -m state --state NEW,ESTABLISHED -j ACCEPT
	$IPT -A OUTPUT -o $EXT_IF -p udp --sport $port -m state --state ESTABLISHED -j ACCEPT
done

### Allow outgoing TCP & UDP
for port in $OUT_TCP; do
	$IPT -A OUTPUT -o $EXT_IF -p tcp --dport $port -m state --state NEW,ESTABLISHED -j ACCEPT
	$IPT -A INPUT -i $EXT_IF -p tcp --sport $port -m state --state ESTABLISHED -j ACCEPT
done

for port in $OUT_UDP; do
	$IPT -A OUTPUT -o $EXT_IF -p tcp --dport $port -m state --state NEW,ESTABLISHED -j ACCEPT
	$IPT -A INPUT -i $EXT_IF -p tcp --sport $port -m state --state ESTABLISHED -j ACCEPT
done

### List rules
$IPT -L -v

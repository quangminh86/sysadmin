#!/bin/bash

# Declare some variables
IPT=$(which iptables)

EXT_IF=$(/sbin/ip route | grep default | awk '{print $5}')

# Set default chain policies
$IPT -P INPUT DROP
$IPT -P FORWARD DROP
$IPT -P OUTPUT DROP

# Delete all existing rules
$IPT -F
$IPT -X
$IPT -t nat -F
$IPT -t nat -X
$IPT -t mangle -F
$IPT -t mangle -X

# Allow loopback
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A OUTPUT -o lo -j ACCEPT

# Allow current established and related connections
$IPT -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT 
$IPT -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT 

# Drop packages with incoming fragments
$IPT -A INPUT -f -j DROP

# Drop incoming malformed XMAS packets
$IPT -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

# Drop all NULL packets
$IPT -A INPUT -p tcp --tcp-flags ALL NONE -j DROP

# ICMP (PING) - Ping flood projection 1 per second
$IPT -A INPUT -p icmp -m limit --limit 5/s --limit-burst 5 -j ACCEPT
$IPT -A OUTPUT -p icmp -m limit --limit 5/s --limit-burst 5 -j ACCEPT
$IPT -A INPUT -p icmp -j DROP
$IPT -A OUTPUT -p icmp -j DROP

# Make sure new incomping tcp connection are SYN packets; otherwise drop
$IPT -A INPUT -p tcp ! --syn -m state --state NEW -j DROP

# Log and drop syn flooding
$IPT -N syn-flood
$IPT -A syn-flood -m limit --limit 100/second --limit-burst 150 -j RETURN
$IPT -A syn-flood -j LOG --log-prefix "SYN flood: "
$IPT -A syn-flood -j DROP

# Allow incoming SSH
$IPT -A INPUT -i $EXT_IF -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
$IPT -A OUTPUT -o $EXT_IF -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT

# Allow outgoing DNS
$IPT -A OUTPUT -o $EXT_IF -p udp --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
$IPT -A INPUT -i $EXT_IF -p udp --sport 53 -m state --state ESTABLISHED -j ACCEPT
$IPT -A OUTPUT -o $EXT_IF -p tcp --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
$IPT -A INPUT -i $EXT_IF -p tcp --sport 53 -m state --state ESTABLISHED -j ACCEPT

# Allow outgoing SSH
$IPT -A OUTPUT -o $EXT_IF -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
$IPT -A INPUT -i $EXT_IF -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT

# Allow incoming HTTP
$IPT -A INPUT -i $EXT_IF -p tcp --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT
$IPT -A OUTPUT -o $EXT_IF -p tcp --sport 80 -m state --state ESTABLISHED -j ACCEPT

# List rules
$IPT -L -v

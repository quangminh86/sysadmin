#!/bin/bash

# Declare some variables
IPT=$(which iptables)
SPAMLIST="blockedip"
SPAMDROPMSG="BLOCKED IP DROP"
NET="any/0"
DNS="8.8.8.8 8.8.4.4"
SERV_TCP="25 53 80 443"
SERV_UDP="53 123"
HI_PORTS="1024:65535"
SSH_PORT="22"

EXT_IF=`/sbin/route | grep -i 'default' | awk '{print $8}'`
INT_IF="eth1"

EXT_IP=`/sbin/ifconfig $EXT_IF | grep "inet addr" | awk -F":" '{print$2}' | awk '{print $1}'`

[ -f blacklist.txt ] && BADIPS=$(egrep -v -E "^#|^$" blacklist.txt)

echo "Starting IPv4 Wall..."

# Delete all existing rules
$IPT -F
$IPT -X
$IPT -t nat -F
$IPT -t nat -X
$IPT -t mangle -F
$IPT -t mangle -X

# Set default chain policies
$IPT -P INPUT DROP
$IPT -P FORWARD DROP
$IPT -P OUTPUT DROP


# unlimited loopback
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A OUTPUT -o lo -j ACCEPT

# unlimited LAN
$IPT -A INPUT -i $INT_IF -j ACCEPT
$IPT -A OUTPUT -o $INT_IF -j ACCEPT

## Block IP
if [ -f blacklist.txt ];
then
# create a new iptables list
$IPT -N $SPAMLIST

for ipblock in $BADIPS
do
   $IPT -A $SPAMLIST -s $ipblock -j LOG --log-prefix "$SPAMDROPMSG"
   $IPT -A $SPAMLIST -s $ipblock -j DROP
done

$IPT -I INPUT -j $SPAMLIST
$IPT -I OUTPUT -j $SPAMLIST
$IPT -I FORWARD -j $SPAMLIST
fi

# Allow current established and related connections
$IPT -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
$IPT -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# Allow incoming SSH
$IPT -A INPUT -i $EXT_IF -p tcp --dport $SSH_PORT -m state --state NEW,ESTABLISHED -j ACCEPT
$IPT -A OUTPUT -o $EXT_IF -p tcp --sport $SSH_PORT -m state --state ESTABLISHED -j ACCEPT

# allow incomming ICMP ping pong stuff
$IPT -A INPUT -p icmp --icmp-type 8 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
$IPT -A OUTPUT -p icmp --icmp-type 0 -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow port 53 tcp/udp (DNS Server)
$IPT -A INPUT -p udp --dport 53 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
$IPT -A OUTPUT -p udp --sport 53 -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPT -A INPUT -p udp -m state --state NEW --dport 53 -j ACCEPT
$IPT -A INPUT -p tcp -m state --state NEW --dport 53 -j ACCEPT

$IPT -A INPUT -p tcp --destination-port 53 -m state --state NEW,ESTABLISHED,RELATED  -j ACCEPT
$IPT -A OUTPUT -p tcp --sport 53 -m state --state ESTABLISHED,RELATED -j ACCEPT

for entry in $DNS; do
	$IPT -A OUTPUT -o $EXT_IF -p udp -s $EXT_IP --sport $HI_PORTS -d $entry --dport 53 -m state --state NEW -j ACCEPT
	$IPT -A INPUT -i $EXT_IF -p udp -s $entry --sport 53 -d $EXT_IP --dport $HI_PORTS -m state --state ESTABLISHED -j ACCEPT
done

# Allow UDP service
for port in $SERV_UDP; do
	if test $port -eq 53
	then
		$IPT -A INPUT -i $EXT_IF -p udp -s $NET --sport $port -d $EXT_IP --dport $port -m state --state NEW,ESTABLISHED -j ACCEPT
		$IPT -A OUTPUT -o $EXT_IF -p udp -s $EXT_IP --sport $port -d $NET --dport $port -m state --state ESTABLISHED -j ACCEPT
	else
		$IPT -A INPUT -i $EXT_IF -p udp -s $NET --sport $HI_PORTS -d $EXT_IP --dport $port -m state --state NEW -j ACCEPT
		$IPT -A OUTPUT -o $EXT_IF -p udp -s $EXT_IP --sport $port -d $NET --dport $HI_PORTS -m state --state ESTABLISHED -j ACCEPT
	fi
done

# Allow TCP service
for port in $SERV_TCP; do
	$IPT -A INPUT -i $EXT_IF -p tcp --syn -s $NET --sport $HI_PORTS -d $EXT_IP --dport $port -m state --state NEW -j ACCEPT
	$IPT -A OUTPUT -o $EXT_IF -p tcp ! --syn -s $EXT_IP --sport $port -d $NET --dport $HI_PORTS -m state --state ESTABLISHED -j ACCEPT
	$IPT -A INPUT -i $EXT_IF -p tcp ! --syn -s $NET --sport $HI_PORTS -d $EXT_IP --dport $port -m state --state ESTABLISHED -j ACCEPT
done

# log everything else and drop - clean up rules
$IPT -A INPUT -j LOG
$IPT -A FORWARD -j LOG
$IPT -A INPUT -j DROP
$IPT -A INPUT -i $EXT_IF -d $EXT_IP -m limit --limit 1/s -j LOG --log-level 5 --log-prefix "BAD_INPUT: "
$IPT -A INPUT -i $EXT_IF -d $EXT_IP -j DROP
$IPT -A OUTPUT -o $EXT_IF -d $EXT_IP -m limit --limit 1/s -j LOG --log-level 5 --log-prefix "BAD_OUTPUT: "
$IPT -A OUTPUT -o $EXT_IF -d $EXT_IP -j DROP
$IPT -A FORWARD -i $EXT_IF -d $EXT_IP -m limit --limit 1/s -j LOG --log-level 5 --log-prefix "BAD_FORWARD: "
$IPT -A FORWARD -i $EXT_IF -d $EXT_IP -j DROP

exit 0
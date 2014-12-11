#!/bin/bash
IPT=/sbin/iptables
# Max connection in seconds
SECONDS=100
# Max connections per IP
BLOCKCOUNT=10
# default action can be DROP or REJECT
DACTION="DROP"
$IPT -A INPUT -p tcp --dport 80 -i eth0 -m state --state NEW -m recent --set
$IPT -A INPUT -p tcp --dport 80 -i eth0 -m state --state NEW -m recent --update --seconds ${SECONDS} --hitcount ${BLOCKCOUNT} -j ${DACTION}

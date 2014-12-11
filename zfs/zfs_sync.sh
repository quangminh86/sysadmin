#!/usr/bin/env bash

# set path environment
PATH="/usr/bin:/bin:/usr/sbin:/sbin"
HOME="/root/bin"

log="$HOME/zfssync.log"

# set source and destination
sdir="storage"
ddir="backup/storage"
dadr="root@10.0.0.30"

# snapshot name
hour1=$(date +%m%d_%H)
hour0=$(date +%m%d_%H --date="-1 hour")

snap1="storage@$hour1"
snap0="storage@$hour0"

# run it now
zfs snapshot $snap1
zfs send -i $snap0 $snap1 | ssh $dadr zfs recv -vdF $ddir

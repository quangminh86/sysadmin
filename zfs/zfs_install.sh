#!/usr/bin/env bash

### This script will install zfs filesystem on Ubuntu 14.04 LTS version ###

# Check if this is the ubuntu distro
if [ ! -f /etc/lsb-release ]; then
	echo "Please install on Ubuntu distro."
	exit
fi

if [ -f /etc/lsb-release ]; then
	. /etc/lsb-release
	version=`lsb_release --release | cut -f2`

	if [ $version != "14.04" ]; then
		echo "This Ubuntu version is not recommend. Please install Ubuntu Trusty 14.04 LTS"
		exit
	fi
fi

sudo apt-get install software-properties-common
sudo add-apt-repository ppa:zfs-native/stable
sudo apt-get update
sudo apt-get install -y ubuntu-zfs

modprobe zfs
lsmod | grep zfs

echo "Your system is ready for use zfs filesystem."


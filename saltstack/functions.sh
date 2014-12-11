#!/bin/bash

# -----------------------------------------------------
# Shell Script Functions
# -----------------------------------------------------

curtime=$(date +%H:%M:%S)

### echo color functions -----------------------------------------------------------

NC='\e[0m' # No Color

red='\e[0;31m'
blue='\e[0;34m'
green='\e[0;32m'
cyan='\e[0;36m'
yellow='\e[0;33m'


function echored() { echo -e "${red}$1${NC}"; }
function echoblue() { echo -e "${blue}$1${NC}"; }
function echogreen() { echo -e "${green}$1${NC}"; }
function echocyan() { echo -e "${cyan}$1${NC}"; }
function echoyellow() { echo -e "${yellow}$1${NC}"; }

### check if os is ubuntu or centos ------------------------------------------------
function os_detect() {
  if [ -f /etc/redhat-release ]
  then
    version=$(sed -rn 's/.*([0-9])\.[0-9].*/\1/p' /etc/redhat-release)
    if [ "$version" = 5 ]
    then
      echocyan "centos5"
      return 1
    elif [ "$version" = 6 ]
    then
      echocyan "centos6"
      return 1
    fi
  elif [ -f /etc/lsb-release ]
  then
    echocyan "ubuntu"
    return 0
  fi
}

### check if a file, directory is exist, variable is empty -------------------------
is_file_exist() {
  local f="$1"
  [[ -f "$f" ]] && return 0 || return 1
}

is_dir_exist() {
  local d="$1"
  [[ -d "$d" ]] && return 0 || return 1
}

is_var_empty() {
  local var="$1"
  [[ -z $var ]] && return 1 || return 0
}

### ask and answer Y or N function -------------------------------------------------
function ask() {
  while true; do
    if [ "${2:-}" = "Y" ]; then
      prompt="Y/n"
      default=Y
    elif [ "${2:-}" = "N" ]; then
      prompt="y/N"
      default=N
    else
      prompt="y/n"
      default=
    fi
    # Ask the question
    read -p "$1 [$prompt] " REPLY
    # Default?
    if [ -z "$REPLY" ]; then
      REPLY=$default
    fi
    # Check if the reply is valid
    case "$REPLY" in
      Y*|y*) return 0 ;;
      N*|n*) return 1 ;;
    esac
  done
}

<<comment 
if ask "Do you want to do such-and-such?"; then
  echo "Yes"
else
  echo "No"
fi
comment

### check if network connection to a server is ok
# check ping, ssh
# usage: check_network 192.168.1.1
function check_network() {
  local ipaddr="$1"
  echocyan "Running check network to $ipaddr"
  ping -q -w 1 -c 1 $ipaddr > /dev/null && echocyan ok || echored error
}

### function working with file or directory

# replace file.txt old new
function replace() {
  local file="$1"
  local old="$2"
  local new="$3"
  sed -i ‘s/$old/$new/g’ $file
}

#

### excute command from remote server ----------------------------------------------
# usage: remote_cmd 192.168.0.10 username password "df -h"
function remote_cmd() {
  local ipaddr="$1"
  local username="$2"
  local password="$3"
  local cmd="$4"
  sshpass -p $password ssh -o StrictHostKeyChecking=no -t $username@$ipaddr $cmd
}

### working with salt
# usage: install_salt 192.168.1.1 username password
function install_salt() {
  local ipaddr="$1"
  local username="$2"
  local password="$3"
  local file="devlist.txt"
  if ! is_file_exist $file; then
    touch $file
  fi

  remote_cmd $ipaddr $username $password "mount | grep ext | grep -v /boot" > $file

  list=$(cat $file | awk '{ print $1 }')
  array=( $list )

  root=${array[0]}
  data=${array[1]}
  if is_var_empty $data; then
    data=$root
  fi

  echogreen "Start install salt on $ipaddr ------------------------------------------"
  if ! is_file_exist "/usr/bin/wget"; then
    remote_cmd $ipaddr $username $password "sudo yum install -y wget"
  fi
  remote_cmd $ipaddr $username $password "wget dl.sohagame.vn/salt/salt.sh -O /tmp/salt.sh; sudo sh /tmp/salt.sh $hostname $root $data"
  remote_cmd $ipaddr $username $password "sudo /etc/init.d/salt-minion restart"
}

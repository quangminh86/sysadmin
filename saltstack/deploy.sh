#!/usr/bin/env bash

source functions.sh

### declare variables
host_list=""
counter=0

echogreen "======================================================================================================"
echogreen "================================ *** Welcome Soha Game AutoDeploy System *** ========================="
echogreen "======================================================================================================"

### input project id
echored "Project ID:"
read pid
mkdir -p $pid

project="/etc/nagios/objects/partner/$pid"
server=$pid".txt"

if ! is_file_exist $server; then
  echored "File $server is not exist. Please create it."
  exit
fi

echo "------------------------- $pid -------------------------" >> $keepass

for host in $( cat $server )
do 
  password=""
  IFS=',' read -a array <<< "$host"
  hostname=${array[0]}
  if [[ $hostname == *#* ]]
  then
      continue
  fi
  iplan=${array[1]}
  ipwan=${array[2]}
  if [[ ! -z ${array[3]} ]]; then password=${array[3]}; fi
  host_list+="$hostname, "
  file="$hostname.cfg"
  
  # update hostname/ipaddr to /etc/hosts
  echo "$iplan $hostname" >> /etc/hosts

  arr[$counter]=$file
  let counter=counter+1

  echo "======================================================================================================"
  echo "Install Salt Client on $hostname"
  echo "======================================================================================================"
  if ! check_network $iplan; then
    exit
  fi
  if [[ -z $password ]]; then
    sh tool/install_stalt.sh $hostname $iplan
  else 
    sh tool/install_stalt.sh $hostname $iplan $password
  fi

  echo "======================================================================================================"
  echo "AutoDeploy to $hostname"
  echo "======================================================================================================"

  sh tool/createfile.sh $hostname $iplan $ipwan $pid

  ### auto deploy with salt
  echo "Adding key -------------------------------------------------------------------------------------------"
  salt-key -y -d $hostname > /dev/null
  echo "Waiting for connection from client"; sleep 15
  if ! salt-key -L | grep $hostname > /dev/null; 
  then 
    echogreen "Pls waiting more ..."
    sleep 20
  fi
  if ! salt-key -L | grep $hostname > /dev/null; then
    echored "Can not find $hostname minion. Pls contact admin"
    exit
  fi
  salt-key -y -a $hostname; sleep 15
  if ! salt $hostname test.ping | grep True > /dev/null; then 
    echogreen "Pls waiting more ..." 
    sleep 20
  fi
  if ! salt $hostname test.ping | grep True > /dev/null; then 
    echored "Can not test.ping to $hostname. Pls contact admin." 
    exit
  fi

  echo "Install base packages --------------------------------------------------------------------------------"
  salt $hostname state.sls base
  echo "Install nagios ---------------------------------------------------------------------------------------"
  salt $hostname state.sls nagios
  echo "Install ganglia --------------------------------------------------------------------------------------"
  salt $hostname state.sls ganglia
  if [[ -z $password ]]; 
  then
    echo "Add user $pid --------------------------------------------------------------------------------------"
    pass=$(openssl rand -base64 12)
    if [ "$pid" != "local" ]; then
      salt $hostname user.add $pid
      cmdsudo="echo ""'$pid ALL=(ALL) NOPASSWD: ALL'"" >> /etc/sudoers"
      salt $hostname cmd.run "$cmdsudo"
      salt $hostname cmd.run "echo $pid:$pass | chpasswd"
    fi
    salt $hostname cmd.run "echo sohagame:$pass | chpasswd"
    echo "$hostname,$iplan,$ipwan,$pass" >> $keepass
  fi
done


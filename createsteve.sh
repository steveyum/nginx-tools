#!/usr/bin/env bash

# to debug or not debug
DEBUG="yes"
# ------------------
USER_NAME="steveyum"
USER_PASS="<password>"
# ------------------
WIFI_SSID="HANA"
WIFI_PASS="<password>"

MISSING_PKGS="git nfs-common vim-nox"
MORE_PKGS="dhcpcd5 ifplugd wpasupplicant"
sudo apt install $MISSING_PKGS

sudo wpa_passphrase $WIFI_SSID $WIFI_PASS >/etc/wpa_supplicant/wpa_supplicant.conf
sudo chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf

# ------------ create a user ------------------ #

get_home() {
  local result; result="$(getent passwd $1)" || return
  echo $result | cut -d : -f 6
}

if ! getent passwd $USER_NAME >> /dev/null; then 
	sudo useradd $USER_NAME -s /bin/bash -m
	echo "$USER_NAME:$USER_PASS" | sudo chpasswd
	
fi
# add to sudo list w/o passwd
sudo tee /etc/sudoers.d/01-$USER_NAME-nopasswd <<EOF>>/dev/null
$USER_NAME ALL=(ALL) NOPASSWD: ALL
EOF
# ------------- 

# create ssh private/public key pair
HOME_DIR=$(getent passwd $USER_NAME | cut -d: -f6)
echo "Generating public/private rsa key pair..."
SSH_DIR=$HOME_DIR/.ssh
sudo mkdir $SSH_DIR
sudo chown $USER_NAME:$USER_NAME $SSH_DIR
sudo -u $USER ssh-keygen -t rsa -N "" -f $SSH_DIR/id_rsa >>/dev/null
echo "Key pair created in $SSH_DIR/id_rsa"




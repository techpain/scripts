#!/bin/bash
# This script is designed to join an Ubuntu 16.04 instance to an active directory domain
# And give sudo privileges to the domain admins of the domain.

# Notes:
# CREDIT: http://www.wolffhaven45.com/blog/linux/join_ubuntu_workstation_windows_domain/
# To query your domain try: realm discover DOMAIN
# To login over ssh you need to use the following format: username@domain@hostnameORip

## IF NOT ROOT RUN THROUGH SUDO
(( EUID != 0 )) && exec sudo -- "$0" "$@"

# VARIABLES
DOMAIN="DOMAIN.WHATEVER"
ALLOWEDGROUP="domain\ admins"

# Install Required Packages
echo "Centos or Ubuntu?"
echo "c/u?"
read OPERATINGSYSTEM
if [ $OPERATINGSYSTEM = c ]; then
        yum -y install realmd samba samba-common oddjob oddjob-mkhomedir sssd ntpdate ntp
fi

if [ $OPERATINGSYSTEM = u ]; then
        apt -y install realmd sssd adcli libwbclient-sssd krb5-user sssd-tools samba-common packagekit samba-common-bin samba-libs
fi

# A popup will ask for the Default Kerberos version realm
# It's whatever you specified for the DOMAIN

# Create realmd.conf
touch /etc/realmd.conf
echo "[active-directory]" >> /etc/realmd.conf
echo "os-name = Ubuntu Linux" >> /etc/realmd.conf
echo "os-version = 16.04" >> /etc/realmd.conf
echo "" >> /etc/realmd.conf
echo "[service]" >> /etc/realmd.conf
echo "automatic-install = yes" >> /etc/realmd.conf
echo "" >> /etc/realmd.conf
echo "[users]" >> /etc/realmd.conf
echo "default-home = /home/%u" >> /etc/realmd.conf
echo "default-shell = /bin/bash" >> /etc/realmd.conf
echo "" >> /etc/realmd.conf
echo "[$DOMAIN]" >> /etc/realmd.conf
echo "user-principal = yes" >> /etc/realmd.conf

# Create Kerberos Ticket to join the domain with
echo "Domain Admin User:"
read DOMAINUSER

# Joing the actual Domain
realm --verbose join -U $DOMAINUSER $DOMAIN

## Set group rules
# First Deny all users from domain
realm deny -R $DOMAIN -a

# Second permit groups
realm permit -R $DOMAIN -g $ALLOWEDGROUP

# Grant SUDO access
echo "" >> /etc/sudoers
echo "# Added by domain join script" >> /etc/sudoers
echo "%$ALLOWEDGROUP@$DOMAIN ALL=(ALL:ALL) ALL" >> /etc/sudoers

# Setup new user home directory creation
echo "session required                   pam_mkhomedir.so skel=/etc/skel/ umask=0022" >> /etc/pam.d/common-session

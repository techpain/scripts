#!/bin/bash
## This script is designed to automate setting up a new router on Ubuntu 16.04

## CREDITS: https://debian-administration.org/article/23/Setting_up_a_simple_Debian_gateway

## IF NOT ROOT RUN THROUGH SUDO
(( EUID != 0 )) && exec sudo -- "$0" "$@"

## VARIABLES
NOW=$(date +%y-%m-%d-%H-%M-%S)
HERE=`pwd`
ALERTEMAIL=user@email.com
MAILSERVER=yourmailserver
SYSLOGSERVER=yoursyslogserver:port
NTPSERVER1=0.pool.ntp.org
NTPSERVER2=1.pool.ntp.org
export INSIDEBRIDGENAME=br0
export OUTSIDEIF=`ip route get 8.8.8.8 | awk '{print $5}' | tr -d '\n'`
export INSIDEIF=`ifconfig -s -a | awk '{print $1}' | grep -v 'Iface' | grep -v 'lo' | grep -v '$INSIDEBRIDGENAME' | grep -v '$OUTSIDEIF' | head -n1`


DOMAIN=Yourdomain.whatever.stuff

# INSIDE INTERFACE NETWORK CONFIG
INADDRESS=10.42.12.1
INNETWORK=10.42.12.0
INNETMASK=255.255.255.0
INBROADCAST=10.42.12.255

# DHCP CONFIG
INSIDEDHCPRANGESTART=10.42.12.100
INSIDEDHCPRANGEEND=10.42.12.199
INSIDEDHCPMASK=255.255.255.0
INSIDEDHCPLEASETIME=12h
OUTSIDEDNS1=8.8.8.8
OUTSIDEDNS2=8.8.4.4

## Create Log
touch $HERE/router-setup-log-$NOW.log
echo "SETP 01 You made it past the variables" >> $HERE/router-setup-log-$NOW.log

## UPDATE SYSTEM
apt-get update && apt-get -y dist-upgrade
echo "STEP 02 Updates were successful" >> $HERE/router-setup-log-$NOW.log

## INSTALL SERVER PACKAGES
# Extras: fail2ban rsyslog
apt-get -y install htop iotop screen tmux iperf openssh-server ntp git wget unzip mtr \
dnsutils dnsmasq bridge-utils telnet curl ssmtp expect fail2ban docker.io
echo "STEP 03 Your specified packages installed" >> $HERE/router-setup-log-$NOW.log

## SETUP NEW USER DEFAULTS
# SET HISTORY SIZE
sed -i 's/HISTSIZE=1000/HISTSIZE=9999/g' /etc/skel/.bashrc
# SET PROMPT STYLE
if ! grep -q 'PROMPT' '/etc/skel/.bashrc' ; then
echo "#PROMPT SET BY SCRIPT" >> /etc/skel/.bashrc
echo "PS1=\"\[\033[35m\]\t\[\033[m\]-\[\033[36m\]\u\[\033[m\]@\[\033[32m\]\h:\[\033[33;1m\]\w\[\033[m\]\$ \"" >> /etc/skel/.bashrc
fi
echo "STEP 04 New user defaults setup" >> $HERE/router-setup-log-$NOW.log

## SECURE SHARED MEMORY
if ! grep -q '/run/shm' '/etc/fstab' ; then
echo "tmpfs     /run/shm     tmpfs     defaults,noexec,nosuid     0     0" >> /etc/fstab
fi
echo "STEP 05 Shared memory has been secured" >> $HERE/router-setup-log-$NOW.log

## SETUP EMAIL STUFF
cp /etc/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf.original
sed -i 's/root=postmaster/root=$ALERTEMAIL/g' /etc/ssmtp/ssmtp.conf
sed -i 's/mailhub=mail/mailhub=$MAILSERVER/g' /etc/ssmtp/ssmtp.conf
echo "STEP 06 SSMTP has been configured" >> $HERE/router-setup-log-$NOW.log

## SETUP NTP
#sed -i 's/pool 0.ubuntu.pool.ntp.org iburst/pool $NTPSERVER1/g' /etc/ntp.conf
#sed -i 's/pool 1.ubuntu.pool.ntp.org iburst/pool $NTPSERVER2/g' /etc/ntp.conf
#sed -i 's/pool 2.ubuntu.pool.ntp.org iburst/#/g' /etc/ntp.conf
#sed -i 's/pool 3.ubuntu.pool.ntp.org iburst/#/g' /etc/ntp.conf
systemctl restart ntp
echo "STEP 07 NTP has been setup" >> $HERE/router-setup-log-$NOW.log

## SETUP IP FORWARDING
sysctl -w net.ipv4.ip_forward=1
echo "STEP 08 IP forwarding has been enabled" >> $HERE/router-setup-log-$NOW.log

## SETUP BRIDGE FOR INSIDE INTERFACE
mv /etc/network/interfaces /etc/network/interfaces-$NOW.bak
touch /etc/network/interfaces
echo "## CREATED BY ROUTERSCRIPT on $NOW" >> /etc/network/interfaces
echo "" >> /etc/network/interfaces
echo "# The loopback network interface" >> /etc/network/interfaces
echo "auto lo" >> /etc/network/interfaces
echo "iface lo inet loopback" >> /etc/network/interfaces
echo "" >> /etc/network/interfaces
echo "# The OUTSIDE interface" >> /etc/network/interfaces
echo "auto $OUTSIDEIF" >> /etc/network/interfaces
echo "iface $OUTSIDEIF inet dhcp" >> /etc/network/interfaces
echo "" >> /etc/network/interfaces
echo "# The INSIDE bridge device" >> /etc/network/interfaces
echo "auto $INSIDEBRIDGENAME" >> /etc/network/interfaces
echo "iface $INSIDEBRIDGENAME inet static" >> /etc/network/interfaces
echo "  bridge_ports $INSIDEIF" >> /etc/network/interfaces
echo "  address $INADDRESS" >> /etc/network/interfaces
echo "  network $INNETWORK" >> /etc/network/interfaces
echo "  netmask $INNETMASK" >> /etc/network/interfaces
echo "  broadcast $INBROADCAST" >> /etc/network/interfaces
echo "  bridge_maxwait 0" >> /etc/network/interfaces
echo "STEP 09 Interfaces file has been setup" >> $HERE/router-setup-log-$NOW.log

## SETUP IPTABLES
# delete all existing rules.
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X

# Always accept loopback traffic
iptables -A INPUT -i lo -j ACCEPT

# Allow established connections, and those not coming from the outside
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m state --state NEW -i ! $INSIDEBRIDGENAME -j ACCEPT
iptables -A FORWARD -i $INSIDEBRIDGENAME -o $OUTSIDEIF -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow outgoing connections from the LAN side.
iptables -A FORWARD -i $OUTSIDEIF -o $INSIDEBRIDGENAME -j ACCEPT

# Masquerade.
iptables -t nat -A POSTROUTING -o $INSIDEBRIDGENAME -j MASQUERADE

# Don't forward from the outside to the inside.
iptables -A FORWARD -i $INSIDEBRIDGENAME -o $INSIDEBRIDGENAME -j REJECT

iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT

# Allow webserver
iptables -A INPUT -i $INSIDEBRIDGENAME -p tcp --dport 80 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT

# Allow DNS
iptables -A INPUT -i $INSIDEBRIDGENAME -p udp --dport 53 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT

# Allow DHCP
iptables -A INPUT -i $INSIDEBRIDGENAME -p udp --dport 67 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -i $INSIDEBRIDGENAME -p udp --dport 68 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT

# Save Rules
iptables-save
service iptables restart

echo "STEP 10 IPtables has been configured" >> $HERE/router-setup-log-$NOW.log

# Restart Networking
systemctl restart networking
echo "STEP 11 Networking has been restarted" >> $HERE/router-setup-log-$NOW.log

# DNSMASQ SETUP
mv /etc/dnsmasq.conf /etc/dnsmasq-$NOW.bak
touch /etc/dnsmasq.conf
echo "domain-needed" >> /etc/dnsmasq.conf
echo "except-interface=$INSIDEBRIDGENAME" >> /etc/dnsmasq.conf
echo "no-dhcp-interface=$INSIDEBRIDGENAME" >> /etc/dnsmasq.conf
echo "local=/$DOMAIN/" >> /etc/dnsmasq.conf
echo "domain=$DOMAIN" >> /etc/dnsmasq.conf
echo "dhcp-leasefile=/etc/dhcp.leases" >> /etc/dnsmasq.conf
echo "dhcp-range=$INSIDEDHCPRANGESTART,$INSIDEDHCPRANGEEND,$INSIDEDHCPMASK,$INSIDEDHCPLEASETIME" >> /etc/dnsmasq.conf
echo "dhcp-authoritative" >> /etc/dnsmasq.conf
echo "dhcp-option=option:router,0.0.0.0" >> /etc/dnsmasq.conf
echo "dhcp-option=option:dns-server,0.0.0.0" >> /etc/dnsmasq.conf
echo "dhcp-option=option:ntp-server,0.0.0.0" >> /etc/dnsmasq.conf
echo "dhcp-option=option:domain-search,$DOMAIN" >> /etc/dnsmasq.conf
echo "no-resolv" >> /etc/dnsmasq.conf
echo "server=$OUTSIDEDNS1" >> /etc/dnsmasq.conf
echo "server=$OUTSIDEDNS2" >> /etc/dnsmasq.conf
echo "dhcp-option=vendor:MSFT,2,1i" >> /etc/dnsmasq.conf
systemctl restart dnsmasq
systemctl enable dnsmasq

echo "STEP 12 DNSMASQ is setup" >> $HERE/router-setup-log-$NOW.log

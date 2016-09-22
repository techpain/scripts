#!/bin/bash
## The Purpose of this script is to streamline setup and configuration of new Ubuntu 16.04 systems.

## VARIABLES
ALERTEMAIL=YOURADMINEMAIL@YOURDOMAIN.WHATEVER
MAILSERVER=YOURMAILSERVER
SYSLOGSERVER=YOURSYSLOGSERVER:PORT
NTPSERVER1=YOURTIMESERVER1
NTPSERVER2=YOURTIMESERVER2

## IF NOT ROOT RUN THROUGH SUDO
(( EUID != 0 )) && exec sudo -- "$0" "$@"

## UPDATE SYSTEM
apt-get update && apt-get dist-upgrade -y

## INSTALL SERVER PACKAGES
apt-get -y install htop iotop screen tmux iperf openssh-server ntp git wget unzip mtr \
dnsutils telnet curl ufw fail2ban ssmtp rsyslog expect docker.io


## INSTALL EXTRA DESKTOP PACKAGES
if [ "$1" = "--withdesktop" ]; then
        apt install chromium-desktop terminator filezilla i3 zenmap wireshark
fi

## SETUP NEW USER DEFAULTS
# SET HISTORY SIZE
sed -i 's/HISTSIZE=1000/HISTSIZE=9999/g' /etc/skel/.bashrc
# SET PROMPT STYLE
if ! grep -q 'PROMPT' '/etc/skel/.bashrc' ; then
echo "#PROMPT SET BY SCRIPT" >> /etc/skel/.bashrc
echo "PS1=\"\[\033[35m\]\t\[\033[m\]-\[\033[36m\]\u\[\033[m\]@\[\033[32m\]\h:\[\033[33;1m\]\w\[\033[m\]\$ \"" >> /etc/skel/.bashrc
fi

## SETUP DEFAULT FIREWALL RULES
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw --force enable
echo "You will need to manually allow any extra services through UFW after this script"

## SECURE SHARED MEMORY
if ! grep -q '/run/shm' '/etc/fstab' ; then
echo "tmpfs     /run/shm     tmpfs     defaults,noexec,nosuid     0     0" >> /etc/fstab
fi

## SETUP EMAIL STUFF
cp /etc/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf.original
sed -i 's/root=postmaster/root=$ALERTEMAIL/g' /etc/ssmtp/ssmtp.conf
sed -i 's/mailhub=mail/mailhub=$MAILSERVER/g' /etc/ssmtp/ssmtp.conf
systemctl restart fail2ban

## SETUP TRIPWIRE

## SETUP SYSLOG FORWARDING
touch /etc/rsyslog.d/loghost.conf
if ! grep -q '@' '/etc/rsyslog.d/loghost.conf' ; then
echo "*.*  @@$SYSLOGSERVER" >> /etc/rsyslog.d/loghost.conf
fi
systemctl restart rsyslog

## SETUP NTP
sed -i 's/pool 0.ubuntu.pool.ntp.org iburst/pool $NTPSERVER1/g' /etc/ntp.conf
sed -i 's/pool 1.ubuntu.pool.ntp.org iburst/pool $NTPSERVER2/g' /etc/ntp.conf
sed -i 's/pool 2.ubuntu.pool.ntp.org iburst/#/g' /etc/ntp.conf
sed -i 's/pool 3.ubuntu.pool.ntp.org iburst/#/g' /etc/ntp.conf
systemctl restart ntp

## REBOOT
echo "Would you like to reboot now to finalize the changes?"
echo "y/n"
read REBOOT
if [$REBOOT = y ]; then
        shutdown -r now
else
        echo "All done, please reboot to finish setup"
fi
#EOF

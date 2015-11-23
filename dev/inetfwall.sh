#!/bin/sh

# File Name: /etc/mobinetgw/inetfwall.sh, /sbin/inetfwall.sh
# Author: Shuvo Dutta
# External File(s): NIL
# Required by File(s): NIL
# Creation Date: 14-12-2013
# Modification Date: 20-10-2015
# Copyright: GNU/GPL
# Description: Configurable Internet Firewall Script

SCRIPTNAME="inetfwall.sh"
VERSION="v1.1"
DATE="20-10-2015"
PID="0"
ROOTUID="0"

CONFIGDIR="/etc/mobinetgw/"
FWALLBACKUP="fwall.rules.bkp"
LOGDIR="/var/log/mobinetgw/"
LOGFILE="inetfwall.log"
VPNFWALLLOGFILE="vpnfwall.log"

INET_IF="0"
LOCAL_IF="eth0"
VPN_IF="tun0"
AP_IF="wlan0"

LOCAL="1"
NAT="1"
SPIFWALL="1"
BLOCKICMP="1"
PROXY="0"
PORTFWD="0"
PORTFWDALL="0"
BLOCKALL="1"

PROXYPORTSFROM="80"
PROXYPORTSTO="8080"
IPCAMPORTS="9090"
TORRENTPORTS="6881:6999"
GNUTELLAPORTS="6346"
TESTPORT="32767"
ALLPORTS="1025:65535"
HOSTPORTS="1:1024"

LOCALNET="192.168.11.0/24"
LOCALROUTER="0.0.0.0"	# set it for a host for which you want incoming connection capability
TORRENTHOST="0.0.0.0"
GNUTELLAHOST="0.0.0.0"

# Exit Status
# 0: Normal
# 1: No Root Priviledge
# 2: Number of Arguments is less than 2
# 3: Invalid Option (Argument 2; $2)

#readconfig()
#{

#}

bkpfwall()
{
	printf "Backing Up Firewall Rules... "
	iptables-save > $CONFIGDIR$FWALLBACKUP
	printf "Done!!!\n"
}

rstrfwall()
{
	printf "Restoring Firewall Rules... "
	iptables-restore < $CONFIGDIR$FWALLBACKUP
	rm $CONFIGDIR$FWALLBACKUP
	printf "Done!!!\n"
}

# flush all the rules in all the chains in all the tables
flushfwall()
{
	iptables -t nat -F
	iptables -t nat -X
	iptables -t filter -F
	iptables -t filter -X
	iptables -t mangle -F
	iptables -t mangle -X
	#iptables -t raw -F
	#iptables -t raw -X
}

localen()
{
	# allow localloop
	iptables -t filter -A INPUT -i lo -j ACCEPT
	iptables -t filter -A OUTPUT -o lo -j ACCEPT

	# incoming ports on eth0 (lan) are not blocked, because the same host provides other services to lan (dhcp, dns, cups, ftp, ssh, vnc etc.).
	# accepts all incoming connections to local machine from eth0; i. e. lan
	iptables -t filter -A INPUT -i eth0 -d $LOCALNET -j ACCEPT
}

naten()
{
	# allow nat on INET_IF, incoming traffic on eth0; lan
	iptables -t nat -A POSTROUTING -o $INET_IF -j MASQUERADE
	#iptables -t filter -A FORWARD -d $LOCALNET -i eth0 -o eth0 -j ACCEPT
	iptables -t filter -A FORWARD -i eth0 -o $INET_IF -j ACCEPT
}

spien()
{
	iptables -t filter -A INPUT -i $INET_IF -m state --state ESTABLISHED,RELATED -j ACCEPT
}

blockicmp()
{
	# drop all ping request (icmp type 8) on $INET_IF
	iptables -t filter -A INPUT -i $INET_IF -p icmp --icmp-type echo-request -j DROP
}

# enable transparent proxy
proxyen()
{
	iptables -t nat -A PREROUTING -i eth0 -p tcp --dport $PROXYPORTSFROM -j REDIRECT --to-port $PROXYPORTSTO
}

portfwden()
{
	# torrents, gnutella & testport
	# tcp
	iptables -t nat -A PREROUTING -i $INET_IF -p tcp -m multiport --dport $TORRENTPORTS,$GNUTELLAPORTS,$TESTPORTS -j DNAT --to-destination $TORRENTHOST
	iptables -t filter -I FORWARD -p tcp -m multiport --dport $TORRENTPORTS,$GNUTELLAPORTS,$TESTPORTS -d $TORRENTHOST -j ACCEPT
	#iptables -t filter -I INPUT -p tcp --dport 6890 --tcp-flags rst rst -j DROP
	
	# udp
	iptables -t nat -A PREROUTING -i $INET_IF -p udp -m multiport --dport $TORRENTPORTS,$GNUTELLAPORTS,$TESTPORTS -j DNAT --to-destination $TORRENTHOST
	iptables -t filter -I FORWARD -p udp -m multiport --dport $TORRENTPORTS,$GNUTELLAPORTS,$TESTPORTS -d $TORRENTHOST -j ACCEPT
}

portfwdallen()
{
	iptables -t nat -A PREROUTING -i $INET_IF -p tcp --dport $ALLPORTS -j DNAT --to-destination $LOCALROUTER
	iptables -t filter -I FORWARD -p tcp --dport $ALLPORTS -d $LOCALNET -j ACCEPT
	# udp
	iptables -t nat -A PREROUTING -i $INET_IF -p udp --dport $ALLPORTS -j DNAT --to-destination $LOCALROUTER
	iptables -t filter -I FORWARD -p udp --dport $ALLPORTS -d $LOCALNET -j ACCEPT

	# block all port on the server from wild i.e. internet
	#iptables -t filter -A INPUT -i $INET_IF -p tcp --dport $HOSTPORTS -j DROP
	#iptables -t filter -A INPUT -i $INET_IF -p udp --dport $HOSTPORTS -j DROP
}

# block all other incoming ports on INET_IF; i. e. from internet
blockall()
{
	# allow current connections
	iptables -t filter -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT	
	iptables -t filter -A INPUT -i $INET_IF -j DROP
}

chkprvlg()
{
	if [ `id -u` -ne $ROOTUID ]
	then
		printf "This Script needs root priviledge to execute...\n"
		exit 1
	fi
}

chkprvlg
if [ $# -ne "2" ]
then
	printf "Usage: $SCRIPTNAME iface en|dis|reset\n"
	exit 2
fi
INET_IF=$1
FWALLBACKUP=$FWALLBACKUP"."$INET_IF
case $2
in
	en)
		bkpfwall
		flushfwall
		printf "Setting Up Firewall... "
		if [ $LOCAL -eq "1" ]
		then
			localen
		fi
		if [ $NAT -eq "1" ]
		then
			naten
		fi
		if [ $SPIFWALL -eq "1" ]
		then
			spien
		fi
		if [ $BLOCKICMP -eq "1" ]
		then
			blockicmp
		fi
		if [ $PROXY -eq "1" ]
		then
			proxyen
		fi
		if [ $PORTFWD -eq "1" ]
		then
			portfwden
		fi
		if [ $PORTFWDALL -eq "1" ]
		then
			portfwdallen
		fi
		if [ $BLOCKALL -eq "1" ]
		then
			blockall
		fi
		RTRNVAL="0"
		printf "Done!!!\n"
		echo `date` > $LOGDIR$LOGFILE
		;;
	dis)
		flushfwall
		rstrfwall
		RTRNVAL="0"
		rm -f $LOGDIR$VPNFWALLLOGFILE
		rm -f $LOGDIR$LOGFILE
		;;
	reset)
		flushfwall
		RTRNVAL="0"
		rm -f $LOGDIR$VPNFWALLLOGFILE
		rm -f $LOGDIR$LOGFILE
		;;
	*)
		printf "Invalid option $2...\n"
		RTRNVAL="3"
		;;
esac
exit $RTRNVAL

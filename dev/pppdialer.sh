#!/bin/sh

# # File Name: /etc/mobinetgw/pppdialaer.sh, /sbin/pppdialaer.sh (primary location)
# Author: Shuvo Dutta
# Required By (File(s)): /sbin/mobinetgw.sh
# External File(s): /etc/ppp/options, /etc/ppp/*.chat
# Copyright: GNU/GPL
# Creation Date: 19-12-2013
# Last Modification: 20-10-2015
# Baseline: NIL
# This script will control pppd for setting up ppp connections over 4g/3g/evdo/cdma usb modem.

PPPBINPATH="/usr/sbin"
PPPDAEMON="pppd"

VPN="0"

case $1
in
	connect)
		$PPPDAEMON
		#$PPPDAEMON debug
		#printf "dialer: connect: $?\n"
		exit $?
		;;
	disconnect)
		killall -s SIGINT $PPPDAEMON
		#killall -HUP $PPPDAEMON
		#printf "dialer: disconnect: $?\n"
		if [ $VPN -eq "1" ]
		then
			service openvpn stop frootvpn
		fi
		exit $?
		;;
	*)
		exit 31
		;;
esac

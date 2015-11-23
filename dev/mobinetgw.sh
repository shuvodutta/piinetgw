#!/bin/sh

# File: /etc/mobinetgw/mobinetgw.sh, /sbin/mobinetgw.sh (primary location)
# Author: Shuvo Dutta
# Required By (File(s)): NIL
# External File(s): pppdialer.sh, inetfwall.sh
# Copyright: GNU/GPL
# Creation Date: 19-12-2013
# Last Modification: $DATE
# Baseline: NIL
# This script will configure a raspberry pi running raspbian/minibian into a 4G/3G/EVDO/CDMA Internet Gateway for the network.

SCRIPTNAME="mobinetgw.sh"
VERSION="v0.1"
DATE="18-11-2015"

PID="0"
ROOTUID="0"

MODEM="/dev/ttyUSB0"

LOCKPATH="/var/lock/"
LOCKFILE="mobinetgw.lock"
LOGPATH="/var/log/"
LOGFILE="mobinetgw.log"
INETSTATFILE="inetstat.ppp0"
CONFIGDIR="/etc/mobinetgw/"
FWALLBACKUP="fwall.rules.bkp.mobinetgw"
RESOLVPATH="/etc/"
RESOLVFILE="resolv.conf"
RESOLVFILEBACKUP=$RESOLVFILE".bkp.mobinetgw"
CRONPATH="/etc/"
CRONTAB="crontab"
ENBFILE="mobinetgw.cron.en"
DIALER="./pppdialer.sh"
FIREWALL="./inetfwall.sh"
RESETFIREWALL="./inetfwallreset.sh"
CRONFILE="mobinetgw.crontab"
TMPFILE="mobinetgw.tmp"

FUNCRTRNVAL="0"
EXITSTATUS="255"

MODDNS="1"

RESOLVSTRING="nameserver "
LOCALDNS1="127.0.0.1"
CUSTOMDNS1="8.8.4.4"
CUSTOMDNS2="208.67.220.220"

DEFAULTGW="192.168.11.1"
DEFAULTGWPPP="10.64.64.64"
DEFAULTGWIF="eth0"
DEFAULTGWPPPIF="ppp0"
INETIFACE="ppp0"

INETHOST="8.8.8.8"
PINGCOUNT="3"
PINGTIMEOUT="1"
PINGSTAT="0"
PINGTARGET="0"

GREPFILTER="%"
CUTDELIM="' '"
CUTFIELD="6"
CUTDELIM2="%"
CUTFIELD2="1"
TRPARAM="[:space:]"
LOOPCOUNT="3"
SLEEPTIME="3"

PINGBIN="ping"
GREPBIN="grep"
CUTBIN="cut"
CATBIN="cat"
ROUTEBIN="route"
TRBIN="tr"
SLEEPBIN="sleep"

# Exit Status
# 0: Normal
# 1: No Root Priviledge
# 2: Lock-File Exsists
# 3: Modem i.e. Specified Serial Device in $MODEM is Not Present (option: up)
# 4: Modem i.e. Specified Serial Device in $MODEM is Not Present but Lock-File is OK (option: down)
# 5: Everything is OK but Lock-File is Not Present (option: down)
# 6: Modem i.e. Specified Serial Device in $MODEM is Not Present & Lock-File is also Not Present (option: down)
# 7: pppd has returned with error (option: up)
# 8: Internet Connectivity is OK (option: chkconn)
# 9: 
# 10: 
# 11: Internet Gateway is already down (option: down)
# 12: Connection Status Checking is not enabled (option: chkconn)

# External Binaries Used: id, ppp0, iptables, iptables-save, iptables-restore, ping, grep, cut, cat

printlog()
{
	
}

installmobinetgw()
{
	printf "Yet to be implemented. Please hang on...\n"
	EXITSTATUS="127"
}

removemobinetgw()
{
	printf "Yet to be implemented. Please hang on...\n"
	EXITSTATUS="127"
}

updatemobinetgw()
{
	printf "Yet to be implemented. Please hang on...\n"
	EXITSTATUS="127"
}

connectinet()
{
	echo `date` > $LOCKPATH$LOCKFILE
	PID=$$
	# to do: list USB Serial Modem devices from /dev (?)
	if [ -c $MODEM ]
	then
		cp $RESOLVPATH$RESOLVFILE $CONFIGDIR$RESOLVFILEBACKUP
		$CONFIGDIR$DIALER connect
		#sleep 3
		if [ $? -ne "0" ]
		then
			printf "Error!!! pppd exit status: $?\n"
			mv $CONFIGDIR$RESOLVFILEBACKUP $RESOLVPATH$RESOLVFILE
			rm $LOCKPATH$LOCKFILE
			EXITSTATUS="7"
		fi
		$CONFIGDIR$FIREWALL ppp0 en
		# to do: Firewall Script Status has to be checked.
		if [ $MODDNS -eq "1" ]
		then
			chkdns
		fi
	else
		printf "Error!!! $MODEM is not present...\n"
		rm $LOCKPATH$LOCKFILE
		# disable connection watch dog if enabled
		disablemobinetgw
		EXITSTATUS="3"
	fi
}

disconnectinet()
{
	if [ -c $MODEM ]
	then
		$CONFIGDIR$FIREWALL ppp0 dis
		# to do: iptables-restore Status has to be checked.
		$CONFIGDIR$DIALER disconnect
		if [ $? -ne "0" ]
		then
			printf "Error!!! pppd exit status: $?\n"
		fi
		if [ -f $CONFIGDIR$RESOLVFILEBACKUP ]
		then
			mv $CONFIGDIR$RESOLVFILEBACKUP $RESOLVPATH$RESOLVFILE
		else
			printf "Error!!! $CONFIGDIR$RESOLVFILEBACKUP does not exsist...\n"
		fi
		if [ -f $LOCKPATH$LOCKFILE ]
		then
			rm $LOCKPATH$LOCKFILE
			EXITSTATUS="0"
		else
			printf "Error!!! $LOCKPATH$LOCKFILE does not exsist...\n"
			EXITSTATUS="5"
		fi
	else
		# if modem has been failed/removed while the connection was up.
		printf "Error!!! $MODEM is not present...\n"
		$CONFIGDIR$FIREWALL ppp0 dis
		if [ -f $CONFIGDIR$RESOLVFILEBACKUP ]
		then
			mv $CONFIGDIR$RESOLVFILEBACKUP $RESOLVPATH$RESOLVFILE
		else
			printf "Error!!! $CONFIGDIR$RESOLVFILEBACKUP does not exsist...\n"
		fi
		if [ -f $LOCKPATH$LOCKFILE ]
		then
			rm $LOCKPATH$LOCKFILE
		else
			printf "Error!!! $LOCKPATH$LOCKFILE does not exsist...\n"
		fi
		disablemobinetgw
		EXITSTATUS="6"
	fi
}		

checkconnection()
{
	local PINGSTAT="0"
	local PINGTARGET="0"
	
	#echo `date`
	#printf "Checking Internet Connectivity...\n"
	PINGSTAT=`$PINGBIN -c 5 $INETHOST | $GREPBIN -i '%' | $CUTBIN -d' ' -f6 | $CUTBIN -d'%' -f1`
	#PINGSTAT=`$PINGBIN -W $PINGTIMEOUT -c $PINGCOUNT $INETHOST | $GREPBIN -i '%' | $CUTBIN -d$CUTDELIM -f$CUTFIELD | $CUTBIN -d'%' -f$CUTFIELD2`
	#printf ">>> $PINGSTAT\n"
	if [ "$PINGSTAT" != "" ]
	then
		if [ $PINGSTAT -gt $PINGTARGET ]
		then
			#printf "Connection Issue(s)!!!\n"
			FUNCRTRNVAL="0"
			printf "$FUNCRTRNVAL" > $LOGPATH$INETSTATFILE
		else
			#printf "Connection is Up...\n"
			FUNCRTRNVAL="1"
			printf "$FUNCRTRNVAL" > $LOGPATH$INETSTATFILE
		fi
	else
		FUNCRTRNVAL="0"
		printf "$FUNCRTRNVAL" > $LOGPATH$INETSTATFILE
	fi
	#echo `date`
}

chkdns()
{
	local TEMP="0"
	local COUNT="0"
	
	while [ $COUNT -lt $LOOPCOUNT ]
	do
		TEMP=`$ROUTEBIN | $GREPBIN -m 1 -i "$INETIFACE" | $TRBIN -s "$TRPARAM" | $CUTBIN -d' ' -f8`
		#printf "dbg: $TEMP\n"
		if [ "$TEMP" = "$INETIFACE" ]
		then
			TEMP=`$CATBIN $RESOLVPATH$RESOLVFILE | $GREPBIN -i "$CUSTOMDNS1" | $CUTBIN -d' ' -f2`
			#printf "dbg: $TEMP\n"
			if [ "$TEMP" != "$CUSTOMDNS1" ]
			then
				printf "Updating $RESOLVPATH$RESOLVFILE... "
				#printf "dbg: chkdns():  modifying dns...\n"
				echo $RESOLVSTRING$LOCALDNS1 > $CONFIGDIR$TMPFILE
				echo $RESOLVSTRING$CUSTOMDNS1 >> $CONFIGDIR$TMPFILE
				echo $RESOLVSTRING$CUSTOMDNS2 >> $CONFIGDIR$TMPFILE
				#$CATBIN $RESOLVPATH$RESOLVFILE >> $CONFIGDIR$TMPFILE
				mv $CONFIGDIR$TMPFILE $RESOLVPATH$RESOLVFILE
				printf "Done@`date`\n"
			fi
			break
		else
			$SLEEPBIN $SLEEPTIME
			COUNT=`expr $COUNT + 1`
		fi
	done
}

enablemobinetgw()
{
	if [ -f $CONFIGDIR$ENBFILE ]
	then
		printf "It's already enabled in cron...\n"
		EXITSTATUS="9"
	else
		printf "Scheduling in cron... "
		echo `date` > $CONFIGDIR$ENBFILE
		$CATBIN $CONFIGDIR$CRONFILE >> $CRONPATH$CRONTAB
		# to do: restart cron service (?)
		printf "Done!!!\n"
	fi
}

disablemobinetgw()
{
	if [ -f $CONFIGDIR$ENBFILE ]
	then
		printf "Disabling in cron... "
		$CATBIN $CRONPATH$CRONTAB | $GREPBIN -i -v 'mobinetgw' > $CONFIGDIR$TMPFILE
		rm $CRONPATH$CRONTAB
		mv $CONFIGDIR$TMPFILE $CRONPATH$CRONTAB
		rm $CONFIGDIR$ENBFILE
		printf "Done!!!\n"
	else
		printf "It's already disabled in cron...\n"
		EXITSTATUS="10"
	fi
}

chkprvlg()
{
	if [ `id -u` -ne $ROOTUID ]
	then
		printf "This Script needs root priviledge to execute...\n"
		EXITSTATUS="1"
	fi
}

chklock()
{
	if [ -f $LOCKPATH$LOCKFILE ]
	then
		FUNCRTRNVAL="1"
	else
		FUNCRTRNVAL="0"
	fi
}

# main
#printf "Mobile Internet Gateway Script for Raspberry Pi (on Raspbian/minibian). Version: $VERSION $DATE\n"
chkprvlg
case $1
in
	install)
		installmobinetgw
		FUNCRTRNVAL="-1"
		;;
	update)
		updatemobinetgw
		FUNCRTRNVAL="-1"
		;;
	remove)
		removemobinetgw
		FUNCRTRNVAL="-1"
		;;
	up)
		chklock
		if [ $FUNCRTRNVAL -eq "1" ]
		then
			printf "$LOCKFILE exists in $LOCKPATH.\nEither it is already setup as Mobile Internet Gateway\nor the lockfile could not be removed last time due to some error.\n$LOCKFILE should be removed manually for later case.\n"
			EXITSTATUS="2"
		else
			connectinet
		fi
		FUNCRTRNVAL="-1"
		;;
	down)
		chklock
		if [ $FUNCRTRNVAL -eq "1" ]
		then
			disconnectinet
		else
			printf "Mobile Internet Gateway is already down...\n"
			EXITSTATUS="11"
		fi
		FUNCRTRNVAL="-1"
		;;
	restart)
		chklock
		if [ $FUNCRTRNVAL -eq "1" ]
		then
			# to do: check exit status
			disconnectinet
			sleep 1
			connectinet
		else
			connectinet
		fi
		FUNCRTRNVAL="-1"
		;;
	chkconn)
		if [ -f $CONFIGDIR$ENBFILE ]
		then
			checkconnection
			#printf "dbg: main: 'chkconn'@`date`\n"
			if [ $FUNCRTRNVAL -eq "0" ]
			then
				echo `date`
				if [ -f $LOCKPATH$LOCKFILE ]
				then
					$CONFIGDIR$DIALER disconnect
					$CONFIGDIR$DIALER connect
					#disconnectinet
					#sleep 1
					#connectinet
				else
					$CONFIGDIR$DIALER connect
					#connectinet
				fi
			else
				EXITSTATUS="8"
			fi
		else
			printf "Internet Connection Checking is Not Enabled, Please Enable it First...\n"
			EXITSTATUS="12"
		fi
		if [ $MODDNS -eq "1" ]
		then
			chkdns
		fi
		FUNCRTRNVAL="-1"
		;;
	en)
		enablemobinetgw
		FUNCRTRNVAL="-1"
		;;
	dis)
		disablemobinetgw
		FUNCRTRNVAL="-1"
		;;
	*)
		printf "Usage: $SCRIPTNAME install | remove | update | up | down | restart | chkconn | en | dis\n"
		;;
esac
exit $EXITSTATUS

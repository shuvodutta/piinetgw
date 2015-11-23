#!/bin/sh

# /sbin/inetled.sh
# Author: Shuvo Dutta
# Required By (File(s)): NIL
# External File(s): NIL
# Copyright: GNU/GPL
# Creation Date: 29-06-2014
# Last Modification: 29-06-2014
# Baseline: NIL
# This script will drive a LED connected to GPIO17 on Raspberry Pi according to internet connectivity status.

GPIOSETUPDIR="/sys/class/gpio/"
GPIOSETUPFILE=$GPIOSETUPDIR"export"
GPIORELEASEFILE=$GPIOSETUPDIR"unexport"

GPIO17DIR=$GPIOSETUPDIR"gpio17/"
GPIO17IODIR=$GPIO17DIR"direction"
GPIO17VAL=$GPIO17DIR"value"
GPIO17STAT="0"

GPIOPIN="17"
GPIODIR="out"
LEDON="1"
LEDOFF="0"

ROOTUID="0"

INETHOST="8.8.8.8"

FUNCRTRNVAL="0"
EXITVAL="0"

ECHOBIN="echo"
PINGBIN="ping"
GREPBIN="grep"
CUTBIN="cut"
CATBIN="cat"

# Exit Status
# 0: Normal
# 1: No Root Priviledge

checkgpio17()
{
	#printf "dbg: checkgpio17():\n"
	if [ -f $GPIO17VAL ]
	then
		#printf "dbg: checkgpio17(): gpio17 is up...\n"
		FUNCRTRNVAL="1"
	else
		FUNCRTRNVAL="1"
		setupgpio17
		if [ $FUNCRTRNVAL -eq "1" ]
		then
			FUNCRTRNVAL="1"
		else
			FUNCRTRNVAL="0"
		fi
	fi
}

checkconnection()
{
	local PINGSTAT="0"
	local PINGTARGET="0"
	
	PINGSTAT=`$PINGBIN -c 5 $INETHOST | $GREPBIN -i '%' | $CUTBIN -d' ' -f6 | $CUTBIN -d'%' -f1`
	#printf "dbg: checkconnection(): PINGSTAT: $PINGSTAT\n"
	if [ "$PINGSTAT" != "" ]
	then
		#printf "dbg: checkconnection(): PINGSTAT: $PINGSTAT\n"
		if [ $PINGSTAT -gt $PINGTARGET ]
		then
			#printf "Connection Issue(s)!!!\n"
			FUNCRTRNVAL="0"
		else
			#printf "Connection is Up...\n"
			FUNCRTRNVAL="1"
		fi
	else
		FUNCRTRNVAL="0"
	fi
}

setupgpio17()
{
	#printf "dbg: setupgpio17():\n"
	$ECHOBIN $GPIOPIN > $GPIOSETUPFILE
	$ECHOBIN $GPIODIR > $GPIO17IODIR
	$ECHOBIN $LEDOFF > $GPIO17VAL
	FUNCRTRNVAL="1"
}

driveled()
{
	case $1
	in
		on)
			printf "switching on led @`date`\n"
			$ECHOBIN $LEDON > $GPIO17VAL
			;;
		off)
			printf "switching off led @`date`\n"
			$ECHOBIN $LEDOFF > $GPIO17VAL
			;;
		*)
			;;
	esac
	FUNCRTRNVAL="1"
}

chkprvlg()
{
	if [ `id -u` -ne $ROOTUID ]
	then
		printf "This Script needs root priviledge to execute...\n"
		exit 1
	fi
}

# main
chkprvlg

FUNCRTRNVAL="0"
checkgpio17
if [ $FUNCRTRNVAL -eq "1" ]
then
	FUNCRTRNVAL="0"
	checkconnection
	if [ $FUNCRTRNVAL -eq "1" ]
	then
		GPIO17STAT=`$CATBIN $GPIO17VAL`
		if [ $GPIO17STAT -ne $LEDON ]
		then
			driveled on
		fi
	else
		GPIO17STAT=`$CATBIN $GPIO17VAL`
		if [ $GPIO17STAT -ne $LEDOFF ]
		then
			driveled off
		fi
	fi
else
	printf "Error: Unable to access/setup GPIO$GPIOPIN @`date`\n"
fi
exit $EXITVAL

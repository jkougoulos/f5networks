#!/bin/bash
# F5 Networks - External Monitor: TLS SNI
# https://github.com/jkougoulos/F5networks
# Artiom Lichtenstein
# John Kougoulos
# v1.3, 05/11/2016 - Artiom Lichtenstein https://github.com/ArtiomL/f5networks
# v1.33, 26/03/2019 jkougoulos addins for allowing authentication, F5/Linux/Trace

# This monitor expects the following
# Variables:
# 	SNIHOST - the hostname of the SNI-enabled site
# 	URI  - the request URI
# 	RECV - the expected response
#	WWWUSER - the username (DOMAIN\\user)
#	WWWPASS - the password
#       XTRA - extra parameters for curl (eg --ntlm -v)
#	DEBUGSNI - produce debug logs
#	TRACESNI - create trace file
# Arguments:
# 	${3} - a unique ID for a distinctive PID filename (e.g. pool name)

# remove IPv6/IPv4 compatibility prefix (LTM passes addresses in IPv6 format)

echoerr() { echo "$@" 1>&2; }

if [ -f "/usr/bin/tmsh" ]    # we run on F5
then
	CURLBIN="curl-apd"
	PIDPATH="/var/run/"
	LOGBIN="logger -p local0.info"
else
	CURLBIN="curl"
	PIDPATH="/tmp/"
	LOGBIN="echoerr"
fi

TRACEPATH=$PIDPATH

IP=`echo ${1} | sed 's/::ffff://'`


if [ -z "${2}" ]
then
	PORT=${2}
fi

if [ -z "$PORT" ]
then
	PORT=443
fi

if [ -z "${3}" ]
then
	EMUID=${3}
fi

if [ -z "$EMUID" ]
then
	EMUID=$SNIHOST
fi

LOGPRE="CURL_TLS_SNI - $EMUID $$"

if [ -z "$TRACESNI" ]
then
	CURLOUT="/dev/null"
else
	CURLOUT="$TRACEPATH`basename ${0}`.${IP}_${PORT}_${EMUID}.log"
	(echo -n "$LOGPRE START: "; date +"%Y-%m-%d %H:%M:%S,%3N" ) >>$CURLOUT
fi

CURLTIMEOUT=10
CURLCONNTIMEOUT=2

#   EMUID=${3} perhaps not used in 11.6 maybe in later versions shows the pool name? or is it just the argument? for the moment expect for it in argument or env or default to SNIHOST
# it is kind of important to be unique across the box because we use it to create a unique PID file in sys

if [ ! -z "$DEBUGSNI" ]
then
	$LOGBIN "$LOGPRE INVOKED IP=$IP PORT=$PORT SNIHOST=$SNIHOST EMUID=$EMUID URI=$URI RECV=$RECV WWWUSER=$WWWUSER WWWPASS=$WWWPASS XTRA=$XTRA 0=$0 Params=/$*/"
fi


PIDFILE="$PIDPATH`basename ${0}`.${IP}_${PORT}_${EMUID}.pid"
# kill the last instance of this monitor if hung and log current PID
if [ -f $PIDFILE ]; then
	OLDPID=`cat $PIDFILE`
	$LOGBIN "$LOGPRE Previous instance runtime exceeded. Killing $OLDPID based on $PIDFILE"
	kill -9 $OLDPID > /dev/null 2>&1
fi
echo "$$" > $PIDFILE

# send the request and check for the expected response

if [ -z "$WWWUSER" ] || [ -z "$WWWPASS" ]
then
	USERPARAM= 
else
	USERPARAM="-u $WWWUSER:$WWWPASS"
fi

# Use --head instead of -X HEAD to end when response comes

$CURLBIN --head --connect-timeout $CURLCONNTIMEOUT -m $CURLTIMEOUT -s -k --noproxy "*" -i $XTRA $USERPARAM \
	 --resolve $SNIHOST:$PORT:$IP -H "Host: $SNIHOST" "https://$SNIHOST:$PORT$URI" 2>>$CURLOUT | tr -d "\r" | grep "$RECV" >>$CURLOUT 2>&1

if [[ $? -eq 0 ]]; then
	if [ ! -z "$DEBUGSNI" ]
	then
        	$LOGBIN "$LOGPRE $IP is UP"
	fi
	if [ ! -z "$TRACESNI" ]
	then
		(echo -n "$LOGPRE STOP: (UP) "; date +"%Y-%m-%d %H:%M:%S,%3N" ) >>$CURLOUT
	fi
	rm -f $PIDFILE
	# Any standard output stops the script from running. Clean up any temporary files before the standard output operation
	echo "UP"
	exit 0
fi

if [ ! -z "$DEBUGSNI" ]
then
	$LOGBIN "$LOGPRE $IP is DOWN"
fi

if [ ! -z "$TRACESNI" ]
then
	(echo -n "$LOGPRE STOP: (DOWN) "; date +"%Y-%m-%d %H:%M:%S,%3N" ) >>$CURLOUT
fi
rm -f $PIDFILE
exit 1

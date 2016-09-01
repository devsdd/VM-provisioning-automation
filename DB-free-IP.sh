#!/bin/bash
# Note: This script is diff. from other servers. This starts at 7.100 and increments and checks each IP in DB. it doesn't find the highest IP in DB. This is done to fill up gaps in the IP range.

MYSQL="mysql --host=<INSERT DB SERVER ADDRESS HERE> --user=root --database=VPS --execute="
NET=172.16.142
HOST=100        # host octet of desired IP address

while [ $HOST != 250 ]
	do
		ip=$($MYSQL"SELECT ip_address FROM guests WHERE ip_address LIKE \"$NET.$HOST%\";" -s -s)
		if [ -z "$ip" ]; then
			ping -c 1 $NET.$HOST > /dev/null 2>&1 || no_ping=1
			if [ $no_ping ] ; then
				echo $NET.$HOST
				exit 0
			else
				HOST=$(expr $HOST + 1)
				continue
			fi
		else
			HOST=$(expr $HOST + 1)
		fi
	done

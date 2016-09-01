#!/bin/bash

server_id=`cat /etc/vps_host_id`

for entry in `/usr/bin/mysql -h <INSERT DB SERVER ADDRESS HERE> -D VPS -e "SELECT hostname FROM guests WHERE state = 'On' AND hostname != 'Linux_Base_Img' AND hostname != 'WIN-BASE-IMG' AND server_id = \"$server_id\";" -s -s`
	do 
		for VM in `/usr/sbin/xm list | /bin/awk '{print $1}' | /bin/grep -v -f /usr/local/etc/vm_grep_patterns.txt`
			do
				if [ "$entry" = "$VM" ] ; then
					continue 2
				fi
			done
		owner=`/usr/bin/mysql -D VPS -e "SELECT owner FROM guests WHERE hostname = '$entry'" -s -s`
		/usr/sbin/xm create /etc/xen/$owner/conf/$entry.conf
		cat << EOF | /usr/sbin/sendmail -f do_not_reply@$(hostname) $owner@<INSERT YOUR DOMAIN NAME HERE>
From: do_not_reply@xen.server
To: $owner@<INSERT DOMAIN NAME HERE>
Subject: Your VPS has been started

Dear $owner,

	This is the VPS management script at $(hostname). Your VPS $entry has been started. You should be able to access it once it boots up in a few minutes.

- regards,
VPS Manager.
EOF

	done

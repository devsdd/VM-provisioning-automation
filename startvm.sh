#!/bin/bash
HOME=/etc/xen
for i in `ls $HOME | egrep '\.[a-z]{1,2}$'`
do
	for j in $HOME/$i/conf/*.conf
	do
		if [ -e $j ]
		then
		/usr/sbin/xm create $j
			while [ $? -ne 0 ]
			do
				echo "sleeping"
				sleep 2
				echo "VMstart $j"
			done

		fi
	done

done

#!/bin/bash

OLD_NET=192.168.7
NEW_NET=172.16.142
OLD_MASK=255.255.255.0
NEW_MASK=255.255.254.0
OLD_GATEWAY=$OLD_NET.1
NEW_GATEWAY=172.16.142.1

HOST=`ifconfig eth0 | awk '/inet addr/ {print $2}' | cut -d '.' -f 4`
OLD_IP=$OLD_NET.$HOST
NEW_IP=$NEW_NET.$HOST

echo $NEW_IP > /root/IP
sed -i "s/$OLD_MASK/$NEW_MASK/" /root/static || failed=1
sed -i "s/$OLD_IP/$NEW_IP/" /root/static || failed=1
sed -i "s/$OLD_GATEWAY/$NEW_GATEWAY/" /root/static || failed=1

mv -f /etc/sysconfig/network-scripts/ifcfg-eth0 /opt/ip_migration/ifcfg-eth0.bak || failed=1
cp -f /root/static /etc/sysconfig/network-scripts/ifcfg-eth0 || failed=1

service network restart || failed=1
ping -c 1 -q $NEW_GATEWAY || failed=1

# revert back in case anything failed
if [ "$failed" ] ; then
	echo $OLD_IP > /root/IP
	cp /opt/ip_migration/ifcfg-eth0.bak /root/static
	cp /opt/ip_migration/ifcfg-eth0.bak /etc/sysconfig/network-scripts/ifcfg-eth0
	echo -e "\nIP change process failed. Reverting back to old config...\n"
	exit 1
fi

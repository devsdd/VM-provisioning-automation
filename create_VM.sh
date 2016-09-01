#!/bin/bash

MASTER_CONF_DIR="/etc/xen"
REQUESTS_DIR="/tmp"
VM_DIR="/dev/virtual"
# base image was created with GB suffix, so have to use GB here.
size=50G
volume_group="/dev/virtual"
BYTES="10M"
server_id=`cat /etc/vps_host_id`

# do not allow common signals to kill/suspend the process as it could screw the disk image creation process
function sigcatch()
{
	echo -e "Attempt to kill VM creation script has been masked. Use \`kill (-KILL|-9)\` for manually killing the process.\n"
}

function abort()
{
# change this to send a email with the error message on each abort
	email "VPS Creation Script Aborted" "$1"
	exit 1
}

# action to take in case of non-critical or non-global errors
function keep_going()
{
	email "$1" "$2" "$3"
}

# no `email` command on the system now, but if that is added, this fn. may have to be renamed.
#function email()
#{
#	return 0
#}

function email()
{
# add the requestor ID to the to address of the sendmail command
	cat << EOF | /usr/sbin/sendmail $3@<INSERT DOMAIN NAME HERE>
From: do_not_reply@$(hostname)
Subject: $1

$2

- regards,
VPS manager.
EOF
}

# check if this script was invoked by root, or else abort
if [ "$EUID" -ne 0 ] ; then
	abort "VPS Creation script needs to be run as 'root' to create VPS."
fi

# Handle the common termination and suspension signals
trap sigcatch SIGHUP SIGINT SIGTERM SIGSTOP

# testing
for file in $(find $REQUESTS_DIR -mindepth 2 | egrep '(Linux|Windows)')
	do
		unset -v exists
# from here on, all errors must be treated as non-global as there may be
# multiple requests waiting, and others should not be aborted if one fails.
#		OS=$(echo $file | awk -F'/' '{print $(NF-1)}')
		OS=$(basename $(dirname $file))
		hostname=$(cat $file)
		user=$(basename $file | cut -d'.' -f 1-2)
		if [ "$OS" = "Linux" ] ; then
			base_img=$VM_DIR/linux
		else
			base_img="$VM_DIR/$OS"
		fi
		new_img=$VM_DIR/$user.$hostname.$(date +%d-%m-%y)
		disk=$(basename $new_img)
		conf_dir=$MASTER_CONF_DIR/$user/conf
		conf_file=$conf_dir/$hostname.conf
		failed=0
# create logical volume (make sure that the name is unique by combining the username and hostname)
		if [ ! -e $volume_group/$disk ] ; then
			/usr/sbin/lvcreate --size $size --name $disk $volume_group || failed=1
			if [ "$failed" = 1 ] ; then
#	MAIL failure to admin and requestor
				keep_going "VPS instance creation failed" "Failed to create logical volume $disk in volume group $volume_group for VPS disk image" $user
			continue
			fi
		else
			keep_going "VPS instance creation failed" "Logical volume $disk already exists in volume group $volume_group. Will not auto-overwrite. VPS creation has been aborted". $user
			exists=1
		fi
# copy the disk image
		if [ ! $exists ] ; then
			dd if=$base_img of=$new_img bs=$BYTES || failed=1
			if [ "$failed" = 1 ] ; then
#	MAIL failure to admin and requestor
				keep_going "VPS instance creation failed" "Failed to copy disk image $user.$hostname for VPS" $user
				/usr/sbin/lvremove --force $volume_group/$disk
				continue
			fi
# keep a separate directory for conf. files for each user, creating if not present
			if [ ! -d "$conf_dir" ] ; then
				mkdir -p $conf_dir
			fi
# copy the master conf. file to the user-specific conf. directory and append a '.conf' to its name.
			cp $MASTER_CONF_DIR/$OS $conf_file
# check whether the VM requested is GNU/Linux or Windows and replace the name and disk in the conf file
			if [ "$OS" = "Linux" ] ; then
				sed -i "s/Linux/$hostname/" $conf_file
				sed -i "s/dev\/virtual\/linux/dev\/virtual\/$disk/" $conf_file
				# update all the details in the conf. file:
				echo "hostname = \"$hostname\"" >> $conf_file
				ip=`/usr/local/bin/DB-free-IP.sh`
				echo "ip = \"$ip\"" >> $conf_file
				echo "netmask = \"255.255.254.0\"" >> $conf_file
				echo "gateway = \"172.16.142.1\"" >> $conf_file

			elif [ "$OS" = "Windows" ] ; then
				sed -i "s/Windows/$hostname/g" $conf_file
				sed -i "s/dev\/virtual\/$hostname/dev\/virtual\/$disk/g" $conf_file
			else keep_going "VPS instance creation failed" "Could not determine OS for $disk" $user
				continue
			fi
# Start the virtual instance		
			/usr/sbin/xm create $conf_file || failed=1
			if [ "$failed" = 1 ] ; then
#	MAIL failure to admin and requestor
				keep_going "VPS instance startup failed" "Failed to start virtual instance $user.$hostname".$(date +%d-%m-%y) $user
				continue
			else
# 	Mail success to requestor and admin and delete the request file
				email "VPS successfully created" "Congratulations, $user! Your $OS VPS with hostname $hostname has been successfully created and started. You will be provided with the access information shortly." "$user"
# and add the new guest details into the DB:
				 /usr/bin/mysql --host="INSERT DB SERVER ADDRESSS HERE" --user=root --database=VPS --execute="INSERT INTO guests VALUES(\"$user\", \"$hostname\", default, default, \"$OS\", \"On\", (SELECT NOW()), \"$server_id\", \"\");" && rm -f $file
			fi
		fi
	done

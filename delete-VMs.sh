#!/bin/sh

# check command-line usage:
if [ $# -ne 1 -o "$1" = "-h" -o "$1" = "--help" ] ; then
	cat << EOF
`tput smso`
Usage: $0 <VPS Name>
`tput rmso`
where <VPS Name> is the name as it appears in the output of the command \`xm list\`

EOF
	exit 1
fi

# check if this script was invoked by root, or else abort
if [ "$EUID" -ne 0 ] ; then
        echo -e "Error: VPS deletion script needs to be run as 'root'.\n"
	exit 2
fi

# do not allow common signals to kill/suspend the process as it could leave the deletion process in a half-done screwed state
function sigcatch()
{
        echo -e "Attempt to kill VM deletion script has been masked. Send a SIGKILL for manually killing the process.\n"
}         

VM=$1
admin="<INSERT YOUR NAME HERE>"
SERVERID=`cat /etc/vps_host_id`
MYSQL="mysql --host=<INSERT DB SERVER ADDRESS HERE> --user=root --database=VPS --execute="

# first check whether such a VPS actually exists
VPS=`$MYSQL"SELECT vm_name FROM guests WHERE vm_name = \"$VM\" AND server_id = \"$SERVERID\"" -s -s`
if [ -z "$VPS" ] ; then
	echo -e "No such VPS entry in the DB for this server. Exiting.\n"
	exit 3
fi

LV=`lvs | grep -m 1 '\.'$VM'\.' | awk '{print $1}'`
user=`echo $LV | cut -d '.' -f -2`
conf_file=/etc/xen/$user/conf/$VM.conf

if [ -z "$LV" ] ; then
	echo -e "Error: No corresponding Logical Volume found for $VPS. Aborting...\n"
	exit 1
elif [ -z "$user" ] ; then
	echo -e "Error: $VPS not associated with any valid user. Aborting...\n"
	exit 1
elif [ ! -f $conf_file ] ; then
	echo -e "Error: No corresponding config file found for $VPS. Aborting...\n"
	exit 1
fi

# check whether it is alive:
xm list $VPS > /dev/null 2>&1
result=$?

clear

if [ $result -eq 0 ] ; then
	echo -n "Shutting down the VPS $VPS... "
	xm destroy $VPS > /dev/null 2>&1 || failed=1
	if [ "$failed" ] ; then
		email $admin "VPS Deletion Failure" "Failed to Shutdown VPS $VPS belonging to $user. Aborting..."
		exit 4
	else
		echo -e "Success.\n"
	fi
fi

cat << EOF
`tput smso`
WARNING
`tput rmso`
You are about to delete the VPS $VPS owned by $user. This action is IRREVERSIBLE. Are you sure you want to do this?
(y|N):
EOF
read confirmation

# Handle the common termination and suspension signals AFTER reading the user input so user can CTRL^C at the prompt
trap sigcatch SIGHUP SIGINT SIGTERM SIGSTOP

case $confirmation in
	y | Y) echo -n "Removing Logical Volume /dev/virtual/$LV... "
		if [ "$LV" ] ; then
		lvremove -f /dev/virtual/$LV > /dev/null 2>&1 || failed=1
			if [ "$failed" ] ; then
				echo -e "Failed.\n"
				email $admin "VPS Deletion Failure" "Failed to remove logical volume $LV."
				exit 5
			else
				echo -e "Success.\n"
			fi
		fi
		echo -n "Removing config. file $conf_file... "
		rm -f $conf_file > /dev/null 2>&1 || failed=1
		if [ "$failed" ] ; then
			echo -e "Failed.\n"
			email $admin "VPS Deletion Failure" "Failed to remove config. file $conf_file."
			exit 6
		else
			echo -e "Success.\n"
		fi
		echo -n "Removing DB entry for VPS $VM... "
		$MYSQL"DELETE FROM guests WHERE owner = \"$user\" AND vm_name = \"$VM\"" -s -s > /dev/null 2>&1 || failed=1
		if [ "$failed" ] ; then
			echo -e "Failed.\n"
			email $admin "VPS Deletion Failure" "Failed to remove DB entry for VPS $VM belonging to $user."
			exit 7
		else
			echo -e "Success.\n"
		#	email $user $admin "VPS Successfully Deleted" "Congratulations! Your VPS $VPS has been successfully deleted."
		fi
		# Now, drop and recreate the `id` column in the DB so that the order is maintained:
		echo -n "Dropping DB column \`id\` from VPS table guests... "
		$MYSQL"ALTER TABLE guests DROP COLUMN id" > /dev/null 2>&1 || failed=1
		if [ "$failed" ] ; then
			echo -e "Failed.\n"
			email $admin "VPS Deletion Failure" "Failed to remove DB entry for VPS $VM belonging to $user."
			exit 7
		else
			echo -e "Success.\n"
		fi
		echo -n "Recreating DB column \`id\` in VPS table guests... "
		$MYSQL"ALTER TABLE guests ADD COLUMN \`id\` int(4) NOT NULL auto_increment PRIMARY KEY AFTER server_id" \
		> /dev/null 2>&1 || failed=1
	;;
	n | N | *) echo Not confirmed
		exit
	;;
esac

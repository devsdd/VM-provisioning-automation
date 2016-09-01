#! /bin/bash

TODAY=`date +%d-%m-%Y`
backup_file=/backup/db/$TODAY.tar.bz2
admin=<INSERT YOUR EMAIL ADDRESS HERE>
logfile=/tmp/backup.log
keep_backup_days=4

function email()
{
	cat << EOF | sendmail $admin -f do_not_reply@`hostname`
From: do_not_reply@`hostname`
To: $admin
Subject: VPS DB Backup Error

Dear $admin,

	The daily backup script for the MySQL DB "VPS" has failed. The error encountered was:
	
	$1
	
	Please take a look.

- regards,
Backup Script @$hostname
EOF
}

# truncate the logfile
> $logfile

# abort if backup matching today's date is already existing
if [ -f $backup_file ] ; then
	email "VPS DB backup already exists for $TODAY"
	exit 0
fi

# remove the previous dump or `mysqlhotcopy` will fail the next time this script runs

if [ -d /tmp/VPS ] ; then
	rm -rf /tmp/VPS
fi

/usr/bin/mysqlhotcopy VPS /tmp/	> $logfile 2>&1 || failed=1

if [ $failed ] ; then
	email "\`mysqlhotcopy\` encountered an error. Check the logfile $logfile."
	exit 1
fi

/bin/tar -cjf $backup_file /tmp/VPS >> $logfile 2>&1 $logfile || failed=1

if [ $failed ] ; then
	email "\`tar\` encountered an error. Check the logfile $logfile."
	exit 1
fi

# copy the backup over to another server for redundancy

/usr/bin/scp -o PreferredAuthentications="hostbased,publickey" $backup_file root@192.168.7.3:/backup/db/vps-1/ >> $logfile 2>&1 || failed=1

if [ $failed ] ; then
	email "Remote backup failed. Check the logfile $logfile."
	exit 1
fi

# delete backup older than $keep_backup_days
find /backup/db/ -type f -name *.tar.bz2 -mtime +$keep_backup_days -exec rm -f '{}' ';'  2>&1 >> $logfile || failed=1

if [ $failed ] ; then
	email "Failed to delete old backups. Check the logfile $logfile."
	exit 1
fi

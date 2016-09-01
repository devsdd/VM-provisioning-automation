#!/bin/bash
for f in /dev/mapper/virtual-* ; do if [ "$f" != "/dev/mapper/virtual-linux" -o "$f" != "/dev/mapper/virtual-Windows" ] ; then kpartx -l $f | awk '/p[12]/ {print $1}' | while read part ; do fsck.ext3 -y $part ; done ; fi ; done


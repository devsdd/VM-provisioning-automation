#!/bin/bash

if [ ! $1 ] ; then
        echo "Stop what?"
else
        for i in `ps aux | grep -i Xvnc $1 | grep -v grep | awk '{print $2}' ` ; do
        kill -9 $i
done
exit 0
fi


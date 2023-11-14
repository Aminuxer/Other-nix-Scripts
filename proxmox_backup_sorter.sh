#!/bin/bash

# ProxMox Backup Sorter by Amin 2018-07-24
# Parse vzdump-logs and place backups in subdirs
# Proxmox 6.x-8.x required, need VM Name data in log-files

if [ -d "$1" ]
   then wdir=$1;
   else
     echo "Usage: $0 <Dir for Proxmox backup sort>";
     exit 1;
fi

echo "Work Dir is $wdir";

for logf in $wdir/vzdump-*.log;
do
   vmname=`cat $logf | grep Name | cut -d ' ' -f 6 | head -n 1`
   vmtype=`cat $logf | grep Name | cut -d ' ' -f 4 | head -n 1`
   fnpref=`echo "$logf" | cut -d '.' -f 1`

   if [ ! -n "$vmname" ] || [ ! -n "$vmtype" ] || [ ! -n "$fnpref" ]
      then echo "No VM Name/Type in $logf file";
      exit 2;
   fi

   echo "$vmtype $vmname";
   mkdir -p $wdir/$vmtype/$vmname
   mv $fnpref* $wdir/$vmtype/$vmname

done

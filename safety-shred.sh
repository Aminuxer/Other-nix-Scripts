#!/bin/bash

# Amin 's Smart SHRED script   v. 2021-11-02

if [ "$1" != '' ]
   then TARGET="$1";   # TARGET - path to shredded device
   else
        echo "Usage: $0 <Path to device for CLEAN>
    Example: $0 /dev/sda12
             $0 /dev/md69
             $0 /dev/mapper/LVM-LV1";
        exit 1;
fi

LABEL=`basename "$TARGET"`;   # start-label <- filename
RPATH=`realpath "$TARGET"`;   # full-path

## Start safety checks - mounted paritions, RAID, LVM, ZFS
##  ACHTUNG CHECKS !!!
   if [ -e "$TARGET" ] && [ `mount -f | cut -d ' ' -f 1 | grep '/dev/' | grep "$RPATH" | wc -l` -gt 0 ] && [ "$2" != "stop" ]
         then echo "Device $TARGET mounted. Unmount first. BE CARE!"; exit 69;
   elif [ -e "$TARGET" ] && [ `swapon -s | grep '/dev/' | cut -d ' ' -f 1 | grep "$RPATH" | wc -l` -gt 0 ]
      then echo "Device $TARGET is active SWAP. Unmount first. Stop."; exit 71;

   elif [ -e "$TARGET" ] && [ `mdadm -D /dev/md* 2>/dev/null | grep 'active' | grep "$RPATH" | wc -l` -gt 0 ]
      then echo "Device $TARGET in RAID-array. Stop. BE CARE!"; exit 72;

   elif [ -e "$TARGET" ] && [ `pvscan -s 2>/dev/null | grep '/dev/' | grep "$RPATH" | wc -l` -gt 0 ]
      then echo "Device $TARGET in LVM. Stop. BE CARE!"; exit 73;

   elif [ -e "$TARGET" ] && [ `blkid --match-token TYPE="zfs_member" -s LABEL | cut -d ':' -f 1 | grep "$RPATH" | wc -l` -gt 0 ]
      then echo "Device $TARGET contain ZFS. Stop. BE CARE!"; exit 74;

   elif [ ! -e "$TARGET" ] && [ `echo "$RPATH" | grep -E "^/(dev|sys|proc)/"` ]
      then echo "Path $RPATH not exist in system area. Stop."; exit 75;

   elif [ `lsblk $RPATH -n -o MOUNTPOINT 2> /dev/null | grep -v '^$' | wc -l` -gt 0 ]
      then echo "Block device $RPATH has active MOUNTPOINT."; exit 75;
   elif [ `losetup -a | grep "$RPATH" | wc -l` -gt 0 ]
          then echo "This device loop-mapped ! Stop it first."; exit 62;
   fi
## End safety checks - mounted paritions, RAID, LVM, ZFS

echo ' ';
echo '----- Controlled SHRED ---------------------';

     if [ `echo "$RPATH" | grep -E "^/dev/"` ]
        then echo "!! ATTENTION !! Device $RPATH will be ERASED!";
     fi

     if [ `which smartctl 2>/dev/null` ]
     then
        HDINFO=`smartctl -i "$RPATH" | grep -E '(Model|Serial|Capacity)'`;
        if [ ! "$HDINFO" == '' ]
        then echo "!! Hardware (smartctl):
$HDINFO"
        fi
     elif [ `which hdparm 2>/dev/null` ]
     then
        HDPARM=`hdparm -i "$RPATH" | grep 'Model' 2>/dev/null`
        if [ ! "$HDPARM" == '' ]
           then echo "!! Hardware (hdparm):
$HDPARM"
        fi
     fi

     OLDFS=`blkid "$RPATH" | sed 's/\s/\n/g'`
     if [ ! "$OLDFS" == '' ]
        then echo "!! Device has filesystem:
  $OLDFS"
     fi

     echo -n "ALL DATA on storage WILL BE DESTROYED. Continue (Yes/No)? "
     read CONFIRM
     if [ ! -n "$CONFIRM" ] || [ ! "$CONFIRM" == 'Yes' ]
        then echo 'No confirmation!'; exit 60;
        else echo "OK, continue...";
     fi

     while [ "$METHOD" == "" ]
     do
         echo -n "Input erase method: Random,Zeros (R/Z/N)? "
         read METHOD
         METHOD=`echo "$METHOD" | grep -Ex '.+'`
     done

     case "$METHOD" in
     R)
       SRC='/dev/urandom';
       ACT='R';;
     Z)
       SRC='/dev/zero';
       ACT='Z';;
     *)
       ACT='N';
       echo "Canceled.";
       exit 5;;
     esac

     if [ "$ACT" == 'R' ] || [ "$ACT" == 'Z' ]
     then
        dd if=$SRC of="$TARGET" bs=4M conv=noerror status=progress
        echo "ERASE $TARGET OK";
     fi

exit 0;

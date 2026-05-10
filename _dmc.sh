#!/bin/bash

# Amin 's DM-Crypt mount helper script   v. 2026-05-10
# https://github.com/Aminuxer/DM-Crypt-Helper-Scripts/blob/master/_dmc.sh

MNTBASE=/run/media;


FSTYPES='ext[2-4]|btrfs|fat|vfat|msdos|ntfs|exfat|xfs|reiserfs|jfs';     # GREP-RegExp for mkfs.(*) and read value
LABELSR='s/[^0-9[:alpha:]+#\.\_=-]//g';                                  # SED safety for internal labels, protect grep
DEPENDS='cryptsetup losetup realpath sed md5sum blkid lsblk';            # Dependencies tools
NOMNTPTS='/ /sys /proc /dev /run /boot/efi /bin /sbin /usr/bin /usr/sbin /etc';    # EXACT Paths disabled as custom mountpoints

#  Check dependencies in OS
deps=( $DEPENDS )

lost_deps=''
for dep in "${deps[@]}"
do
    if ! command -v $dep &> /dev/null
    then
        lost_deps="$lost_deps $dep ";
    fi
done
if [ -n "$lost_deps" ]
   then echo "No tools: [$lost_deps] - install before using."; exit 11;
fi


# command-line parameters parse/help
if [ -e "$1" ] || [ "$2" == "create" ]
   then CCNTR="$1";     # CCNTR = path (full or relative) to cryptocontainer
   else
        echo "Usage: $0 <Path to Dm-Crypt container> [start|stop|create|make_loops] [Mount point] [cipher]
    Example: $0 ~/mysecrets.bin create    - make new in file
             $0 /dev/md0 create           - on RAID
             $0 ~/mysecrets.bin           - switch
             $0 ~/mysecrets.bin stop      - force stop
    create - make new container. Existing file don't touch for safety
    make_loops - create new loop-devices in /dev";
        exit 1;
fi


RPATH=`realpath "$CCNTR"`;    # full, absolute path - used in safety checks, grep with mount and losetup
LABEL=`echo "$RPATH" | sed -r "s/[^0-9a-zA-Z\.\_=-]//g"`_`echo "$RPATH" | md5sum | cut -b 1-8`;   # dev-mapper short name
         #    /\-- `basename "$CCNTR"` instead first $RPATH for short names

## Start safety checks - mounted paritions, RAID, LVM, ZFS, Ceph
##  ACHTUNG CHECKS !!!
   if [ -e "$CCNTR" ] && [ `mount -f | cut -d ' ' -f 1 | grep '/dev/' | grep -F "$RPATH" | wc -l` -gt 0 ] && [ "$2" != "stop" ]
         then echo "Device $CCNTR mounted. Unmount first. BE CARE!"; exit 69;

   elif [ -e "$CCNTR" ] && [ `cat /proc/swaps | cut -d ' ' -f 1 | grep -F "$RPATH" | wc -l` -gt 0 ]
      then echo "Device $CCNTR is active SWAP. Unmount first. Stop."; exit 71;

   elif [ -e "$CCNTR" ] && [ `mdadm -D /dev/md* 2>/dev/null | grep 'active' | grep -F "$RPATH" | wc -l` -gt 0 ]
      then echo "Device $CCNTR in RAID-array. Stop. BE CARE!"; exit 72;

   elif [ -e "$CCNTR" ] && [ `pvscan -s 2>/dev/null | grep '/dev/' | grep -F "$RPATH" | wc -l` -gt 0 ]
      then echo "Device $CCNTR in LVM. Stop. BE CARE!"; exit 73;

   elif [ -e "$CCNTR" ] && [ `blkid -s TYPE | grep ' TYPE="zfs_member"' | cut -d ':' -f 1 | grep -F "$RPATH" | wc -l` -gt 0 ]
      then echo "Device $CCNTR contain ZFS. Stop. BE CARE!"; exit 74;

   elif [ ! -e "$CCNTR" ] && [ `echo "$RPATH" | grep -E "^/(dev|sys|proc)/"` ]
      then echo -e "Path $RPATH in system area. Stop.\nUse new regular file or free block-device."; exit 75;

   elif [ `lsblk $RPATH -n -o MOUNTPOINT 2> /dev/null | grep -v '^$' | wc -l` -gt 0 ]
      then echo "Block device $RPATH has active MOUNTPOINT."; exit 77;

   elif [ -e "$CCNTR" ] && [ `blkid -s TYPE | grep ' TYPE="ceph_bluestore"' | cut -d ':' -f 1 | grep -F "$RPATH" | wc -l` -gt 0 ]
      then echo "Device $CCNTR contain Ceph data!!  Stop-Stop-Stop!!  Check it seven times !!\nset ceph osd.X out, check HEALTH_OK, ceph-volume zap... Where are you running my script, crazy voodoo people ??"; exit 79;

   fi
## End safety checks - mounted paritions, RAID, LVM, ZFS


if [ -n "$3" ]
   then MNTPT=`realpath "$3"`;     # MNTPT = Mount-point from external parameter
   nomntps=( $NOMNTPTS )

   for nomntpt in "${nomntps[@]}"   # Check that custom mount-point not overlap hardware-important system directories
   do
     if [ "$MNTPT" == "$nomntpt" ]
     then
         echo "  !! Prohibited custom mount-point: [$MNTPT] found in [$NOMNTPTS]"; exit 81;
     fi
   done

   if [ ! -d "$MNTPT" ]
      then echo " !! Custom mount-point [$MNTPT] must be directory ! Cannot mount to non-directory. Stop."; exit 82;
   fi

   CHKLINE=`ls -A "$MNTPT"`;
   if [ -n "CHKLINE" ]
      then
      if [ `echo "$MNTPT" | grep -E "^/(dev|sys|proc|boot)"` ] || [ `echo "$MNTPT" | grep -E "^/run/(user|systemd|udev|blkid|mdadm|lvm|cryptsetup)"` ]
         then echo " !! Cannot mount over filled directory in system area. Stop."; exit 83;
      fi
   fi
fi


if [ -n "$4" ]
   then CIPHER=`echo "$4" | grep -Ex '[a-z0-9\-\:\s]+'`;
   else CIPHER='aes-xts-essiv:sha256 --hash sha512 --key-size 512';
fi



inform_ramdisk() {
  if [ `stat --file-system --format=%T "$CCNTR"` == 'tmpfs' ] && [ -f "$CCNTR" ]
     then echo -e "WARN: $CCNTR in TMPFS/RAM !!\n  Data will be LOST after reboot !!";
  fi
}



start() {
echo ' ';
echo "----- Mount CryptoContainer [$CCNTR] ---------------------";

if [ `/sbin/losetup -a | grep -F "$RPATH" | wc -l` -gt 0 ]
then
   echo -e "This container $RPATH already mapped.\nStop container forcibly and try start again.";
   exit 4;
fi

LOOPD=`/sbin/losetup -f`;
/sbin/losetup "$LOOPD" "$RPATH";
if [ $? -ne 0 ]
then
   echo "losetup error, can't make loopback from file"
   exit 5;
fi

echo "Cipher options: $CIPHER"
/sbin/cryptsetup -v create "$LABEL" "$LOOPD" -c $CIPHER
if [ $? -ne 0 ]
then
   echo "cryptsetup error, can't make crypted devmapper from loop-device"
   exit 6;
fi

if [ ! -n "$MNTPT" ]     # Mount point not in command-line: read from internal-FS
   then
      FSDETECT=`blkid -o value -s TYPE "/dev/mapper/$LABEL"`
      if [ $? -ne 0 ]
      then
        FSDETECT='Unknown';
      fi
      echo "FS in container: $FSDETECT"

      CCNLABEL=`blkid -o value -s LABEL "/dev/mapper/$LABEL" | sed -r "$LABELSR"`
      if [ ! -n "$CCNLABEL" ]
         then CCNLABEL="Disk_NoLABEL__$LABEL";
      fi
      MNTPT="$MNTBASE/$CCNLABEL"     # Add Internal FS Label to mount-path
fi

mkdir -p "$MNTPT";

if [ `ls -A "$MNTPT" | wc -l` -gt 0 ]
then
echo "  !! Mount point NOT clean at start() stage
    Underlayed files will be inaccesible;
    This usage scenario NOT recommended;
    You can try change Internal-FS-Label ?"
fi

mount "/dev/mapper/$LABEL" "$MNTPT";
       MLINE=`mount -f | grep -F "$MNTPT"`;
       if [ -n "$MLINE" ]; then
         echo "Label :: [$LABEL] ; $CCNTR --> $MNTPT ; [on $LOOPD]";
         echo '----- Mount CryptoContainer Complete ! ---------';
       else echo '----- ERROR - Bad password  -----------------';
         stop ;
       fi

inform_ramdisk;
echo ' ';
}



stop() {
echo ' ';
echo "----- Unmount CryptoContainer [$CCNTR] --------------------";

LOOPD=`/sbin/losetup -a | grep -F "$RPATH" | cut -d ':' -f 1`;
if [ ! -n "$MNTPT" ]
   then MNTPT=`df /dev/mapper/$LABEL --output=target 2> /dev/null | tail -n 1`
fi

if [ -n "$LOOPD" ]
   then
       sync $LOOPD;
       sync "$RPATH";
fi

if [ -n "$MNTPT" ]
   then umount "$MNTPT";
fi

if [ -n "$LABEL" ]
   then /sbin/cryptsetup remove "$LABEL";
fi

if [ -n "$LOOPD" ]
   then /sbin/losetup -d "$LOOPD";
fi

if [ -n "$MNTPT" ]    # Check mount pint
   then DLINE=`ls -A "$MNTPT"`;
fi

if [ -n "$DLINE" ];   # Only empty dir can be deleted !!
   then echo -e "WARNING: Not empty mount point.\nCheck $MNTPT";
   else
           echo "Check mount-point [$MNTPT] and try remove empty dir";
           if [ ! "$MNTPT" == '' ]
              then
                echo "!! Remove mount-point $MNTPT !!";
                rm -f --one-file-system -d -v "$MNTPT";
                echo '----- Unmount CryptoContainer Complete ! ---------';
              else echo "Empty mount-point string -)";
           fi
fi
echo ' ';
}



create() {
echo ' ';
echo '----- CREATE NEW CryptoContainer ---------------------';

   if [ -f "$CCNTR" ]
     then echo "File $CCNTR exist, overwrite existing files denied."; exit 61;
   elif [ `losetup -a | grep -F "$RPATH" | wc -l` -gt 0 ]
          then echo "This device already loop-mapped ! Stop it first."; exit 62;
   else
     if [ `echo "$RPATH" | grep -E "^/dev/"` ]
        then echo "!! ATTENTION !! Your cryptocontainer on PHYSICAL device !
!! Current content of $RPATH will be ERASED!  Be carefully!";
     fi

     OLDFS=`blkid "$RPATH"`
     if [ ! "$OLDFS" == '' ]
        then echo "!! Device $CCNTR contain filesystem:
          $OLDFS"
     fi

     echo -n "You start to CREATE dm-crypt container. Continue (Yes/No)? "
     read CONFIRM
     if [ ! -n "$CONFIRM" ] || [ ! "$CONFIRM" == 'Yes' ]
        then echo 'No confirmation!'; exit 60;
        else echo "OK, continue...";
     fi

     while [ "$NEWLABEL" = "" ]
     do
       echo -n "Enter internal volume label for new container: "
       read NEWLABEL
       NEWLABEL=`echo "$NEWLABEL" | sed -r "$LABELSR"`
     done

     touch "$CCNTR";
     LOOPD=`/sbin/losetup -f`;

     echo "Supported filesystems on your machine:";
     echo "---------------------------------------";
     ls -1 /sbin/mkfs.* | cut -b '12-' | grep -E "($FSTYPES)" | sort
     echo "---------------------------------------";

     while [ "$FSTYPE" = "" ]
     do
     echo -n "Enter filesystem type from list above: "
     read FSTYPE
     FSTYPE=`echo "$FSTYPE" | grep -Ex $FSTYPES`
     done

     if [ ! `echo "$RPATH" | grep -E "^/dev/"` ]
     then
       while [ "$NEWSIZE" = "" ]
       do
         echo -n "Enter volume size (1048576, 1024K, 100M, 2G, 5T): "
         read NEWSIZE
         NEWSIZE=`echo "$NEWSIZE" | grep -Ex '[0-9]+[KMGTPEZY]?'`
       done
     else
         NEWSIZE=`lsblk -bdno SIZE "$RPATH" | tr -d ' '`;
         NEWSIZE=$((NEWSIZE+0))
         echo "Block device :: Full detected size [$NEWSIZE] used"
         if [ $NEWSIZE -le 4096 ]
         then
             echo -e "Device too small < 4Kb.\n sdX5+ on MBR-parted / DOS Extended ??!"
             exit 44;
         fi
     fi


     echo "Fast fill container"
     dd if=/dev/null of="$CCNTR" bs=1 seek="$NEWSIZE"
     if [ $? -ne 0 ]
     then
        echo "DD error; Size too big, read-only storage, etc ?"
        exit 7;
     fi

     /sbin/losetup "$LOOPD" "$RPATH";
     /sbin/cryptsetup create "$LABEL" "$LOOPD" -c $CIPHER;
     echo "Shreding [$NEWSIZE] space on [$CCNTR] ...   (please wait)";
     shred -n1 "/dev/mapper/$LABEL";

     echo "Formatting cryptocontainer...";
     if [ "$FSTYPE" == 'ext2' ] || [ "$FSTYPE" == 'ext3' ] || [ "$FSTYPE" == 'ext4' ] ||
        [ "$FSTYPE" == 'xfs' ] || [ "$FSTYPE" == 'btrfs' ] || [ "$FSTYPE" == 'ntfs' ] || [ "$FSTYPE" == 'exfat' ] || [ "$FSTYPE" == 'jfs' ]
     then
        mkfs.$FSTYPE -L "$NEWLABEL" "/dev/mapper/$LABEL";

     elif [ "$FSTYPE" == 'fat' ] || [ "$FSTYPE" == 'msdos' ] || [ "$FSTYPE" == 'vfat' ]
     then
        mkfs.$FSTYPE -n "$NEWLABEL" "/dev/mapper/$LABEL"

     elif [ "$FSTYPE" == 'reiserfs' ]
     then
        mkfs.$FSTYPE -l "$NEWLABEL" -f "/dev/mapper/$LABEL"
     fi

     if [ ! -n "$MNTPT" ]
        then MNTPT="$MNTBASE/$NEWLABEL";
     fi
     mkdir -p "$MNTPT";

    if [ `ls -A $MNTPT | wc -l` -gt 0 ]
    then
    echo "  !! Mount point NOT clean at create() stage
    Underlayed files will be inaccesible;
    This usage scenario NOT recommended;
    You can try change Internal-FS-Label ?"
    fi

     mount -t "$FSTYPE" "/dev/mapper/$LABEL" "$MNTPT";
     if [ `ls -A $MNTPT | wc -l` -eq 0 ]
     then
       mount -t auto "/dev/mapper/$LABEL" "$MNTPT" 2>/dev/null;
     fi

       MLINE=`mount -f | grep -F "$MNTPT"`;
       if [ -n "$MLINE" ]; then
         echo "Label :: [$LABEL] ; $CCNTR --> $MNTPT ; [on $LOOPD], SIZE: [$NEWSIZE]";
         echo '----- New CryptoContainer mounted succesfully ! ---------';
       fi
     echo ' ';
fi

inform_ramdisk;

exit 0;
}



make_loops() {
  for i in $(seq 100 220); do
    mknod -m0660 /dev/loop$i b 7 $i;
    chown root.disk /dev/loop$i;
  done;
}



case "$2" in
start)
  start ;;
stop)
  stop ;;
create)
  create ;;
make_loops)
  make_loops ;;
*)
  if [ `/sbin/losetup -a | grep -F "$RPATH" | wc -l` -gt 0 ]; then
   stop;
   else
   stop;
   start;
  fi
esac



exit 0;
